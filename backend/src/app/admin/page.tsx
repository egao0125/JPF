"use client";

import { useCallback, useEffect, useState } from "react";

type Report = {
  id: string;
  targetType: string;
  targetId: string;
  reason: string;
  createdAt: string;
  targetText: string;
  targetRemoved: boolean;
  school: string;
};

const box: React.CSSProperties = {
  background: "#ffffff",
  border: "1px solid #cfd9de",
  borderRadius: 14,
  padding: 20,
};
const input: React.CSSProperties = {
  width: "100%",
  boxSizing: "border-box",
  padding: "12px 14px",
  borderRadius: 10,
  border: "1px solid #cfd9de",
  background: "#ffffff",
  color: "#0f1419",
  fontSize: 15,
};
const button: React.CSSProperties = {
  padding: "10px 18px",
  borderRadius: 10,
  border: "none",
  background: "#0f1419",
  color: "#ffffff",
  fontWeight: 700,
  cursor: "pointer",
  fontSize: 14,
};

async function api(path: string, opts: RequestInit = {}, token?: string) {
  const res = await fetch(`/api/v1${path}`, {
    ...opts,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...opts.headers,
    },
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.error ?? "エラーが発生しました");
  return json;
}

export default function AdminPage() {
  const [token, setToken] = useState<string | null>(null);
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [step, setStep] = useState<"email" | "code" | "in">("email");
  const [message, setMessage] = useState("");
  const [reports, setReports] = useState<Report[]>([]);

  useEffect(() => {
    const saved = localStorage.getItem("jpf_admin_token");
    if (saved) {
      setToken(saved);
      setStep("in");
    }
  }, []);

  const loadReports = useCallback(async (t: string) => {
    try {
      const data = await api("/admin/reports", {}, t);
      setReports(data.reports);
      setMessage("");
    } catch (e) {
      setMessage((e as Error).message);
      if ((e as Error).message.includes("モデレーター") || (e as Error).message.includes("トークン")) {
        localStorage.removeItem("jpf_admin_token");
        setToken(null);
        setStep("email");
      }
    }
  }, []);

  useEffect(() => {
    if (token && step === "in") void loadReports(token);
  }, [token, step, loadReports]);

  const requestCode = async () => {
    try {
      const data = await api("/auth/request-code", { method: "POST", body: JSON.stringify({ email }) });
      setMessage(data.devCode ? `開発モード: コードは ${data.devCode}` : "コードを送信しました");
      setStep("code");
    } catch (e) {
      setMessage((e as Error).message);
    }
  };

  const verify = async () => {
    try {
      const data = await api("/auth/verify", { method: "POST", body: JSON.stringify({ email, code }) });
      if (!data.user.isModerator) {
        setMessage("このアカウントにはモデレーター権限がありません");
        return;
      }
      localStorage.setItem("jpf_admin_token", data.token);
      setToken(data.token);
      setStep("in");
    } catch (e) {
      setMessage((e as Error).message);
    }
  };

  const act = async (id: string, action: "remove" | "dismiss" | "ban") => {
    if (!token) return;
    try {
      await api(`/admin/reports/${id}`, { method: "POST", body: JSON.stringify({ action }) }, token);
      await loadReports(token);
    } catch (e) {
      setMessage((e as Error).message);
    }
  };

  return (
    <main style={{ maxWidth: 720, margin: "0 auto", padding: 24 }}>
      <h1 style={{ fontSize: 24 }}>🛡️ JPF モデレーション</h1>

      {step !== "in" && (
        <div style={{ ...box, display: "flex", flexDirection: "column", gap: 12, maxWidth: 420 }}>
          {step === "email" ? (
            <>
              <label>モデレーターのメールアドレス</label>
              <input
                style={input}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="mod@u-tokyo.ac.jp"
              />
              <button style={button} onClick={requestCode}>
                認証コードを送信
              </button>
            </>
          ) : (
            <>
              <label>認証コード（6桁）</label>
              <input
                style={input}
                value={code}
                onChange={(e) => setCode(e.target.value)}
                placeholder="123456"
              />
              <button style={button} onClick={verify}>
                ログイン
              </button>
            </>
          )}
          {message && <p style={{ color: "#f4212e", margin: 0 }}>{message}</p>}
        </div>
      )}

      {step === "in" && (
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <span style={{ color: "#536471" }}>未対応の通報: {reports.length}件</span>
            <button
              style={{ ...button, background: "#eff3f4", color: "#0f1419" }}
              onClick={() => {
                localStorage.removeItem("jpf_admin_token");
                setToken(null);
                setStep("email");
              }}
            >
              ログアウト
            </button>
          </div>
          {message && <p style={{ color: "#f4212e" }}>{message}</p>}
          {reports.length === 0 && <div style={box}>✨ 未対応の通報はありません</div>}
          {reports.map((r) => (
            <div key={r.id} style={box}>
              <div style={{ color: "#536471", fontSize: 13, marginBottom: 8 }}>
                {r.school} ・ {r.targetType === "post" ? "投稿" : "コメント"} ・{" "}
                {new Date(r.createdAt).toLocaleString("ja-JP")}
                {r.targetRemoved && " ・ ⚠️ 自動非表示中"}
              </div>
              <div style={{ marginBottom: 8, whiteSpace: "pre-wrap" }}>{r.targetText}</div>
              <div style={{ color: "#f4212e", fontSize: 14, marginBottom: 12 }}>通報理由: {r.reason}</div>
              <div style={{ display: "flex", gap: 8 }}>
                <button style={button} onClick={() => act(r.id, "remove")}>
                  削除する
                </button>
                <button
                  style={{ ...button, background: "#eff3f4", color: "#0f1419" }}
                  onClick={() => act(r.id, "dismiss")}
                >
                  問題なし
                </button>
                <button
                  style={{ ...button, background: "#f4212e", color: "#fff" }}
                  onClick={() => act(r.id, "ban")}
                >
                  投稿者をBAN
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </main>
  );
}
