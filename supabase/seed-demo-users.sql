-- Eight demo users (auth accounts + full profiles) so matching is testable with one real account.
-- Demo users auto-confirm matches (see confirm_match) and are labeled in the UI.
-- Their password is 'demo-pass-1234' if you ever want to log in as one.

do $$
declare
  u record;
  uid uuid;
begin
  for u in
    select * from (values
      ('maya@demo.communitybuilder.app',  'Maya',  27, 'woman',     '94110', 2, 'ENFP', array['Food & Drink','Outdoors & Nature','Markets & Shopping']),
      ('alex@demo.communitybuilder.app',  'Alex',  30, 'man',       '94117', 2, 'INTJ', array['Outdoors & Nature','Fitness & Sports','Learning & Ideas']),
      ('sam@demo.communitybuilder.app',   'Sam',   25, 'nonbinary', '94103', 1, 'ENFP', array['Arts & Culture','Games & Social','Food & Drink']),
      ('priya@demo.communitybuilder.app', 'Priya', 29, 'woman',     '94114', 3, 'INFJ', array['Food & Drink','Arts & Culture','Learning & Ideas']),
      ('jordan@demo.communitybuilder.app','Jordan',33, 'man',       '94122', 2, 'ESTP', array['Fitness & Sports','Adventure & Thrill','Games & Social']),
      ('elena@demo.communitybuilder.app', 'Elena', 35, 'woman',     '94123', 3, 'ISFJ', array['Markets & Shopping','Arts & Culture','Outdoors & Nature']),
      ('dev@demo.communitybuilder.app',   'Dev',   24, 'man',       '94109', 1, 'ENTP', array['Games & Social','Food & Drink','Adventure & Thrill']),
      ('grace@demo.communitybuilder.app', 'Grace', 38, 'woman',     '94131', 2, 'INFP', array['Learning & Ideas','Outdoors & Nature','Markets & Shopping'])
    ) as t(email, first_name, age, gender, zipcode, budget, ptype, buckets)
  loop
    uid := gen_random_uuid();

    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', u.email,
            extensions.crypt('demo-pass-1234', extensions.gen_salt('bf')), now(),
            '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now());

    insert into public.profiles (user_id, first_name, age, gender, zipcode, budget_level, personality_type, onboarding_complete, is_demo)
    values (uid, u.first_name, u.age, u.gender, u.zipcode, u.budget, u.ptype, true, true);

    insert into public.preferences (user_id, age_min, age_max, gender_pref, max_distance_km)
    values (uid, 21, 45, 'any', 25);

    insert into public.availability (user_id, day_of_week, time_block) values
      (uid, 6, 'morning'), (uid, 6, 'afternoon'), (uid, 0, 'morning'), (uid, 0, 'afternoon'),
      (uid, 3, 'evening'), (uid, 4, 'evening');

    insert into public.user_interests (user_id, activity_id, bucket_id)
    select uid, a.id, a.bucket_id
    from public.activities a
    join public.interest_buckets b on b.id = a.bucket_id
    where b.name = any(u.buckets)
    order by random()
    limit 8;
  end loop;
end $$;
