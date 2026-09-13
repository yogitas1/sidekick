# Sidekick (Community Builder prototype)

**Meetup + Bumble BFF in one.** Users get matched with a compatible person *and* a concrete
activity they both want to do, at a time they're both free — so the meetup actually happens.

Working name: **Sidekick** (placeholder — rename in `src/app/layout.tsx` and the page headers).

## How it works

1. **Onboard** — age/gender, budget, optional 4-question personality quiz, pick **8 activities**
   you'd genuinely do (these map to interest buckets), match preferences (age range, gender,
   distance, notification timing), zipcode, and a weekly availability grid.
2. **Match** — the `find_match` Postgres function scores candidates by shared interest buckets,
   availability overlap, budget compatibility, personality, and rematch priority; filters by
   mutual age/gender preferences and zipcode distance; then proposes a specific activity + time.
3. **A plan, not just a place** — every match also gets one of the activity's `activity_prompts`:
   where exactly to meet, one concrete thing to do first, where to go after, and a plan B. The
   point is that neither person has to decide anything in the first ten minutes.
4. **Confirm** — both sides confirm ("demo users" auto-confirm so you can test solo).
5. **Chat** — opens 24 hours before the meetup, closes 2 hours after. Enforced by RLS, not just UI.
6. **Feedback** — post-meetup form. A no-show report adds a strike; **3 strikes suspends the
   account**. Cancelling flags your match for a priority rematch.

## Stack

- **Next.js 16** (App Router, TypeScript, Tailwind v4) — pages in `src/app/`, server actions in
  [src/lib/actions.ts](src/lib/actions.ts), route protection in [src/proxy.ts](src/proxy.ts)
- **Supabase** — auth, Postgres with RLS, Realtime chat. All matching/lifecycle logic lives in
  `security definer` functions ([supabase/schema.sql](supabase/schema.sql)) so the app never
  needs a service-role key.

## Running locally

```bash
npm install
npm run dev   # http://localhost:3000
```

`.env.local` needs (see `.env.example`):

```
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
```

The connected Supabase project is `community-builder` (`bwoulmnrlthohjroexzf`). To recreate the
backend from scratch: run `supabase/schema.sql`, then `supabase/seed.sql`, then
`supabase/seed-sf-activities.sql`, then `supabase/seed-demo-users.sql` in the SQL editor of a
fresh project.

Against the **existing** project, run `supabase/migrations/add_activity_prompts.sql` first (the
snapshot in `schema.sql` already includes it), then `supabase/seed-sf-activities.sql`. Both are
idempotent and safe to re-run — and re-running the seed rolls recurring weekly events like Lindy
in the Park forward to the next Sunday.

### Testing tips

- Eight **demo users** (Maya, Alex, Sam, Priya, Jordan, Elena, Dev, Grace) are seeded with
  varied interests/availability, so "Find my match" works with a single real account.
  Demo users auto-confirm matches and are labeled in the UI; they don't reply in chat.
- **Email confirmation** is ON by default. For friction-free signups while testing, turn off
  *Confirm email* in Supabase Dashboard → Authentication → Sign In / Providers → Email.
  (Recommended while testing: also enable *leaked password protection* on the same page.)
- To see the chat window open without waiting, move a confirmed match's `meetup_time` to within
  24h in the SQL editor.
- `npm run dev`/`start` set `NODE_OPTIONS=--use-system-ca` (via cross-env) because antivirus
  TLS interception on some Windows machines breaks Node's fetch to Supabase otherwise.

## Deliberate v1 scope cuts (v2 backlog)

- **Solo mode** event browser (aggregated events, no matching)
- **Real event integrations** — Eventbrite's public search API is discontinued and Luma's API is
  invite-only; Ticketmaster Discovery API is the most viable first integration. The
  `activities.source` column is ready for these.
- **Weekly automated matching** — `find_match` is on-demand via a dashboard button; schedule it
  with pg_cron or a Vercel cron for the weekly cadence.
- **Notifications** — preferences are stored (`preferences.notification_pref`) but nothing sends
  email/push yet.
- **Activity prompts are hand-written** for ~20 places (3 each) and the prices and free-day rules
  in them were verified in September 2026, so they will drift. They're split from the place on
  purpose: an LLM can regenerate prompts later without re-verifying locations.
- **No exposure dial** — a meaningful share of people won't do anything performative in public
  with a stranger, and every prompt currently assumes they will. A low-key variant per prompt,
  plus a preference to select it, is the obvious next step.
- Group matching, calendar integration, "similar background" matching, interaction-level pairing.
