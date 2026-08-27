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

## 落叶粒子

- 文件：`Assets/Leaves/forest-*.png`、`autumn-*.png`、`apocalypse-*.png`、`wasteland-*.png`。
- 来源：使用 OpenAI ImageGen 为 Quota Grove 专门生成的透明叶片图集，再在本地分割为运行时素材。
- 后处理：应用运行时根据森林、秋林、末日和废土主题调色，并使用 Core Image 生成景深虚化；方向模糊和飘落轨迹由应用代码实时绘制。
- 权利边界：素材不包含第三方品牌标识，不是从现有素材包、图库或同类项目复制。

除上述 Codex 额度来源标识外，项目未捆绑其他第三方品牌图标。

## README 展示图与动图

- 文件：`docs/screenshots/quota-grove-themes-en-v101.png`、`docs/screenshots/quota-grove-modes-en-v101.png`、`docs/screenshots/quota-grove-leaf-animation.gif`。
- 来源：两张 PNG 由 `Scripts/render-readme-showcase.swift` 调用应用内置的真实预览渲染器生成，再使用 Apple AppKit 合成；落叶 GIF 由应用的 `--render-leaf-frames` 逐帧渲染能力输出，再编码为动图。
- 内容：展示四个额度主题，以及收起、展开、贴边隐藏和主题同步落叶动效。
- 字体：仅使用 macOS 系统字体，不额外捆绑字体文件。
