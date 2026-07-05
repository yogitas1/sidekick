import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import OnboardingWizard from "./wizard";

export default async function OnboardingPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("onboarding_complete")
    .eq("user_id", user.id)
    .maybeSingle();
  if (profile?.onboarding_complete) redirect("/dashboard");

  const [{ data: buckets }, { data: activities }] = await Promise.all([
    supabase.from("interest_buckets").select("*").order("id"),
    supabase.from("activities").select("*").order("title"),
  ]);

  return <OnboardingWizard buckets={buckets ?? []} activities={activities ?? []} />;
}
