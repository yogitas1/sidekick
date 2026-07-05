"use client";

import { useState } from "react";
import { submitFeedback } from "@/lib/actions";

export default function FeedbackForm({
  matchId,
  partnerName,
}: {
  matchId: string;
  partnerName: string;
}) {
  const [showedUp, setShowedUp] = useState<boolean | null>(null);
  const [rating, setRating] = useState<number | null>(null);
  const [wouldMeetAgain, setWouldMeetAgain] = useState<boolean | null>(null);
  const [comments, setComments] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (showedUp === null) return;
    setSaving(true);
    setError(null);
    const result = await submitFeedback({
      matchId,
      showedUp,
      rating: showedUp ? rating : null,
      wouldMeetAgain: showedUp ? wouldMeetAgain : null,
      comments,
    });
    if (result?.error) {
      setError(result.error);
      setSaving(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="mt-8 space-y-7">
      <div>
        <p className="font-semibold">Did {partnerName} show up?</p>
        <div className="mt-2 flex gap-2">
          {[
            [true, "Yes ✅"],
            [false, "No-show 🚫"],
          ].map(([value, label]) => (
            <button
              key={String(value)}
              type="button"
              onClick={() => setShowedUp(value as boolean)}
              className={`rounded-full border px-5 py-2.5 text-sm font-medium transition ${
                showedUp === value
                  ? "border-coral bg-coral text-white"
                  : "border-ink/15 bg-white hover:border-coral/50"
              }`}
            >
              {label as string}
            </button>
          ))}
        </div>
        {showedUp === false && (
          <p className="mt-2 text-xs text-ink/50">
            No-shows get a strike. Three strikes pauses an account.
          </p>
        )}
      </div>

      {showedUp && (
        <>
          <div>
            <p className="font-semibold">How was the meetup?</p>
            <div className="mt-2 flex gap-1 text-3xl">
              {[1, 2, 3, 4, 5].map((n) => (
                <button
                  key={n}
                  type="button"
                  onClick={() => setRating(n)}
                  className={rating !== null && n <= rating ? "" : "opacity-25"}
                >
                  ⭐
                </button>
              ))}
            </div>
          </div>

          <div>
            <p className="font-semibold">Would you hang out with {partnerName} again?</p>
            <div className="mt-2 flex gap-2">
              {[
                [true, "Definitely"],
                [false, "Probably not"],
              ].map(([value, label]) => (
                <button
                  key={String(value)}
                  type="button"
                  onClick={() => setWouldMeetAgain(value as boolean)}
                  className={`rounded-full border px-5 py-2.5 text-sm font-medium transition ${
                    wouldMeetAgain === value
                      ? "border-coral bg-coral text-white"
                      : "border-ink/15 bg-white hover:border-coral/50"
                  }`}
                >
                  {label as string}
                </button>
              ))}
            </div>
          </div>
        </>
      )}

      <div>
        <p className="font-semibold">
          Anything else? <span className="text-sm font-normal text-ink/50">(optional)</span>
        </p>
        <textarea
          value={comments}
          onChange={(e) => setComments(e.target.value)}
          rows={3}
          placeholder="What worked, what didn't…"
          className="mt-2 w-full rounded-2xl border border-ink/10 bg-white px-4 py-3 text-sm outline-none focus:border-coral"
        />
      </div>

      {error && <p className="text-sm text-coral-dark">{error}</p>}

      <button
        type="submit"
        disabled={showedUp === null || saving}
        className="w-full rounded-2xl bg-coral py-3 font-semibold text-white hover:bg-coral-dark disabled:opacity-40"
      >
        {saving ? "Submitting…" : "Submit feedback"}
      </button>
    </form>
  );
}
