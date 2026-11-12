# Threadly DESIGN.md — 视觉与交互契约（单一真源）

原型（`design/prototype/`）与实现（`macos-host/`、`windows/`、`linux/` 三宿主）都遵循本文件；改视觉先改这里，再同步实现。
Tokens 逐值提取自 `macos-host/Sources/RivetHost/DesignTokens.swift`（accent / accent-soft）、`ContentView.swift` 内嵌 reader 样式（排版、发丝线、liked 色、列宽）与 `site/styles.css` 家族暖色变量（壳层中性色），保证原型 → 三宿主实现零翻译成本。
阅读器 cooked-HTML 元素级契约另见 `design/reader/DESIGN.md`（0.15.0 已交付，与本文件叠加使用，此处不重复）。

## Brief（2026-11-11）

- **目标**：维护模式，不从零重设计。把既有 UI 的 HIG 标准显式化并钉死：让「论坛长帖阅读」这个主角在界面上站出来（chrome 是被移除的东西）；三宿主共享同一份语义契约（同语义，不等像素，沿用 AGENTS.md「交互契约与验证状态」）。
- **原型范围**（6 屏 × 亮/暗）：① Browse 线程列表（英雄屏）② Thread 帖子详情阅读器 ③ Reply 回复撰写器 ④ Sign in 登录/账号态 ⑤ Notifications 通知 ⑥ AI 结果面板（BYOK 现状）。
- **Exit 条件**：6 屏关键状态齐（空态/加载态/错误态均有实现出处，见组件词汇状态表）+ 交互逻辑与既有实现一致（加载身份绑定、草稿保留、Retry 原位）+ HIG 清单全过 + 用户评审通过。
- **不在范围**：任何新功能——列表键盘导航（j/k）、富文本撰写器、应用内 BYOK 设置表单、移动端形态；`racket/backend.rkt` RVT1 面与路由契约变更；新配色体系；商业化/定价 UI。

## 设计原则（HIG 内核 · Threadly 特有）

- **阅读即产品**：壳的每一像素为长帖让路——680px 单列、发丝线分隔、无卡片堆叠；论坛的 cooked HTML 原样抵达读者，本地不重排其语义。
- **论坛是唯一事实源**：like 状态、编辑、删除一律以论坛为准；每条内容保留作者与原链（"Open on the forum" 一键可达）；缓存是临时的，不是权威。
- **匿名优先，登录降级不加码**：匿名可完整浏览/搜索/阅读；未登录时写入口不出现死按钮——隐藏（Reply 按钮、Notifications 行）或引导登录（回复撰写器内一键 Sign in）。
- **反馈及时且不串屏**：批次加载有进行态与计数（Showing X of Y）；加载失败 Retry 原位、列表选择不动；被取代的响应作废，迟到的帖子永不落在错误的标题下；每个写操作有 pending 与 settle 两态。
- **凭据不可见**：AI key 只经 CLI 配置、掩码显示、0600 落盘、仅发往所配端点；任何界面/错误/日志不得出现凭据明文。

## Tokens（与实现 1:1）

| Token | Light | Dark | 用途 |
|---|---|---|---|
| `--accent` | `#c15f3c` | `#c15f3c` | 陶土 accent：作者名/链接/按钮/类型图标/未读 pill（`DesignTokens.swift`，tint 固定不随外观） |
| `--accent-soft` | `#f7e5dd` | `#3b2a22` | 选中行/更新横幅/disclosure 弱底（`DesignTokens.swift`） |
| `--liked` | `#e0413e` | `#e0413e` | 已点赞爱心（唯一的红；`ContentView.swift` reader） |
| `--bg` | `#faf7f2` | `#1b1a18` | 画布（`site/styles.css` 家族暖底） |
| `--surface` | `#ffffff` | `#24221f` | 侧栏/浮层/工具栏（`site/styles.css`） |
| `--raised` | `#f0ebe2` | `#2e2b27` | hover/占位弱底（`site/styles.css` `--chip-bg`） |
| `--line` | `#e8e2d9` | `#35322d` | 壳层分隔（`site/styles.css`） |
| `--ink` | `#1f1d1a` | `#ece9e2` | 主文字（`site/styles.css`） |
| `--mute` | `#6b6660` | `#a6a099` | 次级文字/计数/时间戳（`site/styles.css` `--muted`） |
| `--hairline` | `rgba(128,128,128,.2)` | 同 | 阅读器帖子分隔/表格线（`ContentView.swift` reader） |
| `--fill` | `rgba(128,128,128,.08–.14)` | 同 | 行内代码/引用底/hover（`ContentView.swift` reader） |

