import { AbsoluteFill, Interactive } from "remotion";
import type { PropsWithChildren } from "react";

export const Frame = ({ children }: PropsWithChildren) => (
  <AbsoluteFill
    style={{
      background: "#f2f3eb",
      color: "#17372c",
      fontFamily: '"PingFang SC", "Helvetica Neue", sans-serif',
    }}
  >
    <Interactive.Div
      name="Brand"
      style={{
        position: "absolute",
        left: 128,
        top: 84,
        fontSize: 30,
        fontWeight: 600,
        letterSpacing: 3,
      }}
    >
      QUOTA GROVE / 额度森林
    </Interactive.Div>
    <Interactive.Div
      name="Demo disclosure"
      style={{
        position: "absolute",
        right: 128,
        top: 90,
        fontSize: 23,
        color: "#64766b",
      }}
    >
      状态演示 · ACTUAL APP RENDERS
    </Interactive.Div>
    {children}
    <Interactive.Div
      name="Footer"
      style={{
        position: "absolute",
        left: 128,
        bottom: 72,
        fontSize: 26,
        color: "#64766b",
      }}
    >
      macOS + Windows · 非官方 Codex 额度工具
    </Interactive.Div>
    <Interactive.Div
      name="Version"
      style={{
        position: "absolute",
        right: 128,
        bottom: 72,
        fontSize: 26,
        color: "#64766b",
      }}
    >
      v1.4.0
    </Interactive.Div>
  </AbsoluteFill>
);
