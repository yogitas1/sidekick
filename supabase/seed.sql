-- Curated SF catalog: interest buckets, activities, and zip centroids.

insert into public.interest_buckets (name, emoji) values
  ('Food & Drink', '🍜'),
  ('Outdoors & Nature', '🌳'),
  ('Arts & Culture', '🎨'),
  ('Adventure & Thrill', '🪂'),
  ('Markets & Shopping', '🛍️'),
  ('Fitness & Sports', '🏃'),
  ('Games & Social', '🎲'),
  ('Learning & Ideas', '📚');

insert into public.zip_geo (zipcode, lat, lng) values
  ('94102', 37.7793, -122.4193), ('94103', 37.7726, -122.4099),
  ('94107', 37.7621, -122.3971), ('94108', 37.7929, -122.4079),
  ('94109', 37.7925, -122.4204), ('94110', 37.7485, -122.4156),
  ('94112', 37.7195, -122.4411), ('94114', 37.7583, -122.4351),
  ('94115', 37.7856, -122.4370), ('94116', 37.7441, -122.4863),
  ('94117', 37.7692, -122.4449), ('94118', 37.7822, -122.4610),
  ('94121', 37.7786, -122.4892), ('94122', 37.7593, -122.4836),
  ('94123', 37.7999, -122.4342), ('94124', 37.7309, -122.3886),
  ('94127', 37.7354, -122.4571), ('94131', 37.7451, -122.4383),
  ('94132', 37.7211, -122.4754), ('94133', 37.8002, -122.4091),
  ('94134', 37.7190, -122.4096), ('94158', 37.7690, -122.3891),
  ('94607', 37.8078, -122.2852), ('94610', 37.8110, -122.2440),
  ('94704', 37.8666, -122.2590), ('94014', 37.6879, -122.4702);

