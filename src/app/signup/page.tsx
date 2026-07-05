"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function SignupPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [needsConfirmation, setNeedsConfirmation] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { data, error } = await supabase.auth.signUp({ email, password });
    if (error) {
      setError(error.message);
      setLoading(false);
      return;
    }
    if (!data.session) {
      // Email confirmation is enabled on the project
      setNeedsConfirmation(true);
      setLoading(false);
      return;
    }
    router.push("/onboarding");
    router.refresh();
  }

  if (needsConfirmation) {
    return (
      <main className="flex flex-1 items-center justify-center px-6 py-16">
        <div className="w-full max-w-sm text-center">
          <div className="text-4xl">📬</div>
          <h1 className="mt-4 text-2xl font-bold">Check your email</h1>
          <p className="mt-2 text-ink/60">
            We sent a confirmation link to <strong>{email}</strong>. Click it, then{" "}
            <Link href="/login" className="text-tan hover:underline">
              log in
            </Link>
            .
          </p>
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
        <h1 className="mt-6 text-3xl font-bold">Create your account</h1>
        <p className="mt-1 text-ink/60">Two minutes to your first real plan.</p>

        <form onSubmit={handleSubmit} className="mt-8 space-y-4">
          <input
            type="email"
            required
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full rounded-2xl border border-ink/10 bg-white px-4 py-3 outline-none focus:border-tan"
          />
          <input
            type="password"
            required
            minLength={8}
            placeholder="Password (8+ characters)"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full rounded-2xl border border-ink/10 bg-white px-4 py-3 outline-none focus:border-tan"
          />
          {error && <p className="text-sm text-tan-dark">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-2xl bg-tan py-3 font-semibold text-white hover:bg-tan-dark disabled:opacity-60"
          >
            {loading ? "Creating…" : "Sign up"}
          </button>
        </form>

        <p className="mt-6 text-sm text-ink/60">
          Already have an account?{" "}
          <Link href="/login" className="font-medium text-tan hover:underline">
            Log in
          </Link>
        </p>
      </div>
    </main>
  );
}
