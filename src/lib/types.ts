export type Gender = "woman" | "man" | "nonbinary" | "other";
export type TimeBlock = "morning" | "afternoon" | "evening";

export interface InterestBucket {
  id: number;
  name: string;
  emoji: string;
}

export interface Activity {
  id: string;
  title: string;
  description: string;
  bucket_id: number;
  venue: string;
  zipcode: string;
  cost_level: number;
  is_scheduled_event: boolean;
  event_time: string | null;
  source: string;
}

export interface Profile {
  user_id: string;
  first_name: string;
  age: number | null;
  gender: Gender | null;
  zipcode: string;
  budget_level: number;
  personality_type: string | null;
  strike_count: number;
  is_suspended: boolean;
  needs_rematch: boolean;
  onboarding_complete: boolean;
  is_demo: boolean;
}

export interface Preferences {
  user_id: string;
  age_min: number;
  age_max: number;
  gender_pref: "any" | "woman" | "man" | "nonbinary";
  max_distance_km: number;
  notification_pref: "day_before" | "two_days_before" | "week_before";
}

export interface AvailabilitySlot {
  day_of_week: number;
  time_block: TimeBlock;
}

export interface Match {
  id: string;
  user_a: string;
  user_b: string;
  activity_id: string;
  meetup_time: string;
  status: "proposed" | "confirmed" | "completed" | "cancelled" | "no_show";
  a_confirmed: boolean;
  b_confirmed: boolean;
  cancelled_by: string | null;
  created_at: string;
}

export interface MatchPartner {
  match_id: string;
  partner_id: string;
  first_name: string;
  age: number;
  gender: Gender;
  is_demo: boolean;
}

export interface Message {
  id: number;
  match_id: string;
  sender_id: string;
  body: string;
  created_at: string;
}

export const DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
export const TIME_BLOCKS: TimeBlock[] = ["morning", "afternoon", "evening"];
export const BUDGET_LABELS = ["$", "$$", "$$$", "$$$$"];

/** Chat opens 24h before the meetup and closes 2h after. */
export function chatWindow(meetupTime: string) {
  const t = new Date(meetupTime).getTime();
  const now = Date.now();
  const opens = t - 24 * 60 * 60 * 1000;
  const closes = t + 2 * 60 * 60 * 1000;
  return {
    opensAt: new Date(opens),
    closesAt: new Date(closes),
    isOpen: now >= opens && now <= closes,
    isPast: now > closes,
  };
}
