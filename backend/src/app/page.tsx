export default function Home() {
  return (
    <main
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        minHeight: "100vh",
        gap: 16,
        textAlign: "center",
        padding: 24,
      }}
    >
      <div style={{ fontSize: 64 }}>🎓</div>
      <h1 style={{ margin: 0, fontSize: 40, color: "#0f1419" }}>JPF</h1>
      <p style={{ margin: 0, color: "#536471", maxWidth: 420, lineHeight: 1.7 }}>
        日本の大学生のための匿名キャンパスSNS。
        <br />
        このサーバーは iOS アプリ用 API（<code>/api/v1</code>）を提供しています。
      </p>
      <a
        href="/admin"
        style={{
          color: "#0f1419",
          textDecoration: "none",
          border: "1px solid #cfd9de",
          padding: "10px 24px",
          borderRadius: 12,
        }}
      >
        モデレーター管理画面 →
      </a>
    </main>
  );
}
