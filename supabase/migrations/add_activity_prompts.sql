-- Migration: activity_prompts
--
-- Adds ready-made plans ("meet here, do this first, then this") that hang off an
-- activity, and has create_match attach one to every new match.
--
-- Safe to re-run. Apply in the Supabase SQL editor, then run
-- seed-sf-activities.sql to load the San Francisco catalog.

create table if not exists public.activity_prompts (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  meeting_point text not null,
  mission text not null,
  then_what text not null default '',
  plan_b text not null default '',
  duration_minutes int not null default 30 check (duration_minutes between 10 and 240),
  created_at timestamptz not null default now()
);

create index if not exists activity_prompts_activity_idx on public.activity_prompts(activity_id);

alter table public.activity_prompts enable row level security;

drop policy if exists "prompts readable" on public.activity_prompts;
create policy "prompts readable" on public.activity_prompts for select to authenticated using (true);

alter table public.matches
  add column if not exists prompt_id uuid references public.activity_prompts(id);

-- Existing rows keep prompt_id null; the UI falls back to the activity description.

create or replace function public.create_match(a uuid, b uuid)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  chosen record;
  slot record;
  mt timestamptz;
  new_match uuid;
  prompt uuid;
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
    (exists (select 1 from activity_prompts p where p.activity_id = act.id)) desc,
    act.is_scheduled_event desc,
    random()
  limit 1;

  if chosen is null then
    return null;
  end if;

  mt := case when chosen.is_scheduled_event then chosen.event_time else slot.t end;

  select p.id into prompt
  from activity_prompts p
  where p.activity_id = chosen.id
  order by random()
  limit 1;

  insert into matches (user_a, user_b, activity_id, prompt_id, meetup_time)
  values (a, b, chosen.id, prompt, mt)
  returning id into new_match;

  update profiles set needs_rematch = false where user_id in (a, b) and needs_rematch;

  return new_match;
end;
$$;

revoke execute on function public.create_match(uuid, uuid) from public, anon, authenticated;
