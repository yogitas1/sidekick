"use client";

import { useState } from "react";
import { updateSettings } from "@/lib/actions";
import AvailabilityGrid from "@/components/AvailabilityGrid";
import { BUDGET_LABELS, type AvailabilitySlot, type Preferences, type Profile } from "@/lib/types";

export default function SettingsForm({
  profile,
  prefs,
  slots,
}: {
  profile: Profile;
  prefs: Preferences | null;
  slots: AvailabilitySlot[];
}) {
  const [firstName, setFirstName] = useState(profile.first_name);
  const [age, setAge] = useState(profile.age ?? 25);
  const [budget, setBudget] = useState(profile.budget_level);
  const [zipcode, setZipcode] = useState(profile.zipcode);
  const [ageMin, setAgeMin] = useState(prefs?.age_min ?? 21);
  const [ageMax, setAgeMax] = useState(prefs?.age_max ?? 45);
  const [genderPref, setGenderPref] = useState<string>(prefs?.gender_pref ?? "any");
  const [distance, setDistance] = useState(prefs?.max_distance_km ?? 15);
  const [notifPref, setNotifPref] = useState<string>(prefs?.notification_pref ?? "day_before");
  const [availability, setAvailability] = useState<AvailabilitySlot[]>(slots);
  const [status, setStatus] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setStatus(null);
    const result = await updateSettings({
      firstName: firstName.trim(),
      age,
      budgetLevel: budget,
      zipcode,
      ageMin,
      ageMax,
      genderPref,
      maxDistanceKm: distance,
      notificationPref: notifPref,
      availability,
    });
    setStatus(result.error ?? "Saved ✓");
    setSaving(false);
  }

  return (
    <form onSubmit={handleSubmit} className="mt-8 space-y-8">
      <section className="rounded-3xl border border-cream bg-white p-6 shadow-sm">
        <h2 className="font-semibold">Profile</h2>
        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          <label className="text-sm">
            <span className="text-ink/60">First name</span>
            <input
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
              className="mt-1 w-full rounded-xl border border-ink/10 px-3 py-2"
            />
          </label>
          <label className="text-sm">
            <span className="text-ink/60">Age</span>
            <input
              type="number"
              min={18}
              value={age}
              onChange={(e) => setAge(Number(e.target.value))}
              className="mt-1 w-full rounded-xl border border-ink/10 px-3 py-2"
            />
          </label>
          <label className="text-sm">
            <span className="text-ink/60">Zipcode</span>
            <input
              value={zipcode}
              maxLength={5}
              onChange={(e) => setZipcode(e.target.value.replace(/\D/g, ""))}
              className="mt-1 w-full rounded-xl border border-ink/10 px-3 py-2"
            />
          </label>
          <div className="text-sm">
            <span className="text-ink/60">Budget</span>
            <div className="mt-1 flex gap-1">
              {BUDGET_LABELS.map((label, i) => (
                <button
                  key={label}
                  type="button"
                  onClick={() => setBudget(i + 1)}
                  className={`flex-1 rounded-xl border px-2 py-2 font-medium ${
                    budget === i + 1 ? "border-tan bg-tan text-white" : "border-ink/10"
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-cream bg-white p-6 shadow-sm">
        <h2 className="font-semibold">Match preferences</h2>
        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          <label className="text-sm">
            <span className="text-ink/60">Age range</span>
            <div className="mt-1 flex items-center gap-2">
              <input
                type="number"
                min={18}
                value={ageMin}
                onChange={(e) => setAgeMin(Number(e.target.value))}
                className="w-20 rounded-xl border border-ink/10 px-3 py-2"
              />
              <span className="text-ink/40">–</span>
              <input
                type="number"
                min={18}
                value={ageMax}
                onChange={(e) => setAgeMax(Number(e.target.value))}
                className="w-20 rounded-xl border border-ink/10 px-3 py-2"
              />
            </div>
          </label>
          <label className="text-sm">
            <span className="text-ink/60">Meet</span>
            <select
              value={genderPref}
              onChange={(e) => setGenderPref(e.target.value)}
              className="mt-1 w-full rounded-xl border border-ink/10 bg-white px-3 py-2"
            >
              <option value="any">Anyone</option>
              <option value="woman">Women</option>
              <option value="man">Men</option>
              <option value="nonbinary">Non-binary folks</option>
            </select>
          </label>
          <label className="text-sm">
            <span className="text-ink/60">Max distance: {distance} km</span>
            <input
              type="range"
              min={2}
              max={50}
              value={distance}
              onChange={(e) => setDistance(Number(e.target.value))}
              className="mt-2 w-full accent-tan"
            />
          </label>
          <label className="text-sm">
            <span className="text-ink/60">Notify me</span>
            <select
              value={notifPref}
              onChange={(e) => setNotifPref(e.target.value)}
              className="mt-1 w-full rounded-xl border border-ink/10 bg-white px-3 py-2"
            >
              <option value="day_before">Day before</option>
              <option value="two_days_before">2 days before</option>
              <option value="week_before">A week ahead</option>
            </select>
          </label>
        </div>
      </section>

      <section className="rounded-3xl border border-cream bg-white p-6 shadow-sm">
        <h2 className="font-semibold">Weekly availability</h2>
        <div className="mt-4">
          <AvailabilityGrid value={availability} onChange={setAvailability} />
        </div>
      </section>

      <div className="flex items-center gap-4">
        <button
          type="submit"
          disabled={saving}
          className="rounded-full bg-tan px-8 py-3 font-semibold text-white hover:bg-tan-dark disabled:opacity-60"
        >
          {saving ? "Saving…" : "Save changes"}
        </button>
        {status && (
          <span className={`text-sm ${status === "Saved ✓" ? "text-sage" : "text-tan-dark"}`}>
            {status}
          </span>
        )}
      </div>
    </form>
  );
}
