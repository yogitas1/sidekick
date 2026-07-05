import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import AppHeader from "@/components/AppHeader";
import Chat from "./chat";
import { BUDGET_LABELS, chatWindow, type MatchPartner, type Message } from "@/lib/types";

function formatTime(iso: string) {
  return new Date(iso).toLocaleString("en-US", {
    weekday: "long",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZone: "America/Los_Angeles",
  });
}

export default async function MatchPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: match } = await supabase
    .from("matches")
    .select("*, activity:activities(*)")
    .eq("id", id)
    .maybeSingle();
  if (!match) notFound();

  const { data: partner } = await supabase
    .rpc("match_partners")
    .select("*")
    .eq("match_id", id)
    .maybeSingle<MatchPartner>();

  const { data: messages } = await supabase
    .from("messages")
    .select("*")
    .eq("match_id", id)
    .order("created_at", { ascending: true });

  const window_ = chatWindow(match.meetup_time);
  const { data: profile } = await supabase
    .from("profiles")
    .select("first_name")
    .eq("user_id", user.id)
    .single();

  return (
    <>
      <AppHeader firstName={profile?.first_name} />
      <main className="mx-auto w-full max-w-2xl flex-1 px-6 py-8">
        <Link href="/dashboard" className="text-sm text-ink/50 hover:text-ink">
          ← Back to dashboard
        </Link>

        <div className="mt-4 rounded-3xl bg-white p-6 shadow-sm">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h1 className="text-2xl font-bold">{match.activity.title}</h1>
              <p className="mt-1 text-ink/70">
                {match.activity.venue} · {BUDGET_LABELS[match.activity.cost_level - 1]}
              </p>
              <p className="mt-1 font-medium text-coral-dark">{formatTime(match.meetup_time)}</p>
            </div>
            {partner && (
              <div className="rounded-2xl bg-cream px-4 py-3 text-center">
                <p className="font-semibold">{partner.first_name}</p>
                <p className="text-xs text-ink/60">{partner.age}</p>
              </div>
            )}
          </div>
          <p className="mt-3 text-sm text-ink/60">{match.activity.description}</p>
          <p className="mt-3 text-xs text-ink/40">
            Status: <span className="font-medium">{match.status}</span>
          </p>
        </div>

        <div className="mt-6">
          {match.status !== "confirmed" && !window_.isPast ? (
            <div className="rounded-3xl bg-white p-8 text-center text-sm text-ink/60 shadow-sm">
              💬 Chat unlocks once you&apos;ve both confirmed the meetup.
            </div>
          ) : (
            <Chat
              matchId={id}
              userId={user.id}
              initialMessages={(messages ?? []) as Message[]}
              meetupTime={match.meetup_time}
              partnerName={partner?.first_name ?? "your match"}
              partnerIsDemo={partner?.is_demo ?? false}
            />
          )}
        </div>
      </main>
    </>
  );
}
