import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import AppHeader from "@/components/AppHeader";
import FindMatchButton from "./find-match-button";
import MatchActions from "./match-actions";
import { BUDGET_LABELS, chatWindow, type Activity, type Match, type MatchPartner } from "@/lib/types";

const GENDER_LABEL: Record<string, string> = {
  woman: "Woman",
  man: "Man",
  nonbinary: "Non-binary",
  other: "Other",
};

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

export default async function DashboardPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("*")
    .eq("user_id", user.id)
    .maybeSingle();
  if (!profile?.onboarding_complete) redirect("/onboarding");

  const { data: matches } = await supabase
    .from("matches")
    .select("*, activity:activities(*)")
    .or(`user_a.eq.${user.id},user_b.eq.${user.id}`)
    .order("meetup_time", { ascending: false });

  const all = (matches ?? []) as (Match & { activity: Activity })[];
  // Dynamic server component: rendered per-request, so reading the clock is safe.
  // eslint-disable-next-line react-hooks/purity
  const now = Date.now();
  const active = all.find(
    (m) =>
      (m.status === "proposed" || m.status === "confirmed") &&
      new Date(m.meetup_time).getTime() > now
  );
  const past = all.filter((m) => m !== active);

  const { data: partners } = await supabase.rpc("match_partners");
  const partnerOf = (matchId: string) =>
    (partners ?? []).find((p: MatchPartner) => p.match_id === matchId);

  const { data: myFeedback } = await supabase.from("feedback").select("match_id");
  const reviewed = new Set((myFeedback ?? []).map((f) => f.match_id));
  const needsFeedback = all.filter(
    (m) =>
      ["confirmed", "completed", "no_show"].includes(m.status) &&
      new Date(m.meetup_time).getTime() < now &&
      !reviewed.has(m.id)
  );

  const iConfirmed = active
    ? active.user_a === user.id
      ? active.a_confirmed
      : active.b_confirmed
    : false;
  const activePartner = active ? partnerOf(active.id) : undefined;
  const window_ = active ? chatWindow(active.meetup_time) : null;

  return (
    <>
      <AppHeader firstName={profile.first_name} />
      <main className="mx-auto w-full max-w-4xl flex-1 px-6 py-10">
        <h1 className="text-3xl font-bold">Hey {profile.first_name} 👋</h1>

        {profile.is_suspended && (
          <div className="mt-4 rounded-2xl border border-coral/30 bg-coral/10 p-4 text-sm text-coral-dark">
            Your account is paused after 3 no-show reports. Reach out to support to appeal.
          </div>
        )}

        {profile.needs_rematch && !active && (
          <div className="mt-4 rounded-2xl border border-butter bg-butter/20 p-4 text-sm text-ink/80">
            Someone cancelled on you — sorry about that. You&apos;re at the front of the line:
            hit <strong>Find my match</strong> for a priority rematch.
          </div>
        )}

        {needsFeedback.length > 0 && (
          <div className="mt-6 space-y-3">
            {needsFeedback.map((m) => (
              <div
                key={m.id}
                className="flex items-center justify-between rounded-2xl bg-white p-4 shadow-sm"
              >
                <div>
                  <p className="font-semibold">How was {m.activity.title}?</p>
                  <p className="text-sm text-ink/60">
                    with {partnerOf(m.id)?.first_name ?? "your match"} · {formatTime(m.meetup_time)}
                  </p>
                </div>
                <Link
                  href={`/feedback/${m.id}`}
                  className="rounded-full bg-coral px-5 py-2 text-sm font-semibold text-white hover:bg-coral-dark"
                >
                  Leave feedback
                </Link>
              </div>
            ))}
          </div>
        )}

        <section className="mt-8">
          <h2 className="text-sm font-semibold tracking-wide text-ink/50 uppercase">
            Upcoming meetup
          </h2>
          {active && activePartner ? (
            <div className="mt-3 overflow-hidden rounded-3xl bg-white shadow-sm">
              <div className="bg-coral/90 px-6 py-3 text-sm font-medium text-white">
                {active.status === "proposed"
                  ? iConfirmed
                    ? "Waiting for your match to confirm…"
                    : "🎉 You have a match! Confirm to lock it in."
                  : "✅ Confirmed — it's a plan!"}
              </div>
              <div className="p-6">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <h3 className="text-2xl font-bold">{active.activity.title}</h3>
                    <p className="mt-1 text-ink/70">
                      {active.activity.venue} ·{" "}
                      {BUDGET_LABELS[active.activity.cost_level - 1]}
                    </p>
                    <p className="mt-1 font-medium text-coral-dark">
                      {formatTime(active.meetup_time)}
                    </p>
                    <p className="mt-3 max-w-md text-sm text-ink/60">
                      {active.activity.description}
                    </p>
                  </div>
                  <div className="rounded-2xl bg-cream px-5 py-4 text-center">
                    <div className="text-3xl">🙂</div>
                    <p className="mt-1 font-semibold">{activePartner.first_name}</p>
                    <p className="text-xs text-ink/60">
                      {activePartner.age} · {GENDER_LABEL[activePartner.gender] ?? activePartner.gender}
                    </p>
                    {activePartner.is_demo && (
                      <p className="mt-1 rounded-full bg-butter/40 px-2 py-0.5 text-[10px] font-medium">
                        demo user
                      </p>
                    )}
                  </div>
                </div>

                {active.status === "confirmed" && window_ && (
                  <div className="mt-5">
                    {window_.isOpen ? (
                      <Link
                        href={`/match/${active.id}`}
                        className="inline-block rounded-full bg-sage px-6 py-2.5 font-semibold text-white hover:opacity-90"
                      >
                        💬 Chat is open — say hi!
                      </Link>
                    ) : (
                      <p className="text-sm text-ink/50">
                        🔒 Chat opens {formatTime(window_.opensAt.toISOString())} (24h before
                        you meet).{" "}
                        <Link href={`/match/${active.id}`} className="text-coral hover:underline">
                          View details
                        </Link>
                      </p>
                    )}
                  </div>
                )}

                <MatchActions
                  matchId={active.id}
                  showConfirm={active.status === "proposed" && !iConfirmed}
                />
              </div>
            </div>
          ) : (
            <div className="mt-3 rounded-3xl bg-white p-10 text-center shadow-sm">
              <p className="text-lg font-medium">No meetup on the calendar yet.</p>
              <p className="mx-auto mt-1 max-w-sm text-sm text-ink/60">
                We&apos;ll pair you with someone compatible and a plan you&apos;ll both love.
              </p>
              <div className="mt-6">
                {!profile.is_suspended && <FindMatchButton />}
              </div>
            </div>
          )}
        </section>

        {past.length > 0 && (
          <section className="mt-10">
            <h2 className="text-sm font-semibold tracking-wide text-ink/50 uppercase">
              Past &amp; previous
            </h2>
            <div className="mt-3 space-y-2">
              {past.map((m) => (
                <div
                  key={m.id}
                  className="flex items-center justify-between rounded-2xl bg-white px-5 py-3 text-sm shadow-sm"
                >
                  <div>
                    <span className="font-semibold">{m.activity.title}</span>
                    <span className="text-ink/50">
                      {" "}
                      · with {partnerOf(m.id)?.first_name ?? "—"} · {formatTime(m.meetup_time)}
                    </span>
                  </div>
                  <span
                    className={`rounded-full px-3 py-1 text-xs font-medium ${
                      m.status === "completed"
                        ? "bg-sage/15 text-sage"
                        : m.status === "cancelled"
                          ? "bg-ink/5 text-ink/50"
                          : m.status === "no_show"
                            ? "bg-coral/10 text-coral-dark"
                            : "bg-butter/30 text-ink/70"
                    }`}
                  >
                    {m.status.replace("_", "-")}
                  </span>
                </div>
              ))}
            </div>
          </section>
        )}
      </main>
    </>
  );
}
