import Link from "next/link";

const steps = [
  {
    emoji: "📝",
    title: "Tell us who you are",
    text: "A quick profile: your vibe, your budget, eight activities you'd genuinely do, and when you're free.",
  },
  {
    emoji: "🤝",
    title: "Get matched with a plan",
    text: "We pair you with a compatible person AND a specific activity you both want — at a time you're both free.",
  },
  {
    emoji: "☕",
    title: "Actually meet up",
    text: "Chat opens 24 hours before. Show up, have fun, and tell us how it went. No-shows strike out.",
  },
];

export default function LandingPage() {
  return (
    <main className="flex-1">
      <nav className="mx-auto flex max-w-5xl items-center justify-between px-6 py-5">
        <span className="text-xl font-bold tracking-tight text-coral">Sidekick</span>
        <div className="flex items-center gap-3">
          <Link
            href="/login"
            className="rounded-full px-4 py-2 text-sm font-medium text-ink/70 hover:text-ink"
          >
            Log in
          </Link>
          <Link
            href="/signup"
            className="rounded-full bg-coral px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-coral-dark"
          >
            Join free
          </Link>
        </div>
      </nav>

      <section className="mx-auto max-w-3xl px-6 pt-16 pb-12 text-center">
        <p className="mb-4 inline-block rounded-full bg-butter/30 px-4 py-1.5 text-sm font-medium text-ink/80">
          🌉 Now matching in San Francisco
        </p>
        <h1 className="text-5xl font-bold leading-tight tracking-tight sm:text-6xl">
          Make a friend.
          <br />
          <span className="text-coral">Make it a plan.</span>
        </h1>
        <p className="mx-auto mt-6 max-w-xl text-lg text-ink/70">
          Friend apps give you endless chats that go nowhere. Sidekick matches you with a
          compatible person <em>and</em> an activity you both actually want to do — picnic at
          Dolores Park, dim sum crawl, bouldering — scheduled when you&apos;re both free.
        </p>
        <Link
          href="/signup"
          className="mt-8 inline-block rounded-full bg-coral px-8 py-4 text-lg font-semibold text-white shadow-lg shadow-coral/25 transition hover:bg-coral-dark"
        >
          Find my first meetup →
        </Link>
      </section>

      <section className="mx-auto grid max-w-5xl gap-6 px-6 py-12 sm:grid-cols-3">
        {steps.map((s) => (
          <div key={s.title} className="rounded-3xl bg-white p-7 shadow-sm">
            <div className="text-3xl">{s.emoji}</div>
            <h3 className="mt-3 text-lg font-semibold">{s.title}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink/70">{s.text}</p>
          </div>
        ))}
      </section>

      <footer className="py-10 text-center text-sm text-ink/50">
        Sidekick — prototype. Be kind, show up. 💛
      </footer>
    </main>
  );
}
