"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { findMatch } from "@/lib/actions";

export default function FindMatchButton() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function handleClick() {
    setLoading(true);
    setMessage(null);
    const result = await findMatch();
    if (result.error) {
      setMessage(result.error);
      setLoading(false);
      return;
    }
    router.refresh();
    setLoading(false);
  }

  return (
    <div className="text-center">
      <button
        onClick={handleClick}
        disabled={loading}
        className="rounded-full bg-tan px-8 py-4 text-lg font-semibold text-white shadow-lg shadow-tan/25 transition hover:bg-tan-dark disabled:opacity-60"
      >
        {loading ? "Matching…" : "✨ Find my match"}
      </button>
      {message && <p className="mt-3 text-sm text-ink/60">{message}</p>}
      <p className="mt-3 text-xs text-ink/40">
        Matching also runs automatically every Monday morning.
      </p>
    </div>
  );
}
