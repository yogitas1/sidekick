-- Community Builder — full database schema (snapshot of what's applied to the Supabase project)
-- Apply in a fresh project with: psql or the Supabase SQL editor, then run seed.sql and seed-demo-users.sql

-- http extension: used by seed.sql to load the full US ZIP centroid dataset in-database
create extension if not exists http with schema extensions;

create table public.interest_buckets (
  id serial primary key,
  name text not null unique,
  emoji text not null default ''
);

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  bucket_id int not null references public.interest_buckets(id),
  venue text not null default '',
  zipcode text not null default '',
  cost_level int not null default 1 check (cost_level between 1 and 4),
  is_scheduled_event boolean not null default false,
  event_time timestamptz,
  source text not null default 'curated',
  created_at timestamptz not null default now()
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default '',
  age int check (age between 18 and 120),
  gender text check (gender in ('woman','man','nonbinary','other')),
  zipcode text not null default '',
  budget_level int not null default 2 check (budget_level between 1 and 4),
  personality_type text,
  strike_count int not null default 0,
  is_suspended boolean not null default false,
  needs_rematch boolean not null default false,
  onboarding_complete boolean not null default false,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.preferences (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  age_min int not null default 18,
  age_max int not null default 99,
  gender_pref text not null default 'any' check (gender_pref in ('any','woman','man','nonbinary')),
  max_distance_km int not null default 15,
  notification_pref text not null default 'day_before' check (notification_pref in ('day_before','two_days_before','week_before'))
);

create table public.user_interests (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  bucket_id int not null references public.interest_buckets(id),
  primary key (user_id, activity_id)
);

create table public.availability (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  day_of_week int not null check (day_of_week between 0 and 6),
  time_block text not null check (time_block in ('morning','afternoon','evening')),
  primary key (user_id, day_of_week, time_block)
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(user_id),
  user_b uuid not null references public.profiles(user_id),
  activity_id uuid not null references public.activities(id),
  meetup_time timestamptz not null,
  status text not null default 'proposed' check (status in ('proposed','confirmed','completed','cancelled','no_show')),
  a_confirmed boolean not null default false,
  b_confirmed boolean not null default false,
  cancelled_by uuid,
  created_at timestamptz not null default now(),
  check (user_a <> user_b)
);

create table public.messages (
  id bigint generated always as identity primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  sender_id uuid not null references public.profiles(user_id),
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

create table public.feedback (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  rater_id uuid not null references public.profiles(user_id),
  ratee_id uuid not null references public.profiles(user_id),
  showed_up boolean not null,
  rating int check (rating between 1 and 5),
  would_meet_again boolean,
  comments text not null default '',
  created_at timestamptz not null default now(),
  unique (match_id, rater_id)
);

create table public.zip_geo (
  zipcode text primary key,
  lat double precision not null,
  lng double precision not null
);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.interest_buckets enable row level security;
alter table public.activities enable row level security;
alter table public.profiles enable row level security;
alter table public.preferences enable row level security;
alter table public.user_interests enable row level security;
alter table public.availability enable row level security;
alter table public.matches enable row level security;
alter table public.messages enable row level security;
alter table public.feedback enable row level security;
alter table public.zip_geo enable row level security;

create policy "buckets readable" on public.interest_buckets for select to authenticated using (true);
create policy "activities readable" on public.activities for select to authenticated using (true);
create policy "zip_geo readable" on public.zip_geo for select to authenticated using (true);

create policy "own profile select" on public.profiles for select to authenticated using (auth.uid() = user_id);
create policy "own profile insert" on public.profiles for insert to authenticated with check (auth.uid() = user_id);
create policy "own profile update" on public.profiles for update to authenticated using (auth.uid() = user_id);

create policy "own prefs all" on public.preferences for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own interests all" on public.user_interests for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own availability all" on public.availability for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "participants read matches" on public.matches for select to authenticated using (auth.uid() in (user_a, user_b));

create policy "participants read messages" on public.messages for select to authenticated
  using (exists (select 1 from public.matches m where m.id = match_id and auth.uid() in (m.user_a, m.user_b)));

-- inserts only inside the chat window (24h before meetup -> 2h after) on a confirmed match
create policy "participants send messages in window" on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.matches m
      where m.id = match_id
        and auth.uid() in (m.user_a, m.user_b)
        and m.status = 'confirmed'
        and now() >= m.meetup_time - interval '24 hours'
        and now() <= m.meetup_time + interval '2 hours'
    )
  );

create policy "participants read feedback" on public.feedback for select to authenticated using (rater_id = auth.uid());
create policy "rater inserts feedback" on public.feedback for insert to authenticated
  with check (
    rater_id = auth.uid()
    and exists (
      select 1 from public.matches m
      where m.id = match_id
        and auth.uid() in (m.user_a, m.user_b)
        and ratee_id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
        and now() > m.meetup_time
    )
  );

