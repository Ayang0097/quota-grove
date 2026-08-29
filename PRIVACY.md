# Quota Grove 隐私说明

Quota Grove 的额度读取、额度缓存和卡片显示完全在本机运行。“跟随当地天气”是默认关闭的可选功能。

- 不上传额度、Codex 日志、对话正文、账号凭据或设备信息。
- 不包含遥测、广告或崩溃上报 SDK。
- 不读取或保存 OpenAI、GitHub 或其他账号凭据。
- 不读取 macOS 的 `~/.codex/auth.json` 或 Windows 对应数据目录中的 `auth.json`。
- 只在 macOS 的 `~/.codex/sessions` 或 Windows 的 `%USERPROFILE%\.codex\sessions` 最近运行事件尾部筛选 `rate_limits` 字段；不解析、显示或保存对话正文。
- 最近一次可信额度快照、卡片位置和展开状态保存在 macOS UserDefaults 或 Windows 的 `%LOCALAPPDATA%\QuotaGrove\settings.json`。
- 用户在 macOS 主动选择自定义背景后，图片会缩放并转换为 `~/Library/Application Support/Quota Grove/custom-background.png`；该文件只用于本机卡片绘制，不会上传。选择“恢复默认背景”时会删除这份应用内副本，不影响原始图片。
- 只有用户主动开启“跟随当地天气”后，macOS 才会通过系统权限请求当前位置。
- 获取到的经纬度会先四舍五入到两位小数（约公里级），不会保存或发送原始精确坐标。
- 模糊化坐标会发送到 `api.open-meteo.com`，请求仅包含当前天气代码、降雨量、阵雨量和降雪量，用于判断是否显示雨效或雪效；不会随请求发送额度或 Codex 数据。
- 模糊化坐标最多在本机缓存 6 小时，天气结果最多缓存 30 分钟；关闭天气联动后不再定位或请求天气。
- 天气状态正常情况下每 15 分钟更新一次。Open-Meteo 会按其自身隐私政策处理网络请求；天气数据依据 CC BY 4.0 使用并署名。
- Windows 登录启动只写入当前用户的 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`；不需要管理员权限。
- macOS 卸载脚本会删除登录启动项和本地偏好；Windows 便携版可直接退出后删除，若启用了登录启动，请先在右键菜单中关闭。

这是非官方工具，与 OpenAI 无隶属或背书关系。内部数据格式发生变化时，应用会安全失败，不会尝试绕过访问控制。

天气数据来源：[Open-Meteo](https://open-meteo.com/)（CC BY 4.0）。
