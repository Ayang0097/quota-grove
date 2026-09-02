import {
  Img,
  Easing,
  Interactive,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";
import { Frame } from "../Frame";

export const QuotaScene = () => {
  const frame = useCurrentFrame();
  const states = [85, 55, 25, 5];
  const active = Math.min(3, Math.floor(frame / 38));
  return (
    <Frame>
      <Interactive.Div
        name="Forest headline"
        style={{
          position: "absolute",
          left: 128,
          top: 235,
          fontSize: 96,
          fontWeight: 600,
          lineHeight: 1.2,
          letterSpacing: -4,
          translate: interpolate(frame, [0, 32], ["0px 14px", "0px 0px"], {
            easing: Easing.bezier(0.45, 0, 0.55, 1),
            extrapolateRight: "clamp",
          }),
        }}
      >
        把 Codex 额度
        <br />
        变成一片森林
      </Interactive.Div>
      <Interactive.Div
        name="Benefit"
        style={{
          position: "absolute",
          left: 134,
          top: 516,
          fontSize: 38,
          lineHeight: 1.7,
          color: "#64766b",
        }}
      >
        额度下降，风景随之改变。
        <br />
        Your quota, as a forest that fades.
      </Interactive.Div>
      <Img
        src={staticFile(`cards/${states[active]}.png`)}
        style={{
          position: "absolute",
          left: 990,
          top: 310,
          width: 800,
          height: 320,
        }}
      />
      <Interactive.Div
        name="State labels"
        style={{
          position: "absolute",
          left: 990,
          top: 685,
          display: "flex",
          gap: 12,
        }}
      >
        {states.map((percent, index) => (
          <Interactive.Div
            key={percent}
            name={`Quota ${percent}`}
            style={{
              width: 190,
              padding: "16px 0",
              textAlign: "center",
              borderBottom: `3px solid ${active === index ? "#24744f" : "#cbd3c8"}`,
              color: active === index ? "#17372c" : "#8b958a",
              fontSize: 26,
            }}
          >
            {["森林", "秋天", "末日", "废土"][index]} · {percent}%
          </Interactive.Div>
        ))}
      </Interactive.Div>
      <Interactive.Div
        name="Quota explanation"
        style={{
          position: "absolute",
          left: 134,
          top: 796,
          fontSize: 27,
          color: "#64766b",
        }}
      >
        7 天剩余额度 + 重置时间，一眼可见。
      </Interactive.Div>
    </Frame>
  );
};
