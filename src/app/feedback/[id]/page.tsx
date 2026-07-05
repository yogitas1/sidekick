import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import AppHeader from "@/components/AppHeader";
import FeedbackForm from "./form";
import type { MatchPartner } from "@/lib/types";

export default async function FeedbackPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: match } = await supabase
    .from("matches")
    .select("*, activity:activities(title)")
    .eq("id", id)
    .maybeSingle();
  if (!match) notFound();

  const { data: existing } = await supabase
    .from("feedback")
    .select("id")
    .eq("match_id", id)
    .eq("rater_id", user.id)
    .maybeSingle();
  if (existing) redirect("/dashboard");

  const { data: partner } = await supabase
    .rpc("match_partners")
    .select("*")
    .eq("match_id", id)
    .maybeSingle<MatchPartner>();

  const { data: profile } = await supabase
    .from("profiles")
    .select("first_name")
    .eq("user_id", user.id)
    .single();

  return (
    <>
      <AppHeader firstName={profile?.first_name} />
      <main className="mx-auto w-full max-w-lg flex-1 px-6 py-10">
        <h1 className="text-3xl font-bold">How did it go?</h1>
        <p className="mt-1 text-ink/60">
          {match.activity.title} with {partner?.first_name ?? "your match"}. Your answers help us
          make better matches — and keep everyone accountable.
        </p>
        <FeedbackForm matchId={id} partnerName={partner?.first_name ?? "your match"} />
      </main>
    </>
  );
}