-- Realtime for chat
alter publication supabase_realtime add table public.messages;

-- ---------------------------------------------------------------------------
-- Functions
-- ---------------------------------------------------------------------------

-- Partner info scoped to the caller: reveals only first name / age / gender
create or replace function public.match_partners()
returns table (match_id uuid, partner_id uuid, first_name text, age int, gender text, is_demo boolean)
language sql stable security definer set search_path = public
as $$
  select m.id, p.user_id, p.first_name, p.age, p.gender, p.is_demo
  from matches m
  join profiles p on p.user_id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  where auth.uid() in (m.user_a, m.user_b);
$$;

create or replace function public.zip_distance_km(zip1 text, zip2 text)
returns double precision
language sql stable security definer set search_path = public
as $$
  select 2 * 6371 * asin(sqrt(
    power(sin(radians(b.lat - a.lat) / 2), 2)
    + cos(radians(a.lat)) * cos(radians(b.lat)) * power(sin(radians(b.lng - a.lng) / 2), 2)
  ))
  from zip_geo a, zip_geo b
  where a.zipcode = zip1 and b.zipcode = zip2;
$$;

-- Next occurrence of a weekly slot, at least 24h out so the chat-window mechanic is observable.
create or replace function public.next_slot_time(dow int, block text)
returns timestamptz
language plpgsql stable security definer set search_path = public
as $$
declare
  base date := (now() at time zone 'America/Los_Angeles')::date;
  hour_of int := case block when 'morning' then 10 when 'afternoon' then 14 else 18 end;
  candidate timestamptz;
  i int;
begin
  for i in 1..14 loop
    if extract(dow from base + i)::int = dow then
      candidate := ((base + i)::timestamp + make_interval(hours => hour_of)) at time zone 'America/Los_Angeles';
      if candidate >= now() + interval '24 hours' then
        return candidate;
      end if;
    end if;
  end loop;
  return now() + interval '48 hours';
end;
$$;

-- ---------------------------------------------------------------------------
-- Matching: shared pieces used by both the on-demand button and the weekly batch
-- ---------------------------------------------------------------------------

-- Normalized, symmetric 0-1 score:
--   0.40 interest-bucket overlap (Jaccard) + 0.25 shared availability (capped at 4 slots)
-- + 0.20 budget closeness + 0.15 personality (unknown counts half)
create or replace function public.compatibility(a uuid, b uuid)
returns double precision
language sql stable security definer set search_path = public
as $$
  with
  ia as (select distinct bucket_id from user_interests where user_id = a),
  ib as (select distinct bucket_id from user_interests where user_id = b),
  shared_buckets as (select count(*) c from ia where bucket_id in (select bucket_id from ib)),
  union_buckets as (select count(*) c from (select bucket_id from ia union select bucket_id from ib) u),
  shared_slots as (
    select count(*) c
    from availability x
    join availability y on y.user_id = b and y.day_of_week = x.day_of_week and y.time_block = x.time_block
    where x.user_id = a
  ),
  pa as (select budget_level, personality_type from profiles where user_id = a),
  pb as (select budget_level, personality_type from profiles where user_id = b)
  select
    0.40 * coalesce((select c from shared_buckets)::float / nullif((select c from union_buckets), 0), 0)
  + 0.25 * least((select c from shared_slots), 4)::float / 4
  + 0.20 * (1 - abs((select budget_level from pa) - (select budget_level from pb))::float / 3)
  + 0.15 * case
      when (select personality_type from pa) is null or (select personality_type from pb) is null then 0.5
      when (select personality_type from pa) = (select personality_type from pb) then 1
      else 0
    end;
$$;

