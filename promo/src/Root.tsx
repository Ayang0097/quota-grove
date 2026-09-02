import { Composition, Still } from "remotion";
import { Promo } from "./Promo";
import { SocialPreview } from "./SocialPreview";
import { QuotaScene } from "./scenes/QuotaScene";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="QuotaGrovePromo"
        component={Promo}
        width={1920}
        height={1080}
        fps={30}
        durationInFrames={600}
      />
      <Composition
        id="QuotaGroveDemo"
        component={QuotaScene}
        width={1920}
        height={1080}
        fps={30}
        durationInFrames={180}
      />
      <Still
        id="SocialPreview"
        component={SocialPreview}
        width={1280}
        height={640}
      />
    </>
  );
};
