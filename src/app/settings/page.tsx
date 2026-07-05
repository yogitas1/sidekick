import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import AppHeader from "@/components/AppHeader";
import SettingsForm from "./form";
import type { AvailabilitySlot } from "@/lib/types";

export default async function SettingsPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const [{ data: profile }, { data: prefs }, { data: slots }] = await Promise.all([
    supabase.from("profiles").select("*").eq("user_id", user.id).maybeSingle(),
    supabase.from("preferences").select("*").eq("user_id", user.id).maybeSingle(),
    supabase.from("availability").select("day_of_week, time_block").eq("user_id", user.id),
  ]);

  if (!profile?.onboarding_complete) redirect("/onboarding");

  return (
    <>
      <AppHeader firstName={profile.first_name} />
      <main className="mx-auto w-full max-w-2xl flex-1 px-6 py-10">
        <h1 className="text-3xl font-bold">Settings</h1>
        <p className="mt-1 text-ink/60">
          Keep your availability fresh — it directly powers your weekly matches.
        </p>
        <SettingsForm
          profile={profile}
          prefs={prefs}
          slots={(slots ?? []) as AvailabilitySlot[]}
        />
      </main>
    </>
  );
}
