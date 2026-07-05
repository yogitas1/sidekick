"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { confirmMatch, cancelMatch } from "@/lib/actions";

export default function MatchActions({
  matchId,
  showConfirm,
}: {
  matchId: string;
  showConfirm: boolean;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function act(fn: (id: string) => Promise<{ error?: string }>) {
    setBusy(true);
    setError(null);
    const result = await fn(matchId);
    if (result.error) setError(result.error);
    router.refresh();
    setBusy(false);
  }

  return (
    <div className="mt-4">
      <div className="flex gap-3">
        {showConfirm && (
          <button
            onClick={() => act(confirmMatch)}
            disabled={busy}
            className="rounded-full bg-sage px-6 py-2.5 font-semibold text-white hover:opacity-90 disabled:opacity-60"
          >
            I&apos;m in ✓
          </button>
        )}
        <button
          onClick={() => {
            if (window.confirm("Cancel this meetup? Your match will be prioritized for a rematch."))
              act(cancelMatch);
          }}
          disabled={busy}
          className="rounded-full border border-ink/15 px-6 py-2.5 font-medium text-ink/60 hover:border-ink/30 disabled:opacity-60"
        >
          Cancel
        </button>
      </div>
      {error && <p className="mt-2 text-sm text-coral-dark">{error}</p>}
    </div>
  );
}
