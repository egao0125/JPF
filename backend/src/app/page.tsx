"use client";

import { useEffect, useRef, useState } from "react";

// System Japanese serif/mono stacks — no webfont download, and Hiragino
// Mincho (on every Apple device) carries the literary tone.
const MINCHO = '"Hiragino Mincho ProN", "Yu Mincho", "Noto Serif JP", "Shippori Mincho", serif';
const MONO = 'Menlo, "Courier New", "Hiragino Mincho ProN", "Hiragino Sans", monospace';

// Overheard fragments — the aliases are the app's real anonymous handles.
const WHISPERS = [
  "単位不足のタヌキが、恋の話をしていた。",
  "ねむいペンギンは、ぜんぶ知っている。",
  "3限のあと、図書館の4階で。",
  "陽キャのイルカが、深夜2時に何かを残した。",
  "学食のカレーの件、まだ誰も許していない。",
  "崖っぷちのオオカミが、就活の本音を吐いた。",
];

const INK = "#0a0a0c";
const PAPER = "#ece9e2";
const DIM = "#8d8a82";
const FAINT = "#55534e";
const AMBER = "#c9a96a";
const LINE = "#2a2a2e";

export default function Home() {
  const [whisperIndex, setWhisperIndex] = useState(0);
  const [whisperShown, setWhisperShown] = useState(true);
  const [email, setEmail] = useState("");
  const [phase, setPhase] = useState<"idle" | "busy" | "done">("idle");
  const [count, setCount] = useState<number | null>(null);
  const [alreadyJoined, setAlreadyJoined] = useState(false);
  const [error, setError] = useState("");
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    timer.current = setInterval(() => {
      setWhisperShown(false);
      setTimeout(() => {
        setWhisperIndex((i) => (i + 1) % WHISPERS.length);
        setWhisperShown(true);
      }, 600);
    }, 4600);
    return () => {
      if (timer.current) clearInterval(timer.current);
    };
  }, []);

  const join = async () => {
    if (phase === "busy") return;
    setError("");
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      setError("メールアドレスの形が、少し違うようだ。");
      return;
    }
    setPhase("busy");
    try {
      const res = await fetch("/api/v1/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email.trim() }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.error ?? "何かがうまくいかなかった。");
      setCount(json.count);
      setAlreadyJoined(json.alreadyJoined);
      setPhase("done");
    } catch (e) {
      setError((e as Error).message);
      setPhase("idle");
    }
  };

  return (
    <main
      style={{
        fontFamily: MINCHO,
        position: "relative",
        minHeight: "100dvh",
        background: INK,
        color: PAPER,
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "96px 24px",
      }}
    >
      <style>{`
        @keyframes fadeUp {
          from { opacity: 0; transform: translateY(14px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes breathe {
          0%, 100% { opacity: 0.55; transform: translate(-50%, -50%) scale(1); }
          50% { opacity: 1; transform: translate(-50%, -50%) scale(1.12); }
        }
        @keyframes blink {
          0%, 55% { opacity: 1; }
          56%, 100% { opacity: 0; }
        }
        .reveal { opacity: 0; animation: fadeUp 1.1s cubic-bezier(0.22, 1, 0.36, 1) forwards; }
        .whisper { transition: opacity 0.6s ease; }
        .ghost-input::placeholder { color: ${FAINT}; }
        .ghost-input:focus { border-bottom-color: ${AMBER} !important; }
        .join-btn:hover { background: ${AMBER}; color: ${INK}; }
        a.quiet { color: ${FAINT}; text-decoration: none; }
        a.quiet:hover { color: ${DIM}; }
      `}</style>

      {/* candlelight */}
      <div
        aria-hidden
        style={{
          position: "absolute",
          left: "50%",
          top: "42%",
          width: 720,
          height: 720,
          transform: "translate(-50%, -50%)",
          background: `radial-gradient(circle, rgba(201,169,106,0.13) 0%, rgba(201,169,106,0.04) 38%, transparent 65%)`,
          filter: "blur(2px)",
          animation: "breathe 7s ease-in-out infinite",
          pointerEvents: "none",
        }}
      />
      {/* vignette */}
      <div
        aria-hidden
        style={{
          position: "absolute",
          inset: 0,
          background: "radial-gradient(ellipse at center, transparent 45%, rgba(0,0,0,0.55) 100%)",
          pointerEvents: "none",
        }}
      />
      {/* grain */}
      <div
        aria-hidden
        style={{
          position: "absolute",
          inset: 0,
          opacity: 0.05,
          pointerEvents: "none",
          backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/%3E%3C/filter%3E%3Crect width='160' height='160' filter='url(%23n)' opacity='0.6'/%3E%3C/svg%3E")`,
        }}
      />

      {/* corner marks */}
      <div
        className="reveal"
        style={{
          position: "absolute",
          top: 28,
          left: 32,
          fontFamily: MONO,
          fontSize: 11,
          letterSpacing: "0.35em",
          color: FAINT,
          animationDelay: "1.6s",
        }}
      >
        JPF
      </div>
      <div
        className="reveal"
        style={{
          position: "absolute",
          top: 28,
          right: 32,
          fontFamily: MONO,
          fontSize: 11,
          letterSpacing: "0.35em",
          color: FAINT,
          animationDelay: "1.6s",
        }}
      >
        匿名
      </div>

      <div style={{ position: "relative", maxWidth: 620, width: "100%", textAlign: "center" }}>
        {/* whisper */}
        <p
          className="reveal whisper"
          style={{
            fontFamily: MONO,
            minHeight: 24,
            fontSize: 13,
            letterSpacing: "0.12em",
            color: AMBER,
            opacity: whisperShown ? undefined : 0,
            animationDelay: "1.2s",
            marginBottom: 40,
          }}
        >
          <span className="whisper" style={{ opacity: whisperShown ? 0.85 : 0 }}>
            「{WHISPERS[whisperIndex]}」
          </span>
          <span style={{ animation: "blink 1.2s step-end infinite", marginLeft: 6, color: FAINT }}>
            ▍
          </span>
        </p>

        <h1
          className="reveal"
          style={{
            margin: 0,
            fontWeight: 500,
            fontSize: "clamp(2.4rem, 7vw, 4rem)",
            lineHeight: 1.4,
            letterSpacing: "0.08em",
            animationDelay: "0.15s",
          }}
        >
          その話は、
          <br />
          <span style={{ color: AMBER }}>ここだけ</span>の話。
        </h1>

        <p
          className="reveal"
          style={{
            margin: "36px auto 0",
            maxWidth: 420,
            fontSize: 15,
            lineHeight: 2.2,
            letterSpacing: "0.1em",
            color: DIM,
            animationDelay: "0.55s",
          }}
        >
          大学メールだけで入れる、完全匿名の学内コミュニティ。
          <br />
          名前はいらない。声だけでいい。
        </p>

        <div
          className="reveal"
          aria-hidden
          style={{
            width: 1,
            height: 44,
            margin: "44px auto",
            background: `linear-gradient(${FAINT}, transparent)`,
            animationDelay: "0.85s",
          }}
        />

        {/* waitlist */}
        <div className="reveal" style={{ animationDelay: "1.0s" }}>
          {phase !== "done" ? (
            <>
              <p
                className=""
                style={{ fontFamily: MONO, fontSize: 11, letterSpacing: "0.3em", color: FAINT, marginBottom: 18 }}
              >
                — 招待を待つ —
              </p>
              <div
                style={{
                  display: "flex",
                  gap: 14,
                  maxWidth: 440,
                  margin: "0 auto",
                  alignItems: "flex-end",
                }}
              >
                <input
                  className="ghost-input"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") void join();
                  }}
                  placeholder="you@u-tokyo.ac.jp"
                  style={{
                    flex: 1,
                    fontFamily: MONO,
                    background: "transparent",
                    border: "none",
                    borderBottom: `1px solid ${LINE}`,
                    outline: "none",
                    color: PAPER,
                    fontSize: 14,
                    letterSpacing: "0.06em",
                    padding: "10px 2px",
                    transition: "border-color 0.3s ease",
                  }}
                />
                <button
                  className="join-btn"
                  onClick={() => void join()}
                  disabled={phase === "busy"}
                  style={{
                    fontFamily: MONO,
                    background: "transparent",
                    border: `1px solid ${AMBER}`,
                    color: AMBER,
                    fontSize: 13,
                    letterSpacing: "0.2em",
                    padding: "12px 22px",
                    cursor: "pointer",
                    transition: "all 0.3s ease",
                    whiteSpace: "nowrap",
                  }}
                >
                  {phase === "busy" ? "…" : "列に並ぶ"}
                </button>
              </div>
              {error && (
                <p
                  className=""
                  style={{ fontFamily: MONO, marginTop: 16, fontSize: 12, letterSpacing: "0.08em", color: "#a4574f" }}
                >
                  {error}
                </p>
              )}
            </>
          ) : (
            <div>
              <p style={{ fontSize: 20, letterSpacing: "0.14em", margin: 0 }}>
                {alreadyJoined ? "すでに、並んでいる。" : "席は、用意しておく。"}
              </p>
              <p
                className=""
                style={{ fontFamily: MONO, marginTop: 16, fontSize: 12, letterSpacing: "0.1em", color: DIM, lineHeight: 2 }}
              >
                その時が来たら、この宛先に知らせる。
                <br />
                現在、<span style={{ color: AMBER }}>{count ?? "—"}</span> 人が扉の前に並んでいる。
              </p>
            </div>
          )}
        </div>
      </div>

      <footer
        className="reveal"
        style={{
          position: "absolute",
          fontFamily: MONO,
          bottom: 26,
          left: 0,
          right: 0,
          textAlign: "center",
          fontSize: 10,
          letterSpacing: "0.3em",
          color: FAINT,
          animationDelay: "1.8s",
        }}
      >
        まもなく、あなたのキャンパスで<a className="quiet" href="/admin">。</a>
      </footer>
    </main>
  );
}
