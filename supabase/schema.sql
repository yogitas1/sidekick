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

-- Core matching: best-scoring compatible user + a shared-interest activity that fits
-- both budgets + a mutually free time. Creates a 'proposed' match; returns its id.
create or replace function public.find_match()
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  my_p profiles%rowtype;
  my_pref preferences%rowtype;
  best record;
  chosen_activity record;
  slot record;
  mt timestamptz;
  new_match uuid;
begin
  select * into my_p from profiles where user_id = me;
  select * into my_pref from preferences where user_id = me;
  if my_p is null or my_pref is null or not my_p.onboarding_complete then
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

  select c.user_id, c.first_name,
    (
      3 * (select count(distinct ui1.bucket_id) from user_interests ui1
           where ui1.user_id = me
             and ui1.bucket_id in (select ui2.bucket_id from user_interests ui2 where ui2.user_id = c.user_id))
      + 2 * least(4, (select count(*) from availability a1
                      join availability a2 on a2.user_id = c.user_id
                        and a2.day_of_week = a1.day_of_week and a2.time_block = a1.time_block
                      where a1.user_id = me))
      + (3 - abs(my_p.budget_level - c.budget_level))
      + case when my_p.personality_type is not null and my_p.personality_type = c.personality_type then 2 else 0 end
      + case when c.needs_rematch then 5 else 0 end
    ) as score
  into best
  from profiles c
  join preferences cp on cp.user_id = c.user_id
  where c.user_id <> me
    and c.onboarding_complete
    and not c.is_suspended
    and c.age between my_pref.age_min and my_pref.age_max
    and my_p.age between cp.age_min and cp.age_max
    and (my_pref.gender_pref = 'any' or my_pref.gender_pref = c.gender)
    and (cp.gender_pref = 'any' or cp.gender_pref = my_p.gender)
    and not exists (
      select 1 from matches m
      where (m.user_a = me and m.user_b = c.user_id) or (m.user_a = c.user_id and m.user_b = me)
    )
    and not exists (
      select 1 from matches m
      where (m.user_a = c.user_id or m.user_b = c.user_id)
        and m.status in ('proposed','confirmed')
        and m.meetup_time > now()
    )
    and coalesce(
      zip_distance_km(my_p.zipcode, c.zipcode) <= least(my_pref.max_distance_km, cp.max_distance_km),
      true
    )
    and exists (
      select 1 from user_interests ui1
      where ui1.user_id = me
        and ui1.bucket_id in (select bucket_id from user_interests ui2 where ui2.user_id = c.user_id)
    )
    and exists (
      select 1 from availability a1
      join availability a2 on a2.user_id = c.user_id
        and a2.day_of_week = a1.day_of_week and a2.time_block = a1.time_block
      where a1.user_id = me
    )
  order by score desc, random()
  limit 1;

  if best is null then
    return null;
  end if;

  select a1.day_of_week, a1.time_block, next_slot_time(a1.day_of_week, a1.time_block) as t
  into slot
  from availability a1
  join availability a2 on a2.user_id = best.user_id
    and a2.day_of_week = a1.day_of_week and a2.time_block = a1.time_block
  where a1.user_id = me
  order by t asc
  limit 1;

  select act.id, act.event_time, act.is_scheduled_event
  into chosen_activity
  from activities act
  where act.bucket_id in (
      select ui1.bucket_id from user_interests ui1
      where ui1.user_id = me
        and ui1.bucket_id in (select bucket_id from user_interests ui2 where ui2.user_id = best.user_id)
    )
    and act.cost_level <= greatest(least((select budget_level from profiles where user_id = me),
                                         (select budget_level from profiles where user_id = best.user_id)), 1)
    and (
      not act.is_scheduled_event
      or (
        act.event_time > now() + interval '24 hours'
        -- event must land in a slot both users marked free
        and exists (
          select 1 from availability a1
          join availability a2 on a2.user_id = best.user_id
            and a2.day_of_week = a1.day_of_week and a2.time_block = a1.time_block
          where a1.user_id = me
            and a1.day_of_week = extract(dow from act.event_time at time zone 'America/Los_Angeles')::int
            and a1.time_block = case
              when extract(hour from act.event_time at time zone 'America/Los_Angeles') between 8 and 11 then 'morning'
              when extract(hour from act.event_time at time zone 'America/Los_Angeles') between 12 and 16 then 'afternoon'
              else 'evening'
            end
        )
      )
    )
  order by
    (exists (select 1 from user_interests ui where ui.activity_id = act.id and ui.user_id in (me, best.user_id))) desc,
    act.is_scheduled_event desc,
    random()
  limit 1;

  if chosen_activity is null then
    return null;
  end if;

  mt := case when chosen_activity.is_scheduled_event then chosen_activity.event_time else slot.t end;

  insert into matches (user_a, user_b, activity_id, meetup_time)
  values (me, best.user_id, chosen_activity.id, mt)
  returning id into new_match;

  update profiles set needs_rematch = false where user_id in (me, best.user_id) and needs_rematch;

  return new_match;
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

grant execute on function public.match_partners() to authenticated;
grant execute on function public.find_match() to authenticated;
grant execute on function public.confirm_match(uuid) to authenticated;
grant execute on function public.cancel_match(uuid) to authenticated;
