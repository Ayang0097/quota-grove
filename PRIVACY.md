# Quota Grove 隐私说明

Quota Grove 完全在本机运行。

- 不发起网络请求，不上传额度、日志或设备信息。
- 不包含遥测、广告或崩溃上报 SDK。
- 不读取或保存 OpenAI、GitHub 或其他账号凭据。
- 不读取 macOS 的 `~/.codex/auth.json` 或 Windows 对应数据目录中的 `auth.json`。
- 只在 macOS 的 `~/.codex/sessions` 或 Windows 的 `%USERPROFILE%\.codex\sessions` 最近运行事件尾部筛选 `rate_limits` 字段；不解析、显示或保存对话正文。
- 最近一次可信额度快照、卡片位置和展开状态保存在 macOS UserDefaults 或 Windows 的 `%LOCALAPPDATA%\QuotaGrove\settings.json`。
- Windows 登录启动只写入当前用户的 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`；不需要管理员权限。
- macOS 卸载脚本会删除登录启动项和本地偏好；Windows 便携版可直接退出后删除，若启用了登录启动，请先在右键菜单中关闭。

这是非官方工具，与 OpenAI 无隶属或背书关系。内部数据格式发生变化时，应用会安全失败，不会尝试绕过访问控制。
