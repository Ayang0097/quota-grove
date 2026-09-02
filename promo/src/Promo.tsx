import { TransitionSeries } from "@remotion/transitions";
import { QuotaScene } from "./scenes/QuotaScene";
import { WorkflowScene } from "./scenes/WorkflowScene";
import { ThemesScene } from "./scenes/ThemesScene";
import { DownloadScene } from "./scenes/DownloadScene";

export const Promo = () => (
  <TransitionSeries>
    <TransitionSeries.Sequence durationInFrames={180} name="Quota states">
      <QuotaScene />
    </TransitionSeries.Sequence>
    <TransitionSeries.Sequence durationInFrames={150} name="Workspace controls">
      <WorkflowScene />
    </TransitionSeries.Sequence>
    <TransitionSeries.Sequence durationInFrames={150} name="macOS themes">
      <ThemesScene />
    </TransitionSeries.Sequence>
    <TransitionSeries.Sequence durationInFrames={120} name="Download">
      <DownloadScene />
    </TransitionSeries.Sequence>
  </TransitionSeries>
);
