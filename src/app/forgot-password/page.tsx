"use client";

import { useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const supabase = createClient();
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/callback?next=/reset-password`,
    });

    // Surface rate-limit errors (the built-in email sender throttles hard);
    // otherwise always show success so we don't reveal which emails exist.
    if (error && /rate|too many/i.test(error.message)) {
      setError(error.message);
      setLoading(false);
      return;
    }

    setSent(true);
    setLoading(false);
  }

  if (sent) {
    return (
      <main className="flex flex-1 items-center justify-center px-6 py-16">
        <div className="w-full max-w-sm text-center">
          <div className="text-4xl">📬</div>
          <h1 className="mt-4 text-2xl font-bold">Check your email</h1>
          <p className="mt-2 text-ink/60">
            If an account exists for <strong>{email}</strong>, we&apos;ve sent a link to
            reset your password. It expires in about an hour.
          </p>
          <Link
            href="/login"
            className="mt-6 inline-block font-medium text-tan hover:underline"
          >
            Back to log in
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main className="flex flex-1 items-center justify-center px-6 py-16">
      <div className="w-full max-w-sm">
        <Link href="/" className="text-xl font-bold text-tan">
          Sidekick
        </Link>
        <h1 className="mt-6 text-3xl font-bold">Reset your password</h1>
        <p className="mt-1 text-ink/60">
          Enter your email and we&apos;ll send you a reset link.
        </p>

        <form onSubmit={handleSubmit} className="mt-8 space-y-4">
          <input
            type="email"
            required
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full rounded-2xl border border-ink/10 bg-white px-4 py-3 outline-none focus:border-tan"
          />
          {error && <p className="text-sm text-tan-dark">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-2xl bg-tan py-3 font-semibold text-white hover:bg-tan-dark disabled:opacity-60"
          >
            {loading ? "Sending…" : "Send reset link"}
          </button>
        </form>

        <p className="mt-6 text-sm text-ink/60">
          Remembered it?{" "}
          <Link href="/login" className="font-medium text-tan hover:underline">
            Log in
          </Link>
        </p>
      </div>
    </main>
  );
}
