-- San Francisco catalog v1: cheap-or-free places, each with a few ready-made plans.
--
-- Prices and free-day rules were verified in September 2026 and will drift.
-- Requires the activity_prompts migration. Safe to re-run: new activities are
-- matched by title and prompts by mission text, so nothing duplicates.
--
-- Later this is replaced by an LLM pulling real-time events (activities.source).

-- ---------------------------------------------------------------------------
-- Places not already in seed.sql. Everything here is free or single digits, so
-- cost_level 1 — create_match filters on cost_level <= the stricter budget, and
-- a free activity should never be filtered out.
-- ---------------------------------------------------------------------------
insert into public.activities (title, description, bucket_id, venue, zipcode, cost_level, is_scheduled_event)
select v.title, v.description, b.id, v.venue, v.zipcode, v.cost_level, false
from (values
  ('Cable Car Museum',
   'Free museum inside the working powerhouse — watch the winding machinery that actually pulls the cables.',
   'Learning & Ideas', '1201 Mason Street', '94108', 1),
  ('Musee Mecanique',
   'Free entry, coin-operated antique arcade on Pier 45. Bring quarters.',
   'Games & Social', 'Pier 45, Fisherman''s Wharf', '94133', 1),
  ('Golden Gate Fortune Cookie Factory',
   'One room in an alley where cookies are still folded by hand. Cookies cost pocket change.',
   'Food & Drink', '56 Ross Alley, Chinatown', '94108', 1),
  ('Wave Organ',
   'Wave-powered stone sound sculpture on a Marina jetty, built from old headstones. Free, open 24 hours.',
   'Outdoors & Nature', 'Yacht Road jetty, Marina', '94123', 1),
  ('Seward Street Slides',
   'Two long concrete slides designed by a 14-year-old in 1973. Bring cardboard.',
   'Adventure & Thrill', '30 Seward Street, Castro', '94114', 1),
  ('Palace of Fine Arts',
   'The last building standing from the 1915 world''s fair. Grounds and lagoon are free, always open.',
   'Arts & Culture', 'Palace of Fine Arts, Marina', '94123', 1),
  ('16th Ave Tiled Steps',
   '163 mosaic steps made by 300 neighbors, with Grand View Park at the top.',
   'Fitness & Sports', '16th Avenue at Moraga, Sunset', '94122', 1),
  ('Fire pit at Ocean Beach',
   'Free first-come fire pits on the sand. Bring firewood and layers — it is always colder than you think.',
   'Outdoors & Nature', 'Ocean Beach, north end', '94122', 1)
) as v(title, description, bucket, venue, zipcode, cost_level)
join public.interest_buckets b on b.name = v.bucket
where not exists (select 1 from public.activities a where a.title = v.title);

-- Weekly recurring event: free swing dancing every Sunday since 1996, with a
-- free beginner lesson at noon. Scheduled events need an event_time, so this
-- points at the next Sunday. Re-run this file (or wire the update below to
-- cron) to roll it forward; a stale event_time just stops being matched.
insert into public.activities (title, description, bucket_id, venue, zipcode, cost_level, is_scheduled_event, event_time, source)
select 'Lindy in the Park',
       'Free social swing dancing on car-free JFK Drive every Sunday, with a free beginner lesson at noon.',
       b.id, 'JFK Drive at 9th Avenue, Golden Gate Park', '94118', 1, true,
       (select (day::timestamp + interval '11 hours 45 minutes') at time zone 'America/Los_Angeles'
        from generate_series((now() at time zone 'America/Los_Angeles')::date + 2,
                             (now() at time zone 'America/Los_Angeles')::date + 9,
                             interval '1 day') as d(day)
        where extract(dow from day) = 0
        order by day
        limit 1),
       'curated'
from public.interest_buckets b
where b.name = 'Games & Social'
  and not exists (select 1 from public.activities a where a.title = 'Lindy in the Park');

