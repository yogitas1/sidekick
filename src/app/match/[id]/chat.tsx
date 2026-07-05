"use client";

import { useEffect, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { chatWindow, type Message } from "@/lib/types";

export default function Chat({
  matchId,
  userId,
  initialMessages,
  meetupTime,
  partnerName,
  partnerIsDemo,
}: {
  matchId: string;
  userId: string;
  initialMessages: Message[];
  meetupTime: string;
  partnerName: string;
  partnerIsDemo: boolean;
}) {
  const [messages, setMessages] = useState<Message[]>(initialMessages);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);
  const window_ = chatWindow(meetupTime);

  useEffect(() => {
    const supabase = createClient();
    const channel = supabase
      .channel(`match-${matchId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "messages", filter: `match_id=eq.${matchId}` },
        (payload) => {
          const msg = payload.new as Message;
          setMessages((prev) => (prev.some((m) => m.id === msg.id) ? prev : [...prev, msg]));
        }
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [matchId]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  async function send(e: React.FormEvent) {
    e.preventDefault();
    const body = draft.trim();
    if (!body) return;
    setSending(true);
    setError(null);
    const supabase = createClient();
    const { data, error } = await supabase
      .from("messages")
      .insert({ match_id: matchId, sender_id: userId, body })
      .select()
      .single();
    if (error) {
      setError(
        error.message.includes("row-level security")
          ? "Chat is closed right now — it's open from 24h before to 2h after the meetup."
          : error.message
      );
    } else if (data) {
      setMessages((prev) => (prev.some((m) => m.id === data.id) ? prev : [...prev, data]));
      setDraft("");
    }
    setSending(false);
  }

  if (!window_.isOpen) {
    return (
      <div className="rounded-3xl border border-cream bg-white p-8 text-center shadow-sm">
        {window_.isPast ? (
          <p className="text-sm text-ink/60">💬 This chat has closed (2h after the meetup).</p>
        ) : (
          <>
            <p className="text-3xl">🔒</p>
            <p className="mt-2 font-semibold">Chat isn&apos;t open yet</p>
            <p className="mt-1 text-sm text-ink/60">
              You can message {partnerName} starting{" "}
              {window_.opensAt.toLocaleString("en-US", {
                weekday: "long",
                hour: "numeric",
                minute: "2-digit",
              })}{" "}
              — 24 hours before you meet.
            </p>
          </>
        )}
      </div>
    );
  }

  return (
    <div className="flex h-[28rem] flex-col rounded-3xl border border-cream bg-white shadow-sm">
      <div className="border-b border-ink/5 px-5 py-3 text-sm font-semibold">
        Chat with {partnerName}
        {partnerIsDemo && (
          <span className="ml-2 rounded-full bg-butter/40 px-2 py-0.5 text-[10px] font-medium text-ink/60">
            demo user — won&apos;t reply
          </span>
        )}
      </div>
      <div className="flex-1 space-y-2 overflow-y-auto p-5">
        {messages.length === 0 && (
          <p className="text-center text-sm text-ink/40">
            Say hi and figure out how you&apos;ll find each other 👋
          </p>
        )}
        {messages.map((m) => (
          <div
            key={m.id}
            className={`max-w-[75%] rounded-2xl px-4 py-2 text-sm ${
              m.sender_id === userId
                ? "ml-auto rounded-br-sm bg-tan text-white"
                : "rounded-bl-sm bg-cream"
            }`}
          >
            {m.body}
          </div>
        ))}
        <div ref={bottomRef} />
      </div>
      <form onSubmit={send} className="flex gap-2 border-t border-ink/5 p-3">
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder="Type a message…"
          className="flex-1 rounded-full border border-ink/10 px-4 py-2 text-sm outline-none focus:border-tan"
        />
        <button
          type="submit"
          disabled={sending || !draft.trim()}
          className="rounded-full bg-tan px-5 py-2 text-sm font-semibold text-white hover:bg-tan-dark disabled:opacity-50"
        >
          Send
        </button>
      </form>
      {error && <p className="px-5 pb-3 text-xs text-tan-dark">{error}</p>}
    </div>
  );
}
