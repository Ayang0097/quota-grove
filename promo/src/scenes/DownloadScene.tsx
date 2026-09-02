import {
  Img,
  Easing,
  Interactive,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";
import { Frame } from "../Frame";

export const DownloadScene = () => {
  const frame = useCurrentFrame();
  return (
    <Frame>
      <Interactive.Div
        name="Download headline"
        style={{
          position: "absolute",
          left: 128,
          top: 236,
          fontSize: 96,
          fontWeight: 600,
          letterSpacing: -3,
        }}
      >
        让额度，留在视线里。
      </Interactive.Div>
      <Interactive.Div
        name="Privacy benefit"
        style={{
          position: "absolute",
          left: 135,
          top: 380,
          fontSize: 40,
          color: "#64766b",
        }}
      >
        读取本机记录 · 不需要 API Key · 不消耗模型 Token
      </Interactive.Div>
      <Img
        src={staticFile("cards/85.png")}
        style={{
          position: "absolute",
          left: 128,
          top: 520,
          width: 740,
          height: 296,
          translate: interpolate(frame, [0, 40], ["0px 20px", "0px 0px"], {
            easing: Easing.bezier(0.45, 0, 0.55, 1),
            extrapolateRight: "clamp",
          }),
        }}
      />
      <Interactive.Div
        name="Project address"
        style={{
          position: "absolute",
          left: 990,
          top: 558,
          fontSize: 43,
          lineHeight: 1.7,
          fontWeight: 500,
        }}
      >
        github.com/Ayang0097/
        <br />
        <span style={{ fontSize: 76, fontWeight: 600 }}>quota-grove</span>
      </Interactive.Div>
      <Interactive.Div
        name="Call to action"
        style={{
          position: "absolute",
          left: 997,
          top: 751,
          fontSize: 30,
          color: "#64766b",
        }}
      >
        下载试用 · 分享反馈 · 有帮助就点个 Star
      </Interactive.Div>
    </Frame>
  );
};
