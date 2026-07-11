"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { AvailabilitySlot } from "@/lib/types";

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/");
}

/**
 * zip_geo holds all ~33k US ZIP centroids, so an unknown zip is a typo,
 * not a coverage gap. Rejecting it here keeps the distance filter honest —
 * find_match skips distance entirely for zips it can't resolve.
 */
async function validateZipcode(zipcode: string): Promise<string | null> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("zip_geo")
    .select("zipcode")
    .eq("zipcode", zipcode)
    .maybeSingle();
  return data ? null : "We don't recognize that zipcode — double-check it?";
}

export interface OnboardingData {
  firstName: string;
  age: number;
  gender: string;
  budgetLevel: number;
  personalityType: string | null;
  activityIds: string[];
  ageMin: number;
  ageMax: number;
  genderPref: string;
  maxDistanceKm: number;
  notificationPref: string;
  zipcode: string;
  availability: AvailabilitySlot[];
}

export async function saveOnboarding(data: OnboardingData): Promise<{ error?: string }> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Not signed in" };

  const zipError = await validateZipcode(data.zipcode);
  if (zipError) return { error: zipError };

  const { error: profileError } = await supabase.from("profiles").upsert({
    user_id: user.id,
    first_name: data.firstName,
    age: data.age,
    gender: data.gender,
    zipcode: data.zipcode,
    budget_level: data.budgetLevel,
    personality_type: data.personalityType,
    onboarding_complete: true,
  });
  if (profileError) return { error: profileError.message };

  const { error: prefError } = await supabase.from("preferences").upsert({
    user_id: user.id,
    age_min: data.ageMin,
    age_max: data.ageMax,
    gender_pref: data.genderPref,
    max_distance_km: data.maxDistanceKm,
    notification_pref: data.notificationPref,
  });
  if (prefError) return { error: prefError.message };

  // Replace availability
  await supabase.from("availability").delete().eq("user_id", user.id);
  if (data.availability.length > 0) {
    const { error } = await supabase
      .from("availability")
      .insert(data.availability.map((s) => ({ user_id: user.id, ...s })));
    if (error) return { error: error.message };
  }

  // Replace interests (bucket_id comes from the chosen activities)
  const { data: activities, error: actError } = await supabase
    .from("activities")
    .select("id, bucket_id")
    .in("id", data.activityIds);
  if (actError) return { error: actError.message };

  await supabase.from("user_interests").delete().eq("user_id", user.id);
  const { error: intError } = await supabase.from("user_interests").insert(
    (activities ?? []).map((a) => ({
      user_id: user.id,
      activity_id: a.id,
      bucket_id: a.bucket_id,
    }))
  );
  if (intError) return { error: intError.message };

  revalidatePath("/dashboard");
  redirect("/dashboard");
}

export async function findMatch(): Promise<{ matchId?: string; error?: string }> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("find_match");
  if (error) return { error: error.message };
  if (!data) {
    return {
      error:
        "No compatible match right now — try widening your preferences or adding more availability.",
    };
  }
  revalidatePath("/dashboard");
  return { matchId: data as string };
}

export async function confirmMatch(matchId: string): Promise<{ error?: string }> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("confirm_match", { p_match_id: matchId });
  if (error) return { error: error.message };
  revalidatePath("/dashboard");
  revalidatePath(`/match/${matchId}`);
  return {};
}

export async function cancelMatch(matchId: string): Promise<{ error?: string }> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("cancel_match", { p_match_id: matchId });
  if (error) return { error: error.message };
  revalidatePath("/dashboard");
  revalidatePath(`/match/${matchId}`);
  return {};
}

export async function submitFeedback(input: {
  matchId: string;
  showedUp: boolean;
  rating: number | null;
  wouldMeetAgain: boolean | null;
  comments: string;
}): Promise<{ error?: string }> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Not signed in" };

  const { data: partner, error: partnerError } = await supabase
    .rpc("match_partners")
    .select("partner_id")
    .eq("match_id", input.matchId)
    .single();
  if (partnerError || !partner) return { error: "Match not found" };

  const { error } = await supabase.from("feedback").insert({
    match_id: input.matchId,
    rater_id: user.id,
    ratee_id: partner.partner_id,
    showed_up: input.showedUp,
    rating: input.rating,
    would_meet_again: input.wouldMeetAgain,
    comments: input.comments,
  });
  if (error) return { error: error.message };

  revalidatePath("/dashboard");
  redirect("/dashboard");
}

export interface SettingsData {
  firstName: string;
  age: number;
  budgetLevel: number;
  zipcode: string;
  ageMin: number;
  ageMax: number;
  genderPref: string;
  maxDistanceKm: number;
  notificationPref: string;
  availability: AvailabilitySlot[];
}

export async function updateSettings(data: SettingsData): Promise<{ error?: string }> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Not signed in" };

  const zipError = await validateZipcode(data.zipcode);
  if (zipError) return { error: zipError };

  const { error: profileError } = await supabase
    .from("profiles")
    .update({
      first_name: data.firstName,
      age: data.age,
      budget_level: data.budgetLevel,
      zipcode: data.zipcode,
    })
    .eq("user_id", user.id);
  if (profileError) return { error: profileError.message };

  const { error: prefError } = await supabase
    .from("preferences")
    .update({
      age_min: data.ageMin,
      age_max: data.ageMax,
      gender_pref: data.genderPref,
      max_distance_km: data.maxDistanceKm,
      notification_pref: data.notificationPref,
    })
    .eq("user_id", user.id);
  if (prefError) return { error: prefError.message };

  await supabase.from("availability").delete().eq("user_id", user.id);
  if (data.availability.length > 0) {
    const { error } = await supabase
      .from("availability")
      .insert(data.availability.map((s) => ({ user_id: user.id, ...s })));
    if (error) return { error: error.message };
  }

  revalidatePath("/dashboard");
  revalidatePath("/settings");
  return {};
}
