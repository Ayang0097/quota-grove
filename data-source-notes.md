# 数据源调查记录

日期：2026-08-27

## 官方边界

OpenAI 官方资料说明 Codex 用量会随任务大小、复杂度和执行位置变化，额度状态与重置时间应以 Codex 客户端或用量界面显示为准。调查未发现面向个人 ChatGPT 订阅、可供第三方桌面工具稳定调用的公开“剩余百分比”API。

OpenAI 官方 Windows 文档确认 Codex 桌面应用可在 Windows 上原生运行，并使用 PowerShell 与 Windows 沙箱；该资料并未承诺本机额度事件的固定文件路径或字段格式。因此 Windows 版沿用可兼容、可安全失败的本机事件适配，而不把它表述为官方 API。

参考：

- https://learn.chatgpt.com/docs/pricing
- https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan
- https://learn.chatgpt.com/docs/windows/windows-app

## 本机观察

在用户本机合法可见的 macOS `~/.codex/sessions/**/*.jsonl` 运行事件中，`payload.rate_limits` 包含：

- `primary.used_percent`
- `primary.window_minutes`
- `primary.resets_at`
- `secondary`（可能为空）
- `plan_type`（可能为空）

2026-08-27 的最小字段验证显示 `window_minutes = 10080`，即 7 天窗口。实现不固化当时的百分比，只使用运行时最新可信事件。

## 适配规则

1. macOS 默认检查 `~/.codex/sessions`；Windows 默认检查 `%USERPROFILE%\.codex\sessions`，并支持通过 `QUOTA_GROVE_CODEX_HOME` 或 `CODEX_HOME` 指定兼容根目录。
2. 只检查最近变更的 JSONL 文件尾部。
3. 只对包含字符串 `\"rate_limits\"` 的行做 JSON 解析。
4. 在 `primary` 和 `secondary` 中优先匹配 10080 分钟；否则选择窗口最长且字段完整的一项，并按实际窗口命名。
5. 仅接受 `used_percent` 在 0...100 之间的有限数值。
6. `remaining_percent` 由 `100 - used_percent` 计算并限制显示到 0...100。
7. `resets_at` 按 Unix 秒解析；缺失时显示“重置时间未知”。
8. `plan_type` 只做可读性映射，未知值原样显示，不推测套餐权益。

## 隐私边界

- 不读取或保存账号密码、令牌和 `auth.json`。
- 不上传任何字段。
- 不记录事件原文或会话路径。
- 文件尾部扫描会经过相邻字节，但解析器只反序列化包含额度标识的行，其他行立即丢弃。

## 兼容性风险

该本机事件格式不是官方公开稳定接口。若路径、字段或语义改变，工具可能暂时无法更新。安全行为是保留最近可信快照，并在展开态继续显示数据更新时间，而不是猜测数据或尝试访问受限接口。
