# Threadly DESIGN.md — 视觉与交互契约

原型（`design/prototype/`）与实现（`macos-host/`、`windows/`、`linux/` 三宿主）都遵循本文件的语义、不变式与平台差异；**数值不在此复制**。

**真源分工**：颜色、字体栈、字号、列宽、圆角、间距与动效时长的具体值以 `design/prototype/shared.css` 为唯一真源（亮暗成对；accent 系与 `macos-host/Sources/RivetHost/DesignTokens.swift` 同源，壳层中性色与 `site/styles.css` 同源，阅读器排版见 `ContentView.swift`）；本文件只记语义、来源与决策。改值改 CSS，改语义改本文件。
阅读器 cooked-HTML 元素级契约另见 `docs/reader-design.md`（0.15.0 已交付，与本文件叠加使用，此处不重复）。

## Brief（2026-11-11）

- **目标**：维护模式，不从零重设计。把既有 UI 的 HIG 标准显式化并钉死：让「论坛长帖阅读」这个主角在界面上站出来（chrome 是被移除的东西）；三宿主共享同一份语义契约（同语义，不等像素，沿用 AGENTS.md「交互契约与验证状态」）。
- **原型范围**（6 屏 × 亮/暗）：① Browse 线程列表（英雄屏）② Thread 帖子详情阅读器 ③ Reply 回复撰写器 ④ Sign in 登录/账号态 ⑤ Notifications 通知 ⑥ AI 结果面板（BYOK 现状）。
- **Exit 条件**：6 屏关键状态齐（空态/加载态/错误态均有实现出处，见组件词汇状态表）+ 交互逻辑与既有实现一致（加载身份绑定、草稿保留、Retry 原位）+ HIG 清单全过 + 用户评审通过。
- **不在范围**：任何新功能——列表键盘导航（j/k）、富文本撰写器、应用内 BYOK 设置表单；`racket/backend.rkt` RVT1 面与路由契约变更；新配色体系；商业化/定价 UI。
- **范围修订（owner 2026-11-22）**：原“不在范围：移动端形态”本轮解禁，新增六个 iPhone 移动阅读/回复原型；不扩展真实后端或论坛认证能力。

## 设计原则（HIG 内核 · Threadly 特有）

- **阅读即产品**：壳的每一像素为长帖让路——固定宽度的单列阅读列、发丝线分隔、无卡片堆叠；论坛的 cooked HTML 原样抵达读者，本地不重排其语义。
- **论坛是唯一事实源**：like 状态、编辑、删除一律以论坛为准；每条内容保留作者与原链（"Open on the forum" 一键可达）；缓存是临时的，不是权威。
- **匿名优先，登录降级不加码**：匿名可完整浏览/搜索/阅读；未登录时写入口不出现死按钮——隐藏（Reply 按钮、Notifications 行）或引导登录（回复撰写器内一键 Sign in）。
- **反馈及时且不串屏**：批次加载有进行态与计数（Showing X of Y）；加载失败 Retry 原位、列表选择不动；被取代的响应作废，迟到的帖子永不落在错误的标题下；每个写操作有 pending 与 settle 两态。
- **凭据不可见**：AI key 只经 CLI 配置、掩码显示、0600 落盘、仅发往所配端点；任何界面/错误/日志不得出现凭据明文。

## Tokens（语义；值不在此复制）

值类 token 真源 = `DesignTokens.swift`（accent 系）· `site/styles.css`（家族暖底中性系）· `ContentView.swift` reader（liked/hairline/fill）；原型 `design/prototype/shared.css` 与其一一对应，本表只记语义与层级。

| Token | 语义 | 来源 |
|---|---|---|
| `--accent --accent-soft` | 陶土 accent：作者名/链接/按钮/类型图标/未读 pill + 选中行/更新横幅/disclosure 弱底（tint 固定不随外观） | `DesignTokens.swift` |
| `--liked` | 已点赞爱心（唯一的红） | `ContentView.swift` reader |
| `--bg --surface --raised --line --ink --mute` | 家族暖底中性系：画布 / 侧栏浮层工具栏 / hover 占位弱底 / 壳层分隔 / 文字 | `site/styles.css` |
| `--hairline --fill` | 阅读器帖子分隔/表格线 / 行内代码引用底 hover | `ContentView.swift` reader |

