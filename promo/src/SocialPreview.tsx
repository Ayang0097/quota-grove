import { AbsoluteFill, Img, Interactive, staticFile } from "remotion";

export const SocialPreview = () => (
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
        left: 70,
        top: 53,
        fontSize: 22,
        letterSpacing: 3,
        fontWeight: 600,
      }}
    >
      QUOTA GROVE / 额度森林
    </Interactive.Div>
    <Interactive.Div
      name="Platforms"
      style={{
        position: "absolute",
        right: 70,
        top: 55,
        fontSize: 20,
        color: "#64766b",
      }}
    >
      macOS + Windows
    </Interactive.Div>
    <Interactive.Div
      name="Headline"
      style={{
        position: "absolute",
        left: 70,
        top: 136,
        fontSize: 62,
        lineHeight: 1.22,
        fontWeight: 600,
        letterSpacing: -2,
      }}
    >
      把 Codex 的剩余额度，
      <br />
      变成一片森林。
    </Interactive.Div>
    <Interactive.Div
      name="English tagline"
      style={{
        position: "absolute",
        left: 74,
        top: 310,
        fontSize: 26,
        color: "#64766b",
      }}
    >
      Your quota, as a forest that fades.
    </Interactive.Div>
    <Img
      src={staticFile("cards/85.png")}
      style={{
        position: "absolute",
        left: 70,
        top: 388,
        width: 530,
        height: 212,
      }}
    />
    <Img
      src={staticFile("cards/5.png")}
      style={{
        position: "absolute",
        left: 680,
        top: 388,
        width: 530,
        height: 212,
      }}
    />
    <Interactive.Div
      name="Demo label"
      style={{
        position: "absolute",
        right: 74,
        top: 317,
        fontSize: 18,
        color: "#64766b",
      }}
    >
      状态演示 / 非官方工具
    </Interactive.Div>
  </AbsoluteFill>
);