update public.activities
set event_time = (
  select (day::timestamp + interval '11 hours 45 minutes') at time zone 'America/Los_Angeles'
  from generate_series((now() at time zone 'America/Los_Angeles')::date + 2,
                       (now() at time zone 'America/Los_Angeles')::date + 9,
                       interval '1 day') as d(day)
  where extract(dow from day) = 0
  order by day
  limit 1
)
where title = 'Lindy in the Park'
  and (event_time is null or event_time < now() + interval '24 hours');

-- The de Young was seeded at cost_level 3, which hid it from anyone on a $ budget.
-- The Hamon Observation Tower needs no ticket at all, and the permanent collection
-- is free every Saturday for Bay Area residents and free to everyone after 4:30pm.
update public.activities set cost_level = 1 where title = 'de Young Museum visit';

-- ---------------------------------------------------------------------------
-- Plans. Three per place so a repeat visit is not identical.
--
-- meeting_point reads after "Meet at", then_what after "Then", plan_b after
-- "If that does not work". Specificity is pinned to things that cannot move —
-- rooms, signs, staircases, machinery, viewpoints — never to a single book,
-- menu item, or mural, because that inventory turns over and a script that
-- sends two strangers to something that is not there is worse than no script.
-- ---------------------------------------------------------------------------
insert into public.activity_prompts (activity_id, meeting_point, mission, then_what, plan_b, duration_minutes)
select a.id, v.meeting_point, v.mission, v.then_what, v.plan_b, v.duration_minutes
from (values
  -- Picnic at Dolores Park
  ('Picnic at Dolores Park',
   'the palm trees at 19th and Dolores',
   'Split up at the Bi-Rite window on 18th, each buy a scoop of a flavor you have never tried, then swap halfway through.',
   'Claim a spot on the hill facing downtown and take turns naming the buildings you can pick out.',
   'Bi-Rite line out the door? Gus''s Market on 17th sells the same ice cream with no wait.', 45),
  ('Picnic at Dolores Park',
   'the tennis courts at the top of the park',
   'Bring a deck of cards. Two rounds of anything — loser owes the other person something from the park cart.',
   'Walk down 18th to Tartine and split one pastry.',
   'Courts packed on a sunny day. The quieter north end by Church and 18th always has room.', 40),
  ('Picnic at Dolores Park',
   'the J-Church stop at Church and 18th',
   'Walk the whole edge of the park once, all the way around, and each point out one thing you had never noticed before.',
   'Pick a bench on the hill and stay as long as it stays warm.',
   'Raining? Dolores Park Cafe is right across the street at 18th and Dolores.', 30),

  -- Lands End coastal hike
  ('Lands End coastal hike',
   'the Lands End Lookout visitor center',
   'Walk out to the stone labyrinth on the cliff above Mile Rock Beach and walk it all the way to the center. It takes longer than it looks.',
   'Head back along the Coastal Trail to the Sutro Baths ruins.',
   'Visitors rearrange the labyrinth constantly. If it is scattered, rebuild a section of it instead.', 75),
  ('Lands End coastal hike',
   'the Sutro Baths ruins parking lot',
   'Find the sea cave tunnel cut through the cliff at the far end of the ruins and walk to the opening where it looks out at the water.',
   'Climb up to Sutro Heights Park for the view back over Ocean Beach.',
   'The tunnel floods at high tide. If the floor is wet, skip it — the ruins are the point anyway.', 60),
  ('Lands End coastal hike',
   'the USS San Francisco memorial at the end of El Camino del Mar',
   'Walk the trail toward Eagles Point and stop at every single bench. One question each per bench, anything you want.',
   'Clement Street is ten minutes away and has the cheapest good food in the city.',
   'Fogged in with no view? The trail still works — that is what the benches are for.', 60),

  -- de Young Museum visit
  ('de Young Museum visit',
   'Wilsey Court, just inside the de Young entrance, where no ticket is needed',
   'Take the elevator to the 9th-floor Hamon Observation Tower. It is free, always, with no ticket. Each of you find one landmark in the 360-degree view that the other cannot spot.',
   'The permanent collection is free every Saturday for Bay Area residents, and free to everyone after 4:30pm.',
   'The tower closes at 4:30 sharp. If you miss it, the Music Concourse fountain out front is a decent consolation.', 40),
  ('de Young Museum visit',
   'the sphinx statues outside the de Young entrance',
   'Go up the free tower first, then pick one gallery — only one — and find the piece you would steal.',
   'Walk across the Music Concourse to the Japanese Tea Garden, free to everyone 9 to 10am on Monday, Wednesday and Friday.',
   'Closed Mondays. The bison paddock is a 15-minute walk west.', 75),
  ('de Young Museum visit',
   'the copper facade on the Hagiwara Tea Garden Drive side',
   'Up in the free tower, each pick the neighborhood you would live in if money were no object, and argue for it.',
   'Coffee at the de Young cafe, which also needs no ticket.',
   'Line at the tower elevator? The sculpture garden is free and usually empty.', 35),

  -- Browse Green Apple Books
  ('Browse Green Apple Books',
   'the Staff Picks table at the front of Green Apple',
   'Ten minutes, no talking. Pick a book off the handwritten-card shelves for the other person. You each have to buy the one you were given.',
   'Read the first page of yours at the counter and report back.',
   'Too expensive? Used copies are upstairs and the rule still works.', 45),
  ('Browse Green Apple Books',
   'the front door at 506 Clement Street',
   'Each find the strangest book in the store. Strangest wins, and the loser buys it for the winner.',
   'Clement Street is right there — pick somewhere to eat that neither of you has tried.',
   'The store is a maze and you will lose each other. Agree to meet back at the register in 15 minutes.', 40),
  ('Browse Green Apple Books',
   'the fiction shelves on the ground floor',
   'Open a book at random, read one sentence out loud, and the other person has to guess what the book is about. Three rounds each.',
   'Arsicault around the corner for a croissant if it is still morning.',
   'Too crowded to be that person? Do it quietly in the used section upstairs.', 35),

  -- City Lights & North Beach stroll
  ('City Lights & North Beach stroll',
   'under the "Abandon All Despair, Ye Who Enter Here" sign at the City Lights front door',
   'Climb the 24 creaky steps to the Poetry Room on the top floor. Pick a book off those shelves for the other person and read them one line out loud.',
   'Vesuvio next door, or Jack Kerouac Alley through to Chinatown.',
   'The rocking Poet''s Chair by the window is usually taken. The floor is fair game — Ferlinghetti''s sign says to read here 14 hours a day.', 45),
  ('City Lights & North Beach stroll',
   'the information desk in the main room at City Lights',
   'Find as many of Ferlinghetti''s hand-lettered signs as you can. There are more than you would think, and "Stash Your Sell Phone and Be Here Now" is the one people walk past.',
   'Espresso at Caffe Trieste, where the regulars have been showing up for 60 years.',
   'The store is open late every night, so a slow start is fine.', 40),
  ('City Lights & North Beach stroll',
   'the bench in Jack Kerouac Alley, between City Lights and Vesuvio',
   'Each buy one Pocket Poets book — they are small and cheap — and read your favorite page out loud to the other person in the alley.',
   'Walk up to Washington Square and watch the pigeons ruin someone''s picnic.',
   'The alley is loud on weekend nights. The Poetry Room upstairs is the quietest room in North Beach.', 50),

  -- Ferry Building farmers market
  ('Ferry Building farmers market',
   'the clock tower entrance on the Embarcadero side',
   'Each buy one thing under five dollars that the other person has never eaten. No hints and no vetoing.',
   'Trade on the back steps facing the bay and rank what you picked.',
   'The full market is Saturday. Tuesday and Thursday are smaller but the rule still works.', 45),
  ('Ferry Building farmers market',
   'the Hog Island oyster counter inside the hall',
   'Walk the whole hall once without buying anything, then go back and buy only the thing you both pointed at.',
   'Out to the back rail to watch the Bay Bridge traffic you are not sitting in.',
   'Saturday mid-morning is a crush. Go at 8am or after 1pm.', 40),
  ('Ferry Building farmers market',
   'the Gandhi statue behind the Ferry Building',
   'Ten dollars each at the produce stalls. Build the best picnic you can between you. Eat it on the pier.',
   'Walk north along the Embarcadero to Pier 7 and out to the end.',
   'Windy days on the water are miserable. The benches inside the hall work fine.', 50),

  -- Murals of Clarion Alley
  ('Murals of Clarion Alley',
   'the Valencia Street entrance to Clarion Alley',
   'Walk the block slowly. Each pick the mural you would hang on your wall and the one you do not understand at all, and explain both.',
   'Balmy Alley is a ten-minute walk south and completely different in tone.',
   'The murals rotate constantly, so whatever is up is what is current. That is the appeal.', 30),
  ('Murals of Clarion Alley',
   'the corner of 17th and Mission',
   'Clarion first, then Balmy Alley. Take one photo each of the same mural from different angles and compare what you framed.',
   'A burrito on Mission Street, whichever place has the shorter line.',
   'The alleys are narrow and feel sketchy after dark. Keep this one to daylight.', 60),
  ('Murals of Clarion Alley',
   'Clarion Alley at Sycamore Street',
   'Find the oldest-looking piece in the alley and the newest, and guess how many layers of paint are between them.',
   'Dolores Park is six blocks west if the sun is out.',
   'If a crew is actively painting, stop and watch instead. Better than the finished wall.', 30),

  -- Dim sum in Chinatown
  ('Dim sum in Chinatown',
   'the Good Mong Kok counter at 1039 Stockton — cash only, no seating',
   'Eight dollars each, point at whatever you cannot identify, then eat it standing in Portsmouth Square next to the Chinese chess games.',
   'Walk up to the Tin How Temple on Waverly Place, the oldest one in the country.',
   'The line runs out the door at lunch. Eastern Bakery on Grant has egg tarts and no wait.', 45),
  ('Dim sum in Chinatown',
   'the Dragon Gate at Grant and Bush',
   'Walk Stockton Street, not Grant — Stockton is where the actual markets are. Each buy one ingredient you cannot name, then find someone who will tell you what it is.',
   'Cook it later, or do not. The asking is the activity.',
   'The markets close early, most by 6pm. Go before 4.', 50),
  ('Dim sum in Chinatown',
   'the benches in Portsmouth Square',
   'Split a pot of tea somewhere on Waverly Place and each tell the other one thing you got completely wrong about this city when you arrived.',
   'The Golden Gate Fortune Cookie Factory is four minutes away in Ross Alley.',
   'The square is full of card games and locals, which is a feature. If the benches are taken, sit on the steps.', 40),

  -- Explore Golden Gate Park
  ('Explore Golden Gate Park',
   'the Bison Paddock fence on JFK Drive',
   'Count the bison. There are usually around a dozen and they are almost always asleep. Then walk to Blue Heron Lake and around the island.',
   'Pedal boat at the boathouse if the line is short.',
   'Bison hiding at the far end? The Dutch windmill at the west end of the park is a ten-minute walk.', 75),
  ('Explore Golden Gate Park',
   'the Conservatory of Flowers steps',
   'Walk the park east to west and each pick one spot you would bring someone back to. You have to actually visit both.',
   'Come out at Ocean Beach and do not turn around until you have touched the water.',
   'The park is three miles end to end. If that is too far, do the eastern half and call it done.', 120),
  ('Explore Golden Gate Park',
   'the Spreckels Temple of Music bandshell on the Music Concourse',
   'On Sundays JFK Drive closes to cars. Walk down the middle of the road, which never stops feeling illegal.',
   'There is usually free music at the bandshell on Sunday afternoons. Sit down for whatever is playing.',
   'Weekday? The JFK Promenade stretch stays car-free every day of the week.', 60),

  -- Sunset at Twin Peaks
  ('Sunset at Twin Peaks',
   'the lower parking lot on Twin Peaks Boulevard',
   'Climb the north peak, then each point out where you live now and where you first lived in this city.',
   'Stay until the streetlights come on, which happens all at once.',
   'Fogged in, which is often. Corona Heights on Roosevelt Way sits below the fog line far more reliably.', 60),
  ('Sunset at Twin Peaks',
   'the Christmas Tree Point overlook',
   'Take one photo of the view, then both of you put the phones away for the rest of the time you are up there.',
   'Walk down into the Castro for food. It is steep and about 25 minutes.',
   'It is always colder and windier up there than you expect. Bring a layer or retreat to the car.', 45),
  ('Sunset at Twin Peaks',
   'the bus stop at Portola and Twin Peaks Boulevard',
   'Take the 37 up so neither of you has to drive or park, and each bring one thing to share at the top.',
   'Mount Davidson is the next hill south and taller, if you still have legs.',
   'Sunset is the crowded hour. Sunrise is empty and better.', 50),

  -- Mission burrito crawl
  ('Mission burrito crawl',
   'the counter at La Taqueria, 2889 Mission',
   'Order for each other, fifteen dollar cap. Get it with no rice — that is the house style and half the reason people argue about this place.',
   'Walk it off down Mission and settle whether the no-rice thing is genius or a con.',
   'Closed Wednesdays and sometimes Tuesdays. El Farolito on 24th basically never closes.', 50),
  ('Mission burrito crawl',
   'the 24th Street BART plaza',
   'One burrito from two different places, split both, and score them out of ten on tortilla, salsa, and structural integrity.',
   'Dessert at Koolfi Creamery — saffron and cardamom, not vanilla.',
   'That is too much food for two people. Order one burrito and one taco instead.', 60),
  ('Mission burrito crawl',
   'the corner of 24th and Alabama',
   'Each name what you think is the best burrito in the city, then go to the other person''s pick first.',
   'The Balmy Alley murals are right there and you will need the walk.',
   'Whoever''s pick is closed, the other one wins by default.', 55),

  -- Cable Car Museum
  ('Cable Car Museum',
   'under the museum arch at 1201 Mason Street',
   'Stand at the observation rail above the winding machinery, each pick one of the four cables, and follow it by eye. Then go down to the sheave room and find the window where your cable disappears under the street.',
   'Walk down to Chinatown — four blocks and all downhill.',
   'Closed Mondays. The Powell Street turntable is ten minutes away and free to watch.', 40),
  ('Cable Car Museum',
   'the corner of Mason and Washington',
   'Find the 1873 Clay Street Hill Railroad grip car, the only surviving car from the first cable car company in the world, and work out how you would have braked it.',
   'Coffee on Polk Street, downhill in the other direction.',
   'If a tour group has the gallery, start in the sheave room downstairs and work upward.', 35),
  ('Cable Car Museum',
   'the museum store just inside the entrance',
   'The machinery is loud enough that you have to lean in to talk. Use that: one question each that you would not ask across a table.',
   'Walk to the top of Nob Hill for the Grace Cathedral labyrinth, also free.',
   'Admission is free so it is never a wasted trip, but check the hours — they shift with the season.', 30),

  -- Musee Mecanique
  ('Musee Mecanique',
   'Laffing Sal, just inside the door at Pier 45',
   'Get five dollars in quarters each. Spend all of yours on machines for the other person to watch — you do not get to play your own.',
   'Walk the pier out to the WWII submarine and the Hyde Street ships.',
   'The change machine is often empty. Bring quarters or break a bill at the cafe next door.', 45),
  ('Musee Mecanique',
   'the fortune teller machine near the entrance',
   'Each get a fortune from a different machine, trade them, and spend the rest of your quarters trying to make the other person''s come true.',
   'Ghirardelli Square is a 15-minute walk along the water.',
   'Entry is free, so even with no cash the loop is worth it.', 40),
  ('Musee Mecanique',
   'the arm-wrestling machine',
   'Find the oldest machine in the room that still works and play it. Some of these are from the 1890s.',
   'Sea lions at Pier 39, ten minutes east and free.',
   'Weekend afternoons are wall-to-wall. Weekday mornings it is nearly empty.', 35),

  -- Golden Gate Fortune Cookie Factory
  ('Golden Gate Fortune Cookie Factory',
   'the doorway at 56 Ross Alley — you will smell it before you see it',
   'Watch the cookies come off the press and get folded by hand, buy a bag, and write a fortune for each other on the back of the receipt.',
   'Walk Ross Alley out to Jackson and up to Waverly Place.',
   'It is one room that barely fits four people. If there is a line, wait — it moves in minutes.', 25),
  ('Golden Gate Fortune Cookie Factory',
   'the Ross Alley entrance off Jackson Street',
   'Buy the flat unfolded cookies, which are cheap, and each guess what the other person''s fortune says before opening it.',
   'Dim sum at Good Mong Kok on Stockton, five minutes away, cash only.',
   'Cash is strongly preferred here. Bring a few dollars.', 20),
  ('Golden Gate Fortune Cookie Factory',
   'the corner of Grant and Jackson',
   'Find the alley first — it is unmarked and easy to walk straight past. Then buy one bag and hand cookies to strangers until it is empty.',
   'Portsmouth Square to watch the chess games.',
   'Closes around 7pm and earlier some days. Afternoon is safest.', 30),

  -- Wave Organ
  ('Wave Organ',
   'the end of the jetty past the St. Francis Yacht Club',
   'Check the tide chart before you leave and go at high tide. Put your ear to different pipes, find the one that sounds best, and make the other person listen to it.',
   'Walk back along the Marina Green toward the Palace of Fine Arts.',
   'At low tide it is nearly silent — but it is still one of the best skyline views in the city.', 40),
  ('Wave Organ',
   'the parking lot at the end of Yacht Road',
   'Sit in the stone chamber at the end and stay completely quiet for five full minutes. Then say what you heard.',
   'Crissy Field is a 20-minute walk west with the bridge in front of you the whole way.',
   'Open 24 hours and never crowded, so the only thing that matters is the tide.', 35),
  ('Wave Organ',
   'the first bench on the jetty',
   'The whole thing is built from demolished cemetery headstones. Find a piece with the carving still visible on it.',
   'The Palace of Fine Arts is ten minutes south.',
   'Wind on that jetty is serious. If it is howling, do the Palace first and come back.', 30),

  -- Seward Street Slides
  ('Seward Street Slides',
   'the top of the slides at 30 Seward Street',
   'Bring cardboard. Time each other, best of three, loser buys coffee.',
   'Walk down into the Castro for that coffee.',
   'There is usually leftover cardboard at the top. If not, any flattened box works.', 30),
  ('Seward Street Slides',
   'the Seward Mini Park entrance on Seward Street',
   'Two slides, side by side. Race. Then race again sitting backwards, which is objectively a bad idea.',
   'Corona Heights is ten minutes up the hill for the view.',
   'Open Tuesday through Sunday, 10 to 5, and closed when wet.', 25),
  ('Seward Street Slides',
   'the bench at the bottom of the slides',
   'A 14-year-old designed these in 1973 after winning a neighborhood design contest. Go down once, then decide whether she deserved to win.',
   'Dolores Park is a 15-minute walk east.',
   'Kids have priority and the park is small. Weekday afternoons are quieter.', 25),

  -- Palace of Fine Arts
  ('Palace of Fine Arts',
   'the rotunda steps facing the lagoon',
   'Find the weeping women on top of the colonnade urns and work out why they are facing inward, away from everyone.',
   'Walk the lagoon loop and count the swans.',
   'The grounds are free and open all the time. Rain actually improves the photos.', 40),
  ('Palace of Fine Arts',
   'the far side of the lagoon, facing the dome',
   'The whole thing was built for the 1915 world''s fair out of plaster and meant to be demolished afterward. Each pick the detail you would have saved.',
   'The Wave Organ is a ten-minute walk north and completely different.',
   'Wedding shoots take over the rotunda on weekends. The lagoon side is always clear.', 35),
  ('Palace of Fine Arts',
   'the colonnade at the east end',
   'Stand at opposite ends of the colonnade and talk at normal volume. The acoustics do something strange. Find the point where it stops working.',
   'Crissy Field and the bridge, 15 minutes west.',
   'If it is packed, the lagoon benches on the residential side are always empty.', 30),

  -- 16th Ave Tiled Steps
  ('16th Ave Tiled Steps',
   'the bottom of the tiled steps at 16th Avenue and Moraga',
   '163 steps. Count the animals in the mosaic on the way up — you will disagree on the total.',
   'Keep climbing to Grand View Park for the best view in the Sunset.',
   'The Hidden Garden Steps on 16th at Kirkham are two blocks away and less known.', 45),
  ('16th Ave Tiled Steps',
   'the corner of 16th and Noriega',
   'Steps first, then Grand View, then Golden Gate Heights. Three summits, each one better, none more than 15 minutes apart.',
   'Andytown on Lawton for coffee when you come down.',
   'Fog rolls in fast out here. Go in the morning — it usually burns off by 11.', 70),
  ('16th Ave Tiled Steps',
   'the top of the tiled steps',
   'Come down the steps instead of up, slowly, and each pick your favorite tile. Three hundred neighbors made this mosaic.',
   'Walk to Sunset Dunes on the old Great Highway and out to the water.',
   'The steps are steep with no railing in places. Take the Moraga sidewalk if that is a problem.', 40),

  -- Lindy in the Park
  ('Lindy in the Park',
   'JFK Drive between 8th and 10th Avenue, by the speakers',
   'Free beginner swing lesson at noon. No partner and no experience needed — just be there by 11:55.',
   'Stay for the social dancing afterward, or walk over to the Music Concourse.',
   'Cancelled if it rains. The de Young''s free observation tower is a five-minute walk.', 90),
  ('Lindy in the Park',
   'the edge of the dance floor on JFK Drive at 9th Avenue',
   'Watch for ten minutes, each pick one move you think you could manage, then take the noon lesson and try it.',
   'The Japanese Tea Garden or the bandshell, both walking distance.',
   'Nervous? Standing and watching is completely normal here and nobody will make you dance.', 90),
  ('Lindy in the Park',
   'the 44 bus stop at 9th and Lincoln',
   'Neither of you has to be good at this. Take the lesson, then dance with each other exactly once before you are allowed to quit.',
   'Food on Irving Street, two blocks south.',
   'It is volunteer-run and weather-dependent. Check before you go.', 75),

  -- Fire pit at Ocean Beach
  ('Fire pit at Ocean Beach',
   'the fire pit closest to the Beach Chalet at the north end of Ocean Beach',
   'Pits are free and first-come. Bring firewood and one snack each, claim a pit before sunset, and split s''mores duty.',
   'Stay until the fire is fully out — you are required to put it out anyway.',
   'All the pits go early on a warm Friday. Get there before sunset, or just sit on the sand with a blanket.', 120),
  ('Fire pit at Ocean Beach',
   'the Great Highway parking lot at Fulton',
   'Sunset over the water first, then light the fire. Each bring one thing to burn that is not trash — driftwood counts.',
   'Walk the shoreline north toward the Cliff House ruins.',
   'Fire rules change seasonally and pits close in high wind. Check before you haul wood out there.', 120),
  ('Fire pit at Ocean Beach',
   'the octopus sculpture at Sloat and the Great Highway',
   'Walk the car-free Sunset Dunes promenade south to north at dusk, then take a pit if one is open.',
   'Java Beach on Judah is open late for something warm.',
   'It is always cold and windy at Ocean Beach. Two layers more than you think.', 100)
) as v(activity_title, meeting_point, mission, then_what, plan_b, duration_minutes)
join public.activities a on a.title = v.activity_title
where not exists (
  select 1 from public.activity_prompts p
  where p.activity_id = a.id and p.mission = v.mission
);
