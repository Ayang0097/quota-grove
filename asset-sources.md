# 素材与视觉来源

## Quota Grove 应用图标

- 文件：`Assets/QuotaGroveIcon.svg`
- 来源：本项目独立绘制的 SVG。
- 构成：命令提示符、叶片和未闭合的额度环。
- 字体：无。

## Codex 额度来源标识

- 文件：`Assets/CodexIcon.png`
- 来源：本机安装的官方 Codex/ChatGPT 桌面应用资源 `icon-codex-light.png`。
- 原始规格：1024 × 1024 px，透明背景、圆角底座。
- 使用位置：仅显示在卡片“7 天额度”标题旁，用于说明额度数据来自本机 Codex/ChatGPT 客户端。
- 不用于：Quota Grove 应用图标、仓库头像、产品 Logo、宣传主视觉或暗示官方合作与背书。
- 权属：该图标以及 OpenAI、Codex、ChatGPT 相关名称和商标的权利归其各自权利人所有；本项目不主张所有权，也不通过仓库许可证对其进行再许可。

## 卡片主题

- 正式背景：产品负责人提供的 `bg/*.png`，源尺寸均为 1983 × 793 px，与收起卡片保持约 2.5:1 比例。依据 PRD，这些素材由产品负责人确认拥有使用和分发权利。
- 森林：`bg/背景百分之50以上.png`
- 秋天：`bg/背景百分之50以下.png`
- 末日：`bg/背景百分之20以下.png`
- 废土：`bg/背景百分之3以下.png`
- 回退背景：`QuotaCardView.swift` 中独立绘制的 Core Graphics/AppKit 路径和渐变，仅在正式图片缺失时使用。

除上述 Codex 额度来源标识外，项目未捆绑其他第三方品牌图标。

## README 展示图

- 文件：`docs/screenshots/quota-grove-themes-en-v101.png`、`docs/screenshots/quota-grove-modes-en-v101.png`。
- 来源：由 `Scripts/render-readme-showcase.swift` 调用应用内置的真实预览渲染器生成卡片，再使用 Apple AppKit 合成展示画布。
- 内容：展示四个额度主题，以及收起、展开和贴边隐藏三种界面形态。
- 字体：仅使用 macOS 系统字体，不额外捆绑字体文件。
