import {
  Img,
  Easing,
  Interactive,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";
import { Frame } from "../Frame";

export const ThemesScene = () => {
  const frame = useCurrentFrame();
  return (
    <Frame>
      <Interactive.Div
        name="Themes headline"
        style={{
          position: "absolute",
          left: 128,
          top: 210,
          fontSize: 90,
          fontWeight: 600,
          letterSpacing: -3,
        }}
      >
        给你的桌面，换一种风景。
      </Interactive.Div>
      <Interactive.Div
        name="Platform scope"
        style={{
          position: "absolute",
          left: 133,
          top: 336,
          fontSize: 36,
          color: "#64766b",
        }}
      >
        macOS 五套背景 · Five background suites on macOS
      </Interactive.Div>
      <Interactive.Div
        name="Suite gallery"
        style={{
          position: "absolute",
          left: 133,
          top: 465,
          display: "flex",
          gap: 28,
          flexWrap: "wrap",
          width: 1660,
          translate: interpolate(frame, [0, 42], ["0px 28px", "0px 0px"], {
            easing: Easing.bezier(0.45, 0, 0.55, 1),
            extrapolateRight: "clamp",
          }),
        }}
      >
        {[
          ["85", "额度森林"],
          ["astralTerrarium", "星屿生态舱"],
          ["cloudseaBeacon", "云海灯塔"],
          ["moonlitConservatory", "月光花房"],
          ["abyssalReverie", "深海幻境"],
        ].map(([file, label]) => (
          <Interactive.Div
            key={file}
            name={label}
            style={{
              width: 534,
              display: "flex",
              alignItems: "center",
              gap: 20,
              height: 184,
            }}
          >
            <Img
              src={staticFile(`cards/${file}.png`)}
              style={{ width: 360, height: 144 }}
            />
            <Interactive.Div
              name={`${label} label`}
              style={{ fontSize: 25, color: "#64766b", width: 148 }}
            >
              {label}
            </Interactive.Div>
          </Interactive.Div>
        ))}
      </Interactive.Div>
    </Frame>
  );
};