- **accent 不随外观提亮**是应用现状（SwiftUI `.tint` 固定）；站点暗色 accent 有提亮值，未进入应用——如未来对齐须先改本表并同步 `DesignTokens.swift` 与 `shared.css`。
- 壳层 chrome（侧栏/工具栏材质）在三宿主上跟随系统材质（AppKit sidebar / WinUI / GTK4），表中中性色是原型与语义基准，宿主材质允许差异；阅读器文档三宿主必须逐值一致（`docs/reader-design.md` 契约）。
- **字体角色**：系统 sans 栈；正文（阅读器与列表同一基准）、线程头、次级（callout）、caption、caption2（计数/时间戳用 `tabular-nums` 等宽数字）、代码 mono——各层级的字号/行高见 `shared.css`；阅读列宽固定为单列（原则见「阅读即产品」）。
- **几何与动效**：窗口 / 搜索框·编辑器·代码块 / 控件与行内元素 / 胶囊各有圆角层级，间距节奏与动效时长均以 `shared.css` 为准，动效不过度。
- **语言**：界面文案英文（跟随现行实现，如 "Search the archive"、"Load more"），契约文档与评审注释中文。

## 组件词汇（含状态）

`Sidebar`（顶部搜索框 "Search the archive"（有字出 × 清除钮）+ Browse 分区：Notifications（仅登录可见）/ Latest / categories（论坛自有色圆点，顺序 = 论坛位次）+ 主题列表 + 底部账号区）· `TopicListRow`（标题 ≤2 行截断 + `CategoryChip`（论坛色胶囊）+ `CountStrip`（reply/eye/heart，等宽数字）+ `N new` 未读 pill（本地已读追踪，tooltip 说明）+ `RelativeStamp`（"2h/3d"，全时间进 tooltip））· `NotificationListRow`（类型图标 accent 色 + "username · title"，未读加 ● 前缀；点击打开关联主题）· `ThreadReader`（固定宽度单列文档：meta 行 avatar+作者+`#N`+相对时间+like；quote/onebox/code/table 契约见 docs/reader-design.md）· `Morebar`（"Showing X of Y posts · Load more"，批次进行中禁用；空批次移除）· `JumpToBottom`（右下角胶囊浮钮，到底即隐）· `ReplySheet`（Markdown 编辑器 + "Markdown · as \<user\>" + 草稿每键保存，Esc=Cancel ⏎=Reply）· `SignInSheet`（浏览器批准页 + 粘贴码，空码禁用主按钮）· `AIPanel`（Summary/Translation 结果可选中 + 免责行）· `StatusBar`（更新横幅 accent-soft 底 / up-to-date 确认 / 黄三角错误行，均可 Dismiss）· 空态族：`Select a topic`（详情默认占位）· `Nothing here yet`（空分类，指引换分类或搜索）· `Couldn't open this thread`（Retry 原位 / Back to list）· `Empty thread` · `No notifications.`。

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


## 移动端阅读与回复契约（owner 2026-11-22）

### 定线与依据

桌面 = rivet（三宿主已落地）；移动端 = 移动阅读/回复契约（原生 Swift，等 rivet 移动宿主定型；owner 2026-11-22 要求原型含移动端视图）。本节只定义原型与交互，不宣称已完成 Swift 实现。

阅读器 cooked-HTML 元素级契约以 `docs/reader-design.md` 为准，`reader/index.html` 为排版样例。三宿主逐值一致的原则延伸至移动端：列宽自适应、核心排版保持；下列 owner 指定的触控、最小字号和可读性适配具名记录，不回写或改动正式阅读器契约。

本轮遵循家族设计规范 `2026-11-20-minimal-family` 的适用项；现有六个桌面屏保留。本地 OpenDesign 项目不是 git 工作区，源 SHA、commit/push 与原生宿主验收不在本次原型交付中冒充完成。

### 文件与视觉映射