- **accent 不随外观提亮**是应用现状（SwiftUI `.tint` 固定）；站点暗色提亮为 `#d08a6e`，未进入应用——如未来对齐须先改本表并同步 `DesignTokens.swift`。
- 壳层 chrome（侧栏/工具栏材质）在三宿主上跟随系统材质（AppKit sidebar / WinUI / GTK4），表中中性色是原型与语义基准，宿主材质允许差异；阅读器文档三宿主必须逐值一致（`design/reader` 契约）。
- **字体**：`system-ui, -apple-system, "Segoe UI", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif`；正文 15px/1.6（阅读器与列表一致），阅读列宽 680px（padding `22px 28px 48px`）；线程头 `.title2` ≈22px/600；次级 13px（callout）；caption 12px；caption2 11px（计数/时间戳，`tabular-nums` 等宽数字）；代码 `ui-monospace` 13px。
- **圆角**：窗口 12px（原型画布）· 搜索框/编辑器/代码块 8px · 控件与行内元素 6px · 胶囊 99px。**间距节奏**：4/8/12/16/24。**动效**：120ms ease，不过度。
- **语言**：界面文案英文（跟随现行实现，如 "Search the archive"、"Load more"），契约文档与评审注释中文。

## 组件词汇（含状态）

`Sidebar`（顶部搜索框 "Search the archive"（有字出 × 清除钮）+ Browse 分区：Notifications（仅登录可见）/ Latest / categories（论坛自有色圆点，顺序 = 论坛位次）+ 主题列表 + 底部账号区）· `TopicListRow`（标题 ≤2 行截断 + `CategoryChip`（论坛色胶囊）+ `CountStrip`（reply/eye/heart，等宽数字）+ `N new` 未读 pill（本地已读追踪，tooltip 说明）+ `RelativeStamp`（"2h/3d"，全时间进 tooltip））· `NotificationListRow`（类型图标 accent 色 + "username · title"，未读加 ● 前缀；点击打开关联主题）· `ThreadReader`（680px 文档：meta 行 avatar+作者+`#N`+相对时间+like；quote/onebox/code/table 契约见 design/reader）· `Morebar`（"Showing X of Y posts · Load more"，批次进行中禁用；空批次移除）· `JumpToBottom`（右下角胶囊浮钮，到底即隐）· `ReplySheet`（Markdown 编辑器 + "Markdown · as \<user\>" + 草稿每键保存，Esc=Cancel ⏎=Reply）· `SignInSheet`（浏览器批准页 + 粘贴码，空码禁用主按钮）· `AIPanel`（Summary/Translation 结果可选中 + 免责行）· `StatusBar`（更新横幅 accent-soft 底 / up-to-date 确认 / 黄三角错误行，均可 Dismiss）· 空态族：`Select a topic`（详情默认占位）· `Nothing here yet`（空分类，指引换分类或搜索）· `Couldn't open this thread`（Retry 原位 / Back to list）· `Empty thread` · `No notifications.`。

## 不变式

1. **accent 语义钉死**：只给作者名、链接、可点按钮、通知类型图标、未读 pill、选中底（accent-soft）与更新横幅；liked 是唯一的红；分类 chip 用论坛自己的颜色，三者互不混用；禁止大面积 accent 色块。
2. **亮暗成对**：不存在只有单态的界面；每个 UI 改动以 `THREADLY_APPEARANCE=dark|light` 双验证（家族红线）。
3. **层级三层封顶**：bg < surface < raised/accent-soft；分隔靠 hairline，不用重描边与阴影堆叠表达层级。
4. **写路径永远可回退**：回复失败草稿保留、撰写器关闭/切题不丢字；失败加载 Retry 原位且列表选择不动；like/回复有 pending 与 settle 态，失败后按钮必须醒来。
5. **凭据与竞态零暴露**：key 掩码 + 0600 + 不出现在任何 UI/日志/反馈；身份作废（登出/切题/回列表）后迟到的响应一律丢弃，不得串屏。


## 平台映射与差异声明（预钉 · 宿主实现时升级为落点表）

统一层（三平台必须一致，`design/prototype/` 原型已锁定）：信息架构、核心流程、快捷键语义、
语义色与层级词汇。因地制宜层（按平台惯例落地，不预画像素）：

| 维度 | macOS | Windows | Linux |
|---|---|---|---|
| 修饰键 | ⌘ | Ctrl | Ctrl |
| 命令入口 | 原生菜单栏 | 菜单栏/命令行内 | 菜单栏 |
| 字体 | 系统栈 + PingFang SC | 系统栈 + Microsoft YaHei | 系统栈 + Noto Sans CJK |
| 原生控件 | SwiftUI 控件 | WinUI 3 控件 | GTK4 控件 |

差异声明纪律：宿主特例必须先写进本节才能实现；未声明的宿主差异按违约处理
（案例：taskly 漂移台账 D8）。
