# Quota Grove 架构

## 组件

```text
NSApplication (.accessory)
  └─ AppDelegate
      ├─ CodexProcessMonitor
      ├─ LocalRateLimitSource
      │   └─ ~/.codex/sessions/**/*.jsonl (read only)
      └─ CardWindowController
          ├─ CardPanel (non-activating)
          └─ QuotaCardView (drawing + pointer interaction)
```

## 数据流

1. 进程监视器每 3 秒检查 Codex/ChatGPT 桌面客户端是否存在。
2. 客户端存在时，额度源每 20 秒读取最近会话文件的尾部。
3. 适配器先以文本常量过滤 `rate_limits` 行，再用 `JSONSerialization` 解析目标字段。
4. 选择 10080 分钟窗口，验证百分比范围，生成不可变 `QuotaSnapshot`。
5. 窗口控制器将快照传给纯绘制视图；视图按剩余百分比选择主题。
6. 成功快照保存到 UserDefaults。数据源暂时失败时继续显示最近快照，展开态通过数据更新时间体现新旧。

## 性能策略

- 每次只读取候选 JSONL 文件末尾最多 2 MiB，不加载完整历史。
- 会话目录最多保留 32 个最新候选；已命中的文件优先复用，周期性重新发现新会话。
- 正式背景按当前主题懒加载并缓存，不在每次刷新时重复解码；缺图时由少量 Core Graphics 路径即时绘制回退场景。
- UI 和文件读取分离；扫描在后台串行队列执行，主线程只更新视图。

## 窗口状态

```text
collapsed ⇄ expanded
    │           │
    └── drag to exact edge ──> stashed
                                 │
                        hover → temporarily revealed
                                 │
                        leave → stashed
```

展开状态、完整窗口位置和收纳边均持久化。收纳条自身不覆盖完整窗口位置。

收纳态可见宽度为 16 pt：外层沿用加深后的当前主题背景、18 pt 圆角与绿色描边，内层使用 5 pt 竖向额度轨道。左右边缘使用镜像轮廓，直边贴屏幕、圆角朝向桌面。

## 视觉系统

- 调色板：林夜 `#0C251D`、苔光 `#78E0AA`、秋褐 `#3B2115`、枫金 `#F4B84A`、灾变红 `#F05252`、废土灰 `#8A8580`。
- 字体：中文信息全部使用 macOS 系统字体；数字启用等宽数字特征。
- 签名元素：环境地貌与额度进度共享同一条底部“生命线”，额度下降时场景从绿色森林退化为红黑树林与灰白废墟。
- 克制原则：只有背景场景承担情绪，结构、字色和间距保持一致。

## 安全与失败

- 不创建网络连接。
- 不读取 `auth.json`、账号凭据、Git 仓库或对话内容字段。
- 格式变化、缺字段和异常百分比均返回可说明错误，不崩溃。
- 日志只写错误类别，不写 JSONL 行、会话路径或正文。