- 六个独立入口：`prototype/mobile-browse.html`、`mobile-thread.html`、`mobile-reply.html`、`mobile-notifications.html`、`mobile-signin.html`、`mobile-ai.html`。各自内联行为，只相对引用同目录 `shared.css`，零远程字体、脚本、图片或服务依赖。
- 纯内容画布有一个固定的最大宽度（手机内容宽度），视口更窄时自然收缩，居中、无边框外壳、灵动岛、虚拟状态栏；背景使用既有 `--bg`。桌面样式不重写，新增样式全部以 `.mobile` 限定。
- 复用 `--accent` / `--accent-soft`、`--liked`、暖底中性与 `--hairline` / `--fill`。`liked` 只用于已点赞爱心，错误用文本与恢复动作表达，不用新红色。
- 可读性适配：原始陶土色用于小字在暖底的对比不足 4.5:1；移动强调文字使用由现有 `--accent` 与 `--ink` 混合的派生别名 `--m-accent-text`，不引入新色值或修改全局 token。图形、引用竖线与 liked 保留原语义色。辅助文案采用现有 `--mute`。
- 系统 UI 字体；正文沿用阅读器基准，编辑器、大标题、主题标题、代码、辅助各有层级（值见 `shared.css` 的 `.mobile` 规则）；计数/时间戳 tabular。移动文字不得低于 owner 规定的下限（12px），原样例中低于下限的作者引用行、onebox source 等已提升。
- 内容边距与壳层节奏按 4px 节奏；控件与面板各有圆角层级（值见 CSS）。阅读器内部 quote / code / pre 圆角以及元素内边距按正式/现有元素契约保留，优先级高于壳层默认值。
- `aside.quote` 作者行、`aside.onebox` source/标题/说明、`details/summary`、`pre/code`、`hr` 与 `.table-scroll` 均有示例；代码保持原行不折断，表格在自身区域横向滚动，不撑破画布，onebox 缩略图规则 max-width:100%。
- 功能图标使用现有内联 SVG 路径；返回箭头由现有 down 图形旋转，不引新库。动效短促（值见 CSS），reduced-motion 时关闭动画/平滑滚动。

### 流程、身份与状态

- Browse：搜索、Latest/categories 选择抽屉、分类圆点、CategoryChip、CountStrip、未读 pill 与相对时间；返回恢复搜索、分类、主题与列表滚动。Notifications 入口仅登录可见。
- Thread：单列阅读、同页分批追加、显示真实本地样例 Showing X of Y；批次中禁用按钮，失败原位 Retry 不丢位置；JumpToBottom 在未到底时显示，到底隐藏，按钮避开底栏。长代码和表格只在各自容器横向滚动。
- 阅读内容沿用旧原型四条示例，另加一条明确标注 Reader formatting sample 的元素覆盖样例；列表历史计数为原型样例，不冒充真实实时论坛数据。未附正文的主题呈 Empty thread 并给出返回路径。
- Reply：全屏 textarea、`Markdown · as samr`、每键保存指示、Cancel 保留草稿、发送按钮替代回车发送；重复提交防护，失败保留草稿；成功只新增本地回复，不触发真实写入。切题按 topic id 区分草稿。Enter 始终换行。
- Sign in：浏览器批准步骤与粘贴码，空码禁用 Complete sign-in；本地 Browser approval dialog 模拟浏览器批准页，明确无真实连接，提供 `THREADLY-DEMO` 样例码；只接受该码，不保存授权码，不创建真实论坛密钥。
- 匿名阅读不显示可交互点赞/Reply，点赞数量为纯文本；登录入口可见。Reply/Notifications 独立评审入口首次默认样例账户 samr，Browse/Thread 首次默认匿名；已有明确退出状态优先，不因打开独立入口覆盖身份。
- Notifications：沿用类型图标 accent 色，未读 ● 与辅助名称；点击关联主题并标记本地已读。空态文案 `No notifications.`；匿名直接进入该页面提示登录，不泄露通知列表。
- AI：主题上方的原生半屏 dialog，Summary/Translation 切换、结果可选择、免责行、关闭与焦点恢复；结果明确为本地样例。无实时模型连接，不新增 BYOK 表单。
- 对话框开启/关闭正确转移焦点；主流程有键盘焦点；异步请求按导航/身份序号作废，迟到结果不串屏。所有交互命中至少 44×44px，列表行不低于 44px。
- localStorage 可用时保存主题阅读位置、最深已读、身份、主题分批数量、主题草稿及亮暗偏好；不可用则本页内存降级并在草稿状态明确提示。

