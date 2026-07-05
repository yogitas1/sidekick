import Link from "next/link";
import { signOut } from "@/lib/actions";

export default function AppHeader({ firstName }: { firstName?: string }) {
  return (
    <nav className="border-b border-ink/5 bg-white/70 backdrop-blur">
      <div className="mx-auto flex max-w-4xl items-center justify-between px-6 py-4">
        <Link href="/dashboard" className="text-lg font-bold tracking-tight text-tan">
          Sidekick
        </Link>
        <div className="flex items-center gap-4 text-sm">
          <Link href="/dashboard" className="font-medium text-ink/70 hover:text-ink">
            Dashboard
          </Link>
          <Link href="/settings" className="font-medium text-ink/70 hover:text-ink">
            Settings
          </Link>
          <form action={signOut}>
            <button className="rounded-full border border-ink/15 px-3 py-1.5 font-medium text-ink/70 hover:border-ink/30">
              Sign out{firstName ? ` (${firstName})` : ""}
            </button>
          </form>
        </div>
      </div>
    </nav>
  );
}