-- Anytime activities
insert into public.activities (title, description, bucket_id, venue, zipcode, cost_level, is_scheduled_event) values
  ('Picnic at Dolores Park', 'Grab snacks and claim a sunny patch of grass with the best skyline view in the Mission.', (select id from interest_buckets where name='Outdoors & Nature'), 'Mission Dolores Park', '94114', 1, false),
  ('Mission burrito crawl', 'Settle the great burrito debate: La Taqueria vs. El Farolito vs. Taqueria Cancún.', (select id from interest_buckets where name='Food & Drink'), 'Mission District', '94110', 1, false),
  ('Ferry Building farmers market', 'Saturday-morning stroll through stalls of local produce, oysters, and porchetta sandwiches.', (select id from interest_buckets where name='Markets & Shopping'), 'Ferry Building', '94111', 2, false),
  ('Explore Golden Gate Park', 'Wander from the bison paddock to Stow Lake — rent a paddle boat if you dare.', (select id from interest_buckets where name='Outdoors & Nature'), 'Golden Gate Park', '94117', 1, false),
  ('Lands End coastal hike', 'Cliffside trail with Golden Gate views, ending at the Sutro Baths ruins.', (select id from interest_buckets where name='Outdoors & Nature'), 'Lands End', '94121', 1, false),
  ('SFMOMA afternoon', 'Seven floors of modern art — start at the Rothkos and argue about what counts as art.', (select id from interest_buckets where name='Arts & Culture'), 'SFMOMA', '94103', 3, false),
  ('de Young Museum visit', 'Art in the park, plus the free observation tower with 360° city views.', (select id from interest_buckets where name='Arts & Culture'), 'de Young Museum', '94118', 3, false),
  ('Dim sum in Chinatown', 'Point at carts, share everything, and find out who orders the chicken feet.', (select id from interest_buckets where name='Food & Drink'), 'Chinatown', '94108', 2, false),
  ('Try a new coffee shop', 'Pick a neighborhood café neither of you has tried — Ritual, Sightglass, or a hidden gem.', (select id from interest_buckets where name='Food & Drink'), 'Your pick', '94110', 1, false),
  ('Climb at Mission Cliffs', 'Indoor bouldering — beginner friendly, and falling on padded floors is half the fun.', (select id from interest_buckets where name='Fitness & Sports'), 'Mission Cliffs', '94110', 3, false),
  ('Run the Embarcadero', 'Easy 5k along the waterfront from the Ferry Building to Oracle Park and back.', (select id from interest_buckets where name='Fitness & Sports'), 'Embarcadero', '94105', 1, false),
  ('Board game night at a café', 'Settle in at a game café and let the loser buy the next round of drinks.', (select id from interest_buckets where name='Games & Social'), 'Game Parlour', '94122', 2, false),
  ('Karaoke in Japantown', 'Private room, zero judgment, at least one dramatic ballad required.', (select id from interest_buckets where name='Games & Social'), 'Japantown', '94115', 2, false),
  ('Sunset at Twin Peaks', 'Short climb, huge payoff — the whole city lighting up at golden hour.', (select id from interest_buckets where name='Outdoors & Nature'), 'Twin Peaks', '94131', 1, false),
  ('Browse Green Apple Books', 'Get lost in the used-book maze and pick a book for each other.', (select id from interest_buckets where name='Markets & Shopping'), 'Green Apple Books', '94118', 2, false),
  ('Thrift the Haight', 'Vintage stores and oddity shops along Haight Street — best find under $20 wins.', (select id from interest_buckets where name='Markets & Shopping'), 'Haight-Ashbury', '94117', 2, false),
  ('Alamo Square + Painted Ladies', 'Classic postcard views, then coffee on Divisadero.', (select id from interest_buckets where name='Outdoors & Nature'), 'Alamo Square', '94117', 1, false),
  ('Exploratorium after dark', 'A science museum you''re allowed to touch — even better with someone competitive.', (select id from interest_buckets where name='Learning & Ideas'), 'Exploratorium', '94111', 3, false),
  ('California Academy of Sciences', 'Aquarium, planetarium, rainforest dome, and a very chill albino alligator.', (select id from interest_buckets where name='Learning & Ideas'), 'Cal Academy', '94118', 3, false),
  ('Try axe throwing', 'Surprisingly beginner-friendly, deeply satisfying, great story afterward.', (select id from interest_buckets where name='Adventure & Thrill'), 'SoMa', '94103', 3, false),
  ('Surf lesson at Pacifica', 'Wetsuits provided, dignity optional — Linda Mar is the classic beginner break.', (select id from interest_buckets where name='Adventure & Thrill'), 'Pacifica', '94044', 3, false),
  ('Go-karts at K1 Speed', 'Electric go-karts, live lap times, instant rivalry.', (select id from interest_buckets where name='Adventure & Thrill'), 'K1 Speed', '94124', 3, false),
  ('Skydive over the Bay', 'Tandem jump with coastline views — the ultimate ice breaker.', (select id from interest_buckets where name='Adventure & Thrill'), 'Skydive California', '95376', 4, false),
  ('Ramen tour in the Richmond', 'Compare tonkotsu notes across Clement Street''s best spots.', (select id from interest_buckets where name='Food & Drink'), 'Inner Richmond', '94118', 2, false),
  ('Bakery hop: Tartine to Arsicault', 'A structured croissant investigation. For science.', (select id from interest_buckets where name='Food & Drink'), 'Mission → Richmond', '94110', 2, false),
  ('Pickup volleyball at Ocean Beach', 'Casual beach volleyball — all skill levels, bring a hoodie for the fog.', (select id from interest_buckets where name='Fitness & Sports'), 'Ocean Beach', '94122', 1, false),
  ('Yoga in the park', 'Outdoor flow session at Marina Green, then smoothies after.', (select id from interest_buckets where name='Fitness & Sports'), 'Marina Green', '94123', 1, false),
  ('Murals of Clarion Alley', 'Self-guided street-art walk through the Mission''s open-air gallery.', (select id from interest_buckets where name='Arts & Culture'), 'Clarion Alley', '94110', 1, false),
  ('City Lights & North Beach stroll', 'Browse the legendary Beat bookstore, then espresso at Caffe Trieste.', (select id from interest_buckets where name='Learning & Ideas'), 'North Beach', '94133', 1, false),
  ('Trivia night at a local pub', 'Join forces for pub trivia — useless knowledge finally pays off.', (select id from interest_buckets where name='Games & Social'), 'Your local', '94117', 2, false);

-- Sample scheduled events at sensible local times on upcoming days.
-- In production these rows come from event-platform integrations (source column).
insert into public.activities (title, description, bucket_id, venue, zipcode, cost_level, is_scheduled_event, event_time, source) values
  ('Off the Grid food truck party', 'Dozens of food trucks, live music, fire pits at Fort Mason.', (select id from interest_buckets where name='Food & Drink'), 'Fort Mason Center', '94123', 2, true, ((now() at time zone 'America/Los_Angeles')::date + 3)::timestamp at time zone 'America/Los_Angeles' + interval '18 hours', 'curated'),
  ('First Thursday gallery walk', 'Downtown galleries open late with free wine and new exhibitions.', (select id from interest_buckets where name='Arts & Culture'), 'Union Square galleries', '94108', 1, true, ((now() at time zone 'America/Los_Angeles')::date + 5)::timestamp at time zone 'America/Los_Angeles' + interval '17 hours', 'curated'),
  ('Community run club 5k', 'Friendly group run along Crissy Field, coffee after.', (select id from interest_buckets where name='Fitness & Sports'), 'Crissy Field', '94129', 1, true, ((now() at time zone 'America/Los_Angeles')::date + 4)::timestamp at time zone 'America/Los_Angeles' + interval '9 hours', 'curated'),
  ('Stern Grove summer concert', 'Free outdoor concert in a eucalyptus grove amphitheater.', (select id from interest_buckets where name='Arts & Culture'), 'Stern Grove', '94132', 1, true, ((now() at time zone 'America/Los_Angeles')::date + 7)::timestamp at time zone 'America/Los_Angeles' + interval '14 hours', 'curated');
