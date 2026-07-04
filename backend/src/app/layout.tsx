import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = {
  title: "JPF — 匿名キャンパスSNS",
  description: "日本の大学生のための匿名キャンパスコミュニティ",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ja">
      <body
        style={{
          margin: 0,
          fontFamily:
            '-apple-system, BlinkMacSystemFont, "Hiragino Sans", "Noto Sans JP", sans-serif',
          background: "#ffffff",
          color: "#0f1419",
          minHeight: "100vh",
        }}
      >
        {children}
      </body>
    </html>
  );
}