-- Mutual hard constraints: age ranges, gender prefs, distance, never matched
-- before, and at least one shared interest bucket and availability slot.
create or replace function public.passes_filters(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select
    exists (
      select 1
      from profiles pa
      join preferences fa on fa.user_id = pa.user_id,
           profiles pb
      join preferences fb on fb.user_id = pb.user_id
      where pa.user_id = a and pb.user_id = b
        and pa.age between fb.age_min and fb.age_max
        and pb.age between fa.age_min and fa.age_max
        and (fa.gender_pref = 'any' or fa.gender_pref = pb.gender)
        and (fb.gender_pref = 'any' or fb.gender_pref = pa.gender)
        and coalesce(zip_distance_km(pa.zipcode, pb.zipcode) <= least(fa.max_distance_km, fb.max_distance_km), true)
    )
    and not exists (
      select 1 from matches m
      where (m.user_a = a and m.user_b = b) or (m.user_a = b and m.user_b = a)
    )
    and exists (
      select 1 from user_interests x
      where x.user_id = a
        and x.bucket_id in (select bucket_id from user_interests y where y.user_id = b)
    )
    and exists (
      select 1 from availability x
      join availability y on y.user_id = b and y.day_of_week = x.day_of_week and y.time_block = x.time_block
      where x.user_id = a
    );
$$;

-- Picks an activity from a shared bucket that fits both budgets and a mutually
-- free time, then creates the proposed match. Returns null if no activity fits.
create or replace function public.create_match(a uuid, b uuid)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  chosen record;
  slot record;
  mt timestamptz;
  new_match uuid;
begin
  select x.day_of_week, x.time_block, next_slot_time(x.day_of_week, x.time_block) as t
  into slot
  from availability x
  join availability y on y.user_id = b and y.day_of_week = x.day_of_week and y.time_block = x.time_block
  where x.user_id = a
  order by t asc
  limit 1;

  if slot is null then
    return null;
  end if;

  select act.id, act.event_time, act.is_scheduled_event
  into chosen
  from activities act
  where act.bucket_id in (
      select x.bucket_id from user_interests x
      where x.user_id = a
        and x.bucket_id in (select y.bucket_id from user_interests y where y.user_id = b)
    )
    and act.cost_level <= greatest(least((select budget_level from profiles where user_id = a),
                                         (select budget_level from profiles where user_id = b)), 1)
    and (
      not act.is_scheduled_event
      or (
        act.event_time > now() + interval '24 hours'
        -- scheduled events must land in a slot both users marked free
        and exists (
          select 1 from availability x
          join availability y on y.user_id = b and y.day_of_week = x.day_of_week and y.time_block = x.time_block
          where x.user_id = a
            and x.day_of_week = extract(dow from act.event_time at time zone 'America/Los_Angeles')::int
            and x.time_block = case
              when extract(hour from act.event_time at time zone 'America/Los_Angeles') between 8 and 11 then 'morning'
              when extract(hour from act.event_time at time zone 'America/Los_Angeles') between 12 and 16 then 'afternoon'
              else 'evening'
            end
        )
      )
    )
  order by
    (exists (select 1 from user_interests ui where ui.activity_id = act.id and ui.user_id in (a, b))) desc,
    act.is_scheduled_event desc,
    random()
  limit 1;

  if chosen is null then
    return null;
  end if;

  mt := case when chosen.is_scheduled_event then chosen.event_time else slot.t end;

  insert into matches (user_a, user_b, activity_id, meetup_time)
  values (a, b, chosen.id, mt)
  returning id into new_match;

  update profiles set needs_rematch = false where user_id in (a, b) and needs_rematch;

  return new_match;
end;
$$;

-- On-demand matching (the dashboard button), a thin composition of the shared
-- pieces. Cancelled-on users (needs_rematch) get a 0.5 priority boost.
create or replace function public.find_match()
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  my_p profiles%rowtype;
  best uuid;
begin
  select * into my_p from profiles where user_id = me;
  if my_p is null or not my_p.onboarding_complete
     or not exists (select 1 from preferences where user_id = me) then
    raise exception 'complete onboarding first';
  end if;
  if my_p.is_suspended then
    raise exception 'account suspended';
  end if;
  if exists (
    select 1 from matches
    where (user_a = me or user_b = me)
      and status in ('proposed','confirmed')
      and meetup_time > now()
  ) then
    raise exception 'you already have an upcoming meetup';
  end if;

  select c.user_id into best
  from profiles c
  where c.user_id <> me
    and c.onboarding_complete
    and not c.is_suspended
    and not exists (
      select 1 from matches m
      where (m.user_a = c.user_id or m.user_b = c.user_id)
        and m.status in ('proposed','confirmed')
        and m.meetup_time > now()
    )
    and passes_filters(me, c.user_id)
  order by
    compatibility(me, c.user_id) + case when c.needs_rematch then 0.5 else 0 end desc,
    random()
  limit 1;

  if best is null then
    return null;
  end if;

  return create_match(me, best);
end;
$$;

-- The weekly batch: greedy max-weight assignment over all eligible pairs.
-- Runs as system (no auth.uid()); called by pg_cron, never by clients.
create or replace function public.run_weekly_matching()
returns int
language plpgsql security definer set search_path = public
as $$
declare
  paired int := 0;
  r record;
begin
  -- everyone eligible and not already booked (idempotency guard: re-running
  -- can never double-book, because booked users never enter the pool)
  create temp table pool on commit drop as
    select p.user_id, p.needs_rematch
    from profiles p
    where p.onboarding_complete
      and not p.is_suspended
      and exists (select 1 from preferences f where f.user_id = p.user_id)
      and not exists (
        select 1 from matches m
        where (m.user_a = p.user_id or m.user_b = p.user_id)
          and m.status in ('proposed','confirmed')
          and m.meetup_time > now()
      );

  -- score every eligible pair once (hard filters first keeps the O(n^2) cheap)
  create temp table scored on commit drop as
    select a.user_id as ua, b.user_id as ub,
           compatibility(a.user_id, b.user_id)
             + case when a.needs_rematch or b.needs_rematch then 0.5 else 0 end as score
    from pool a
    join pool b on a.user_id < b.user_id
    where passes_filters(a.user_id, b.user_id);

  -- greedily take the best available pair, lock both out, repeat
  for r in select * from scored order by score desc, random() loop
    if exists (select 1 from pool where user_id = r.ua)
       and exists (select 1 from pool where user_id = r.ub) then
      -- create_match can return null (no activity fits this pair's budgets);
      -- then both stay in the pool for their next-best pairings
      if create_match(r.ua, r.ub) is not null then
        delete from pool where user_id in (r.ua, r.ub);
        paired := paired + 1;
      end if;
    end if;
  end loop;

  return paired;
end;
$$;

-- Confirm: caller confirms their side; demo partners auto-confirm so the flow is testable solo.
create or replace function public.confirm_match(p_match_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  m matches%rowtype;
  partner uuid;
begin
  select * into m from matches where id = p_match_id and auth.uid() in (user_a, user_b) for update;
  if m is null then raise exception 'match not found'; end if;
  if m.status <> 'proposed' then raise exception 'match is not awaiting confirmation'; end if;

  if m.user_a = auth.uid() then
    update matches set a_confirmed = true where id = p_match_id;
  else
    update matches set b_confirmed = true where id = p_match_id;
  end if;

  partner := case when m.user_a = auth.uid() then m.user_b else m.user_a end;
  if exists (select 1 from profiles where user_id = partner and is_demo) then
    update matches set a_confirmed = true, b_confirmed = true where id = p_match_id;
  end if;

  update matches set status = 'confirmed' where id = p_match_id and a_confirmed and b_confirmed;
end;
$$;

-- Cancel: flags the other user for priority rematch.
create or replace function public.cancel_match(p_match_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  m matches%rowtype;
  victim uuid;
begin
  select * into m from matches where id = p_match_id and auth.uid() in (user_a, user_b) for update;
  if m is null then raise exception 'match not found'; end if;
  if m.status not in ('proposed','confirmed') then raise exception 'match cannot be cancelled'; end if;

  victim := case when m.user_a = auth.uid() then m.user_b else m.user_a end;
  update matches set status = 'cancelled', cancelled_by = auth.uid() where id = p_match_id;
  update profiles set needs_rematch = true where user_id = victim;
end;
$$;

-- Strikes: a no-show report adds a strike; 3 strikes suspends. Also finalizes match status.
create or replace function public.apply_feedback()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if not new.showed_up then
    update profiles
    set strike_count = strike_count + 1,
        is_suspended = (strike_count + 1 >= 3)
    where user_id = new.ratee_id;
    update matches set status = 'no_show' where id = new.match_id and status in ('confirmed','completed');
  else
    update matches set status = 'completed' where id = new.match_id and status = 'confirmed';
  end if;
  return new;
end;
$$;

create trigger feedback_applied
after insert on public.feedback
for each row execute function public.apply_feedback();

-- ---------------------------------------------------------------------------
-- Grants: only signed-in users may call the app API functions; helpers are internal
-- ---------------------------------------------------------------------------
revoke execute on function public.match_partners() from public, anon;
revoke execute on function public.find_match() from public, anon;
revoke execute on function public.confirm_match(uuid) from public, anon;
revoke execute on function public.cancel_match(uuid) from public, anon;
revoke execute on function public.zip_distance_km(text, text) from public, anon, authenticated;
revoke execute on function public.next_slot_time(int, text) from public, anon, authenticated;
revoke execute on function public.apply_feedback() from public, anon, authenticated;
revoke execute on function public.compatibility(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.passes_filters(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.create_match(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.run_weekly_matching() from public, anon, authenticated;

grant execute on function public.match_partners() to authenticated;
grant execute on function public.find_match() to authenticated;
grant execute on function public.confirm_match(uuid) to authenticated;
grant execute on function public.cancel_match(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Weekly matching schedule (pg_cron runs inside Postgres; times are UTC)
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron;

-- Mondays 17:00 UTC = 9am PST / 10am PDT
select cron.schedule(
  'weekly-matching',
  '0 17 * * 1',
  $cron$ select public.run_weekly_matching(); $cron$
);
