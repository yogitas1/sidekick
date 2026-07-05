"use client";

import { useMemo, useState } from "react";
import { saveOnboarding } from "@/lib/actions";
import AvailabilityGrid from "@/components/AvailabilityGrid";
import {
  BUDGET_LABELS,
  type Activity,
  type AvailabilitySlot,
  type InterestBucket,
} from "@/lib/types";

const REQUIRED_PICKS = 8;

const QUIZ = [
  {
    q: "After a long week, you recharge by…",
    a: { label: "Being around people", letter: "E" },
    b: { label: "Quiet time solo", letter: "I" },
  },
  {
    q: "When trying something new, you…",
    a: { label: "Jump in and figure it out", letter: "S" },
    b: { label: "Imagine the possibilities first", letter: "N" },
  },
  {
    q: "Friends would say you lead with…",
    a: { label: "Head — logic and candor", letter: "T" },
    b: { label: "Heart — empathy and warmth", letter: "F" },
  },
  {
    q: "Your ideal Saturday is…",
    a: { label: "Planned by 9am", letter: "J" },
    b: { label: "Whatever unfolds", letter: "P" },
  },
] as const;

const STEP_TITLES = [
  "About you",
  "Budget & vibe",
  "Pick your 8",
  "Who you'd like to meet",
  "Where & when",
];