### 评审状态入口

不在产品界面增加测试开关。任一移动页面可添加 `?state=empty`，阅读页支持 `?state=load-error`、`?state=loading`、`?state=more-error`，回复页支持 `?state=reply-error`、`?state=session-expired`，AI 页支持 `?state=ai-error`。错误恢复不自动重写草稿，成功重试恢复对应区域。

### Exit 条件与家族 UI 适用项

- [ ] 六个移动关键屏齐全，可从 index Mobile 分组打开。
- [ ] cooked-HTML quote/onebox/code/table/details/hr 与正式契约对齐，移动偏离项有明确理由。
- [ ] 导航返回、加载恢复、已读与草稿保留可靠；匿名入口限制正确。
- [ ] 亮暗双主题真实切换；正文/辅助/强调文字均达到 4.5:1。
- [ ] 零外部资源依赖，相对引用有效；无小于 12px 的移动文字。
- [ ] 可见操作命中至少 44×44px；键盘焦点、reduced-motion 与文字放大适用项有证据。
- [ ] 减法、排版、状态、操作可靠、家族一致等清单适用项完成原型自查；原生宿主、Swift 实物对照与用户评审待后续，不以 HTML 自查代替。


### 本轮自查证据（2026-11-22）

- **通过：文件与资源**。六个移动 HTML 均独立内联交互，仅引用同目录 `shared.css`；无外部脚本、图片、字体、fetch、XHR 或 CSS import；导航页全部相对引用存在。
- **通过：字号与语义样式**。移动专属声明的字号均不低于 12px；纯画布最大宽度 390px；控件、summary 与正文链接均显式声明最小 44×44px 命中尺寸。正文链接为满足触控命中使用 inline-flex，可能增加所在行的高度，这是移动触控适配，不改变链接语义。
- **通过：配色计算**。根据共享 token 与移动派生强调文字色，分别计算亮/暗两态 ink、mute、accent-text 在 bg/surface/raised/accent-soft 上的 24 组对比，最小 4.66:1。此为样式色值计算，不冒充实际屏幕像素采样。
- **通过：DOM 行为自查**。六个入口初始化与主题切换无脚本错误；搜索/返回保留、按批追加、quote/onebox/code/table/details/hr 覆盖、匿名隐藏点赞与 Reply、批准码流程、Cancel 草稿恢复、本地发送、点赞双向切换，以及 load-error/more-error/reply-error/session-expired/empty/ai-error 恢复路径均通过 DOM 环境检查。
- **未验证：真实浏览器与原生环境**。无头浏览器启动失败；连接的浏览器访问服务不可用。因此未验证实际布局溢出、真实 44px 几何命中、原生 dialog 焦点锁定、读屏、200% 文字放大、实际 reduced-motion 效果与 iPhone 实机表现。已有尺寸和降级规则，不以源码声明替代平台证据。
- **待评审**：owner 视觉/交互评审、Swift 实现与本原型对照、git 落账；本项目没有 git 元数据，未执行 commit/push。


## 原型对齐家族基线（2026-11-26）

对齐家族设计规范修订 `2026-11-20-minimal-family`；起始 SHA `d00ad58`。范围仅 `design/`：信息架构、强调色、布局结构、样例数据与文案含义不变，主题的存储与切换方式不变（页面仍是 `#app.dark`，导航页为 `body.dark`）。

