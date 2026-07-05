"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      setError(error.message);
      setLoading(false);
      return;
    }
    router.push("/dashboard");
    router.refresh();
  }

  return (
    <main className="flex flex-1 items-center justify-center px-6 py-16">
      <div className="w-full max-w-sm">
        <Link href="/" className="text-xl font-bold text-coral">
          Sidekick
        </Link>
        <h1 className="mt-6 text-3xl font-bold">Welcome back</h1>
        <p className="mt-1 text-ink/60">Log in to see your upcoming meetups.</p>

        <form onSubmit={handleSubmit} className="mt-8 space-y-4">
          <input
            type="email"
            required
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full rounded-2xl border border-ink/10 bg-white px-4 py-3 outline-none focus:border-coral"
          />
          <input
            type="password"
            required
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full rounded-2xl border border-ink/10 bg-white px-4 py-3 outline-none focus:border-coral"
          />
          {error && <p className="text-sm text-coral-dark">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-2xl bg-coral py-3 font-semibold text-white hover:bg-coral-dark disabled:opacity-60"
          >
            {loading ? "Logging in…" : "Log in"}
          </button>
        </form>

        <p className="mt-6 text-sm text-ink/60">
          New here?{" "}
          <Link href="/signup" className="font-medium text-coral hover:underline">
            Create an account
          </Link>
        </p>
      </div>
    </main>
  );
}