export default function OnboardingWizard({
  buckets,
  activities,
}: {
  buckets: InterestBucket[];
  activities: Activity[];
}) {
  const [step, setStep] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // Step 1
  const [firstName, setFirstName] = useState("");
  const [age, setAge] = useState<number | "">("");
  const [gender, setGender] = useState("");
  // Step 2
  const [budget, setBudget] = useState(2);
  const [quiz, setQuiz] = useState<(0 | 1 | null)[]>([null, null, null, null]);
  // Step 3
  const [picked, setPicked] = useState<string[]>([]);
  const [bucketFilter, setBucketFilter] = useState<number | null>(null);
  // Step 4
  const [ageMin, setAgeMin] = useState(21);
  const [ageMax, setAgeMax] = useState(45);
  const [genderPref, setGenderPref] = useState("any");
  const [distance, setDistance] = useState(15);
  const [notifPref, setNotifPref] = useState("day_before");
  // Step 5
  const [zipcode, setZipcode] = useState("");
  const [availability, setAvailability] = useState<AvailabilitySlot[]>([]);

  const personalityType = useMemo(() => {
    if (quiz.some((x) => x === null)) return null;
    return quiz.map((pick, i) => (pick === 0 ? QUIZ[i].a.letter : QUIZ[i].b.letter)).join("");
  }, [quiz]);

  const visibleActivities = useMemo(
    () =>
      bucketFilter === null
        ? activities
        : activities.filter((a) => a.bucket_id === bucketFilter),
    [activities, bucketFilter]
  );

  const bucketOf = (id: number) => buckets.find((b) => b.id === id);

  function togglePick(id: string) {
    setPicked((p) =>
      p.includes(id) ? p.filter((x) => x !== id) : p.length < REQUIRED_PICKS ? [...p, id] : p
    );
  }

  const stepValid = [
    firstName.trim().length > 0 && age !== "" && Number(age) >= 18 && gender !== "",
    true, // budget always set, quiz optional
    picked.length === REQUIRED_PICKS,
    ageMin >= 18 && ageMax >= ageMin,
    /^\d{5}$/.test(zipcode) && availability.length > 0,
  ][step];

  async function finish() {
    setSaving(true);
    setError(null);
    const result = await saveOnboarding({
      firstName: firstName.trim(),
      age: Number(age),
      gender,
      budgetLevel: budget,
      personalityType,
      activityIds: picked,
      ageMin,
      ageMax,
      genderPref,
      maxDistanceKm: distance,
      notificationPref: notifPref,
      zipcode,
      availability,
    });
    // saveOnboarding redirects on success; only errors return
    if (result?.error) {
      setError(result.error);
      setSaving(false);
    }
  }

  return (
    <main className="mx-auto w-full max-w-2xl flex-1 px-6 py-10">
      {/* Progress */}
      <div className="mb-8">
        <div className="flex justify-between text-xs font-medium text-ink/50">
          <span>
            Step {step + 1} of {STEP_TITLES.length}
          </span>
          <span>{STEP_TITLES[step]}</span>
        </div>
        <div className="mt-2 h-2 rounded-full bg-ink/10">
          <div
            className="h-2 rounded-full bg-tan transition-all"
            style={{ width: `${((step + 1) / STEP_TITLES.length) * 100}%` }}
          />
        </div>
      </div>

      {step === 0 && (
        <section className="space-y-5">
          <h1 className="text-3xl font-bold">Nice to meet you 👋</h1>
          <p className="text-ink/60">
            Only your first name, age, and gender are shared with matches.
          </p>
          <input
            placeholder="First name"
            value={firstName}
            onChange={(e) => setFirstName(e.target.value)}
            className="w-full rounded-2xl border border-ink/10 bg-white px-4 py-3 outline-none focus:border-tan"
          />
          <input
            type="number"
            placeholder="Age"
            min={18}
            max={120}
            value={age}
            onChange={(e) => setAge(e.target.value === "" ? "" : Number(e.target.value))}
            className="w-full rounded-2xl border border-ink/10 bg-white px-4 py-3 outline-none focus:border-tan"
          />
          <div className="flex flex-wrap gap-2">
            {[
              ["woman", "Woman"],
              ["man", "Man"],
              ["nonbinary", "Non-binary"],
              ["other", "Other"],
            ].map(([value, label]) => (
              <button
                key={value}
                type="button"
                onClick={() => setGender(value)}
                className={`rounded-full border px-5 py-2.5 text-sm font-medium transition ${
                  gender === value
                    ? "border-tan bg-tan text-white"
                    : "border-ink/15 bg-white hover:border-tan/50"
                }`}
              >
                {label}
              </button>
            ))}
          </div>
        </section>
      )}

      {step === 1 && (
        <section className="space-y-8">
          <div>
            <h1 className="text-3xl font-bold">What&apos;s your meetup budget?</h1>
            <p className="mt-1 text-ink/60">We&apos;ll only suggest plans that fit both of you.</p>
            <div className="mt-4 flex gap-2">
              {BUDGET_LABELS.map((label, i) => (
                <button
                  key={label}
                  type="button"
                  onClick={() => setBudget(i + 1)}
                  className={`flex-1 rounded-2xl border px-4 py-4 text-lg font-semibold transition ${
                    budget === i + 1
                      ? "border-tan bg-tan text-white"
                      : "border-ink/15 bg-white hover:border-tan/50"
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>

          <div>
            <h2 className="text-xl font-bold">
              Quick vibe check <span className="text-sm font-normal text-ink/50">(optional)</span>
            </h2>
            <p className="mt-1 text-sm text-ink/60">
              Four either/ors — helps us pair compatible energy.
            </p>
            <div className="mt-4 space-y-4">
              {QUIZ.map((item, i) => (
                <div key={item.q} className="rounded-2xl border border-cream bg-white p-4 shadow-sm">
                  <p className="text-sm font-medium">{item.q}</p>
                  <div className="mt-2 flex gap-2">
                    {[item.a, item.b].map((opt, j) => (
                      <button
                        key={opt.label}
                        type="button"
                        onClick={() =>
                          setQuiz((q) => {
                            const next = [...q];
                            next[i] = next[i] === j ? null : (j as 0 | 1);
                            return next;
                          })
                        }
                        className={`flex-1 rounded-xl border px-3 py-2 text-sm transition ${
                          quiz[i] === j
                            ? "border-tan bg-tan/10 font-medium text-tan-dark"
                            : "border-ink/10 hover:border-tan/40"
                        }`}
                      >
                        {opt.label}
                      </button>
                    ))}
                  </div>
                </div>
              ))}
            </div>
            {personalityType && (
              <p className="mt-3 text-sm text-ink/60">
                Your vibe: <strong className="text-tan">{personalityType}</strong>
              </p>
            )}
          </div>
        </section>
      )}

      {step === 2 && (
        <section>
          <h1 className="text-3xl font-bold">Pick {REQUIRED_PICKS} things you&apos;d actually do</h1>
          <p className="mt-1 text-ink/60">
            From food crawls to skydiving — your picks power the matching.{" "}
            <strong className={picked.length === REQUIRED_PICKS ? "text-sage" : "text-tan"}>
              {picked.length}/{REQUIRED_PICKS} picked
            </strong>
          </p>

          <div className="mt-4 flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => setBucketFilter(null)}
              className={`rounded-full px-3 py-1.5 text-xs font-medium ${
                bucketFilter === null ? "bg-ink text-white" : "bg-white text-ink/70"
              }`}
            >
              All
            </button>
            {buckets.map((b) => (
              <button
                key={b.id}
                type="button"
                onClick={() => setBucketFilter(bucketFilter === b.id ? null : b.id)}
                className={`rounded-full px-3 py-1.5 text-xs font-medium ${
                  bucketFilter === b.id ? "bg-ink text-white" : "bg-white text-ink/70"
                }`}
              >
                {b.emoji} {b.name}
              </button>
            ))}
          </div>

          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            {visibleActivities.map((a) => {
              const isPicked = picked.includes(a.id);
              const bucket = bucketOf(a.bucket_id);
              return (
                <button
                  key={a.id}
                  type="button"
                  onClick={() => togglePick(a.id)}
                  className={`rounded-2xl border p-4 text-left transition ${
                    isPicked
                      ? "border-tan bg-tan/5 shadow-sm"
                      : "border-ink/10 bg-white hover:border-tan/40"
                  }`}
                >
                  <div className="flex items-start justify-between gap-2">
                    <span className="font-semibold">{a.title}</span>
                    <span className="text-lg">{isPicked ? "✅" : bucket?.emoji}</span>
                  </div>
                  <p className="mt-1 line-clamp-2 text-xs text-ink/60">{a.description}</p>
                  <p className="mt-2 text-xs font-medium text-ink/50">
                    {a.venue} · {BUDGET_LABELS[a.cost_level - 1]}
                    {a.is_scheduled_event && " · 📅 scheduled event"}
                  </p>
                </button>
              );
            })}
          </div>
        </section>
      )}

      {step === 3 && (
        <section className="space-y-6">
          <h1 className="text-3xl font-bold">Who would you like to meet?</h1>
          <div>
            <label className="text-sm font-medium text-ink/70">
              Age range: {ageMin}–{ageMax}
            </label>
            <div className="mt-2 flex items-center gap-3">
              <input
                type="number"
                min={18}
                max={99}
                value={ageMin}
                onChange={(e) => setAgeMin(Number(e.target.value))}
                className="w-24 rounded-xl border border-ink/10 bg-white px-3 py-2"
              />
              <span className="text-ink/40">to</span>
              <input
                type="number"
                min={18}
                max={99}
                value={ageMax}
                onChange={(e) => setAgeMax(Number(e.target.value))}
                className="w-24 rounded-xl border border-ink/10 bg-white px-3 py-2"
              />
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-ink/70">Gender</label>
            <div className="mt-2 flex flex-wrap gap-2">
              {[
                ["any", "Anyone"],
                ["woman", "Women"],
                ["man", "Men"],
                ["nonbinary", "Non-binary folks"],
              ].map(([value, label]) => (
                <button
                  key={value}
                  type="button"
                  onClick={() => setGenderPref(value)}
                  className={`rounded-full border px-4 py-2 text-sm font-medium transition ${
                    genderPref === value
                      ? "border-tan bg-tan text-white"
                      : "border-ink/15 bg-white hover:border-tan/50"
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-ink/70">
              Max distance: {distance} km
            </label>
            <input
              type="range"
              min={2}
              max={50}
              value={distance}
              onChange={(e) => setDistance(Number(e.target.value))}
              className="mt-2 w-full accent-tan"
            />
          </div>
          <div>
            <label className="text-sm font-medium text-ink/70">
              When should we tell you about a match?
            </label>
            <div className="mt-2 flex flex-wrap gap-2">
              {[
                ["day_before", "Day before"],
                ["two_days_before", "2 days before"],
                ["week_before", "A week ahead"],
              ].map(([value, label]) => (
                <button
                  key={value}
                  type="button"
                  onClick={() => setNotifPref(value)}
                  className={`rounded-full border px-4 py-2 text-sm font-medium transition ${
                    notifPref === value
                      ? "border-tan bg-tan text-white"
                      : "border-ink/15 bg-white hover:border-tan/50"
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
        </section>
      )}

      {step === 4 && (
        <section className="space-y-6">
          <h1 className="text-3xl font-bold">Where &amp; when are you free?</h1>
          <div>
            <label className="text-sm font-medium text-ink/70">Your zipcode</label>
            <input
              placeholder="e.g. 94110"
              value={zipcode}
              maxLength={5}
              onChange={(e) => setZipcode(e.target.value.replace(/\D/g, ""))}
              className="mt-2 w-40 rounded-2xl border border-ink/10 bg-white px-4 py-3 outline-none focus:border-tan"
            />
          </div>
          <div>
            <label className="text-sm font-medium text-ink/70">
              Weekly availability — tap every block that usually works
            </label>
            <div className="mt-3">
              <AvailabilityGrid value={availability} onChange={setAvailability} />
            </div>
          </div>
        </section>
      )}

      {error && <p className="mt-4 text-sm text-tan-dark">{error}</p>}

      <div className="mt-10 flex items-center justify-between">
        <button
          type="button"
          onClick={() => setStep((s) => Math.max(0, s - 1))}
          className={`rounded-full px-5 py-2.5 text-sm font-medium text-ink/60 hover:text-ink ${
            step === 0 ? "invisible" : ""
          }`}
        >
          ← Back
        </button>
        {step < STEP_TITLES.length - 1 ? (
          <button
            type="button"
            disabled={!stepValid}
            onClick={() => setStep((s) => s + 1)}
            className="rounded-full bg-tan px-7 py-3 font-semibold text-white hover:bg-tan-dark disabled:opacity-40"
          >
            Continue →
          </button>
        ) : (
          <button
            type="button"
            disabled={!stepValid || saving}
            onClick={finish}
            className="rounded-full bg-tan px-7 py-3 font-semibold text-white hover:bg-tan-dark disabled:opacity-40"
          >
            {saving ? "Saving…" : "Finish & find friends 🎉"}
          </button>
        )}
      </div>
    </main>
  );
}
