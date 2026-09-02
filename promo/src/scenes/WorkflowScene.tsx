import {
  Img,
  Easing,
  Interactive,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";
import { Frame } from "../Frame";

export const WorkflowScene = () => {
  const frame = useCurrentFrame();
  return (
    <Frame>
      <Interactive.Div
        name="Workflow headline"
        style={{
          position: "absolute",
          left: 128,
          top: 210,
          fontSize: 90,
          fontWeight: 600,
          letterSpacing: -3,
        }}
      >
        需要时展开，忙碌时贴边。
      </Interactive.Div>
      <Interactive.Div
        name="Workflow subtitle"
        style={{
          position: "absolute",
          left: 133,
          top: 336,
          fontSize: 36,
          color: "#64766b",
        }}
      >
        Click for details. Hover to reveal. Keep your workspace clear.
      </Interactive.Div>
      <Img
        src={staticFile("cards/55.png")}
        style={{
          position: "absolute",
          left: 150,
          top: 560,
          width: 550,
          height: 220,
          translate: interpolate(frame, [0, 36], ["0px 24px", "0px 0px"], {
            easing: Easing.bezier(0.45, 0, 0.55, 1),
            extrapolateRight: "clamp",
          }),
        }}
      />
      <Img
        src={staticFile("cards/expanded.png")}
        style={{
          position: "absolute",
          left: 820,
          top: 430,
          width: 470,
          height: 418.3,
          translate: interpolate(frame, [6, 44], ["0px 24px", "0px 0px"], {
            easing: Easing.bezier(0.45, 0, 0.55, 1),
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
      <Interactive.Div
        name="Screen edge"
        style={{
          position: "absolute",
          left: 1480,
          top: 438,
          width: 280,
          height: 410,
          borderRight: "3px solid #a6b3a4",
          background: "#e5e9df",
          borderRadius: "22px 0 0 22px",
        }}
      >
        <Img
          src={staticFile("cards/stashed.png")}
          style={{
            position: "absolute",
            right: 0,
            top: 95,
            width: 44,
            height: 220,
          }}
        />
      </Interactive.Div>
      <Interactive.Div
        name="Compact label"
        style={{
          position: "absolute",
          left: 330,
          top: 855,
          fontSize: 27,
          color: "#64766b",
        }}
      >
        收起 / Compact
      </Interactive.Div>
      <Interactive.Div
        name="Expanded label"
        style={{
          position: "absolute",
          left: 940,
          top: 872,
          fontSize: 27,
          color: "#64766b",
        }}
      >
        展开 / Details
      </Interactive.Div>
      <Interactive.Div
        name="Stashed label"
        style={{
          position: "absolute",
          left: 1510,
          top: 872,
          fontSize: 27,
          color: "#64766b",
        }}
      >
        贴边 / Stashed
      </Interactive.Div>
    </Frame>
  );
};