| 规则 | 结果 | 变更与证据 |
|---|---|---|
| R1 主题切换 | 通过 | 六个桌面页与本地导航页 `index.html`：`◐` 字形换为内联线性 SVG（浅色显太阳、深色显月亮，16px、stroke 1.7）；`.iconbtn` 改为安静图标钮（28px、透明底无边框、hover `--fill`），同栏 `.toolbtn` 由 26px 提到同高 28px；`aria-label` 与 `title` 用英文 "Switch to light theme" / "Switch to dark theme" 并随主题更新（原中文 title 是英文页的文案缺陷）。状态栏评审注记里的「◐」字样一并去掉。移动端的文字切换钮（Light / Dark）无字形问题，未改。 |
| R2 12px 下限 | 通过 | 源扫描 sub-12px 声明 12 → 0：`shared.css` 的 `.sect` `.chip` `.counts` `.rel` `.note`，`thread.html` 的头像首字母与引用作者行，`notifications.html` 的时间，`reader/index.html` 四处。渲染 small：桌面 6 页 × 亮暗 110 → 0，reader 样例 16 → 0。列表行标题行高 1.35 → 1.4。无记录例外。 |
| R3 减弱动效与可见焦点 | 通过 | `shared.css` 新增全局 `prefers-reduced-motion` 块与 `:focus-visible`（2px `--accent`，offset 2px）；`.mobile` 既有的同名规则特异性更高，行为不变。`reader/index.html` 同步两项，演示用的跳底按钮在 reduced motion 下改为瞬时滚动。 |
| R4 原型完整性 | 通过 | `design/index.html` 是本地评审用导航页（按 `<title>` 列出 13 个原型页，含 Mobile 分组，链接本文件），按 2026-11-26 的原型流程不提交；六个移动页的 `../index.html` 返回链接指向它，克隆后由 agent 本地生成。零远程资源。 |
| R5 可访问名称 | 通过 | 桌面页装饰性内联 SVG 全部 `aria-hidden="true"`；thread 点赞钮加 `aria-label`（Like / Unlike this post）。渲染 nameless 0 → 0。 |
| R6 布局缺陷 | 通过 | 1280×800：browse 侧栏分类名较长的三行，未读 pill 与时间被侧栏边缘裁掉 → meta 放不下时换行、尾组靠右；signin 状态栏提示比右侧注记低 6px → 对齐。最小窗口宽 920（`RivetHostApp.swift` 的 `minWidth`）：原型窗口不收缩、横向溢出 236px、主题钮落到视口外 → 窗口可收缩，溢出 0；thread 工具栏 "Open on the forum" 折成两行 → 不折行、标题省略；signin 状态栏注记折行 → 注记单行、提示自行换行。 |
| R7 契约同步 | 通过 | 本节；token 表无数值变化。字体角色一行里的 caption2 在原型里已无对应文字（计数、时间戳、分类 chip、未读 pill 与 caption 同为 12px），宿主实现仍用 `.caption2`，见遗留。 |
| R8 仓库门禁 | 不适用 | 仓内没有读取 `design/` 的 workflow、脚本或测试（`.github/workflows`、`scripts/`、`tests/` 均不引用）。 |

**渲染证据（无头 Chromium，2026-11-26）**：桌面 6 页 × 亮暗 1280×800、移动 6 页 × 亮暗 390×844、导航页与 reader 样例各 × 亮暗：`small` 0、`overflowX` 0、`nameless` 0、页面错误与加载失败 0；`low`（4.5:1 以下文字对，近似值）与改动前逐页相同（browse 12 / 14、thread 9 / 9，其余 1–2），移动与导航页 0。reader 样例深色下的 `low` 读数是工具按白色背景估算的假象（实际画布 #121212）。2026-11-22 自查里「未验证：真实浏览器」的布局溢出一项，移动六页至此有了渲染证据；焦点环的像素、原生 dialog 焦点、读屏、200% 文字放大与真机仍未验证（该渲染器对 `:focus-visible` 统一报告 3px currentColor，规则在 CSSOM 中命中聚焦控件，2px accent 未能取证）。

**遗留（需产品决策，未改）**：深色下强调色文字与论坛色分类 chip 的对比（主按钮 3.23:1、Sign in / Sign out 3.75:1、Racket chip 2.77:1；契约钉死 accent 不随外观提亮、chip 用论坛自己的颜色）；thread 点赞钮仍用字体字形 ♡ / ♥（三宿主 reader 模板同款）；阅读器内点赞与 Load more 按钮高约 19–22px、更新横幅按钮 24px，低于 28px（属 reader 契约与宿主实现）。
