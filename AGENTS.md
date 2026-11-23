# AGENTS.md

## 家族设计（必读入口）

- 设计/UI 任务先加载 `tlai-product`，必读 `references/policy.md` 与 `references/design-standard.md`（理念、决策规则、UI 验收）。技能缺失时读取 ZCode 真源：macOS/Linux `~/Sync/ZCode/skills/tlai-product/`；Windows `D:/ZCode/skills/tlai-product/`。无法读取须报告规范未核验，不凭记忆跳过。
- 家族规范管共性；本仓现有设计、行为与 token 真源管具体值和产品差异。例外记回原契约，不复制家族规则或新增数值表；已有界面按下一次相关切片渐进对齐。
- 改界面先改原型、落账后实现；按家族 UI 清单与本仓当前技术线的既有门禁验收，原型对照和真实交互证据都要保留；对外宣传使用验收后的实物截图。

## 实现路由（agent 按任务读真源）

- 实现界面以 `design/prototype/` 为准：对照 HTML/CSS/JS 与实物截图验收，不依赖散文复述。
- Token/几何值真源 = `design/prototype/shared.css`（亮暗成对；无 shared.css 的仓 = design/prototype/ 各页样式）；`design/DESIGN.md` 只记语义名、用途与决策。
- 行为边界与跨平台一致性以 `design/DESIGN.md` 的不变式与平台差异节为准。
- 改界面先改原型再改实现（tlai-product）；动共享层（design/、shared/）先 issue 声明，同 commit 落契约。

## Current owner decision — 2026-11-18 quality-first

This product is in **non-commercial development**. The prior 2026-10/11 product pricing, trial, paid-feature, Free/Pro and family Permit/Commerce rollout decisions are canceled. Do not introduce checkout, subscriptions, activation, commercial entitlement, paid update windows or a paywall. Do not change source-license terms or release signing and identity verification. Prioritize product correctness, reliable native experience, recovery, bilingual README and truthful website claims. The [current family portfolio](https://github.com/turlamai/turlamai.github.io/blob/master/PORTFOLIO.md) governs every slice.

指引给 AI agent(及开发者):如何理解、构建、改动 Threadly。

## 这是什么

Threadly 是 Racket 社区论坛(racket.discourse.group,Discourse 架构)的
原生客户端:浏览最新主题、读长帖、全文搜索。论坛是 Racket 语言设计讨论
与生态动态的主场,Threadly 给它一个配得上内容质量的阅读器。**全平台
产品,与 Taskly 同标:桌面三平台(macOS/Windows/Linux)为当前维护范围；移动端
iOS/iPadOS/Android 为 M4 roadmap（平台原生语言），桌面换线后继续开发，不是当前交付承诺。**技术形态遵循
[Rivet](https://github.com/turlamai/rivet) 线:**Racket 引擎 +
各平台第一方原生 UI**。产品灵魂是**阅读体验**——壳的每一像素都要按这个
标准做(对标线见 fulcrum 的 Raycast 对标)。

| 层 | 技术 | 目录 | 状态 |
|---|---|---|---|
| 引擎(Discourse API/缓存) | Racket 9.3 | `racket/` | ✅ fixture 测试全绿 |
| CLI | Racket | `racket/cli.rkt` | ✅ latest/topic/search/categories/doctor |
| macOS 壳 | SwiftUI | `macos-host/` | ✅ 首片 |
| Windows/Linux 壳 | WinUI 3 / GTK4+WebKitGTK | `windows/` `linux/` | ✅ M1(CI 编译门+launch smoke) |
| Android 壳 | Kotlin（平台原生；Jetpack Compose 等按实现立项） | (待建) | M4 |
| iOS/iPadOS 壳 | SwiftUI（平台原生） | (待建) | M4 |
| watchOS 伴机 | SwiftUI + WatchConnectivity（平台原生，表端不嵌引擎） | (待建) | M4 尾段:依赖 iOS 宿主与 M2 登录态,通知伴机形态 |

移动端执行 owner 2026-11-23 确认：各平台原生语言（iOS/iPadOS Swift、Android Kotlin），不复用 rivet 移动宿主，也不把 glaze 载体延伸到移动端；这是持续 roadmap（M4，换线后继续开发），不是暂缓或取消。与引擎的数据边界随实现立项另定。

## 硬边界(本仓库存在的合法性根基,任何改动不得越过)

1. **只读优先,凭据零入库**:匿名浏览使用公开 JSON API；登录写操作
   使用已实现的 Discourse user API key 流,任何 token/cookie/密码不得
   写进仓库或进序列化日志。
2. **做好公民**:只打公开端点;所有响应走磁盘缓存(默认 TTL 300s);
   请求带身份标识 UA;429 必须如实上抛退避,禁止批量爬取(翻页有上限)。
3. **论坛是唯一事实源**:本地只缓存不 fork;编辑/删除/挪版以论坛为准;
   保留作者与原链,不做误导内容归属的转换。
4. **内容礼貌**:引擎不得绕过 Discourse 的 rate limit,不得解析登录墙
   后的内容。

## 架构速览

| 模块 | 文件 | 说明 |
|---|---|---|
| HTTP | `racket/core/http.rkt` | net/http-client 之上;手动跟重定向(≤5 跳,每跳保留 UA) |
| Discourse API | `racket/core/discourse.rkt` | fetch×4 + parse×4;parse 是纯函数,fixture 驱动测试,CI 无网络 |
| 缓存 | `racket/core/cache.rkt` | JSON 文件缓存 + TTL,键=URL sha1;断网时过期缓存仍可用(标注 cached) |
| 路径 | `racket/core/paths.rkt` | `$THREADLY_DATA_DIR` 覆盖 > 平台缓存目录;测试用 `current-data-dir` 参数注入 |
| RVT1 面 | `racket/backend.rkt` | 壳的唯一接口;行=定位字符串(Fulcrum 风格),布局见文件头注释 |
| CLI | `racket/cli.rkt` | version/latest/topic/search/categories/doctor;doctor 离线 |

## 快速命令

```bash
raco test tests/                 # 必须全绿
racket racket/cli.rkt latest        # 冒烟(需网络;CI 冒烟只用 version/doctor)
racket racket/cli.rkt doctor
raco rivet build                 # 生成 GeneratedBackend.swift + 构建壳
raco rivet schema check rivet-schema.json --json
                                 # RPC 兼容性基线,改 backend 的 RVT1 面后
                                 # 用 raco rivet schema --output 重新生成入库
```

Rivet 工作约定:开发前 pull `~/Codes/rivet`,pull 后清 `compiled/` 再
`raco setup`;生成 GeneratedBackend.swift 前核对 rivet pin;发布构建切
pin、开发跟最新。图标改版走 `scripts/make-icons.py`,禁止手改生成物。

## 版本与发布

- **发版以 taskly v0.1.2 实际资产为家族标杆**,已有平台范围逐项对齐:
  macOS arm64/x64 各 dmg+zip(更新载荷)且每件带 `.sha256` sidecar,汇总
  `SHA256SUMS`,加单一签名 feed `update-manifest.json`;Windows/Linux
  宿主落地后按标杆补 msi+zip 与 deb+rpm+AppImage+tar.gz+zip 全矩阵。
- 发版前必实测产物(下载 dmg/安装、启动、读帖)。
- VERSION == rivet.rktd version == racket/version.rkt,由
  `scripts/check-release-version.sh` 三方校验,CI 跑。
- CHANGELOG 是 Keep-a-Changelog 风格;发版前 `## x.y.z` 段必须先写,
  release 由此产 validate 门拦截。
- 新产品走 0.x 纪元,首发 0.1.0。
- 更新签名:Ed25519,`RIVET_UPDATE_KEY_ID=threadly-2026-10`;私钥三处
  就位(Sync/Keys `secrets.ini` [threadly] 节 + GitHub Secret
  `UPDATE_ED25519_PRIVATE_KEY` PEM 形态;散件即到即收立删)。轮换规则见
  Sync/Keys/AGENTS.md。
- 产品主页 `site/` → threadly.jrtx.site(Pages workflow 部署,Pages 已
  启用 workflow 构建型;DNS CNAME 记录由用户添加)。产品站采用家族静态
  站点约定:双语 i18n 默认中文、共享暖色变量+完整暗色主题、零依赖、系统
  字体栈(家族规范:禁 Google Fonts)。

## 坑(已踩过)

- **Racket read-json 把 JSON null 解析成 'null 符号**,而 `hash-ref` 的
  默认值只在键缺失时生效——可选字段(如 last_posted_at)必须过
  `json-clean`('null→#f),否则 'null 混进 RPC 行直接炸
  `(List (List String))` 契约;本地 fixture 不含 null 行时不暴露,
  真机分类页才炸。
- **壳的观察断链**:`@EnvironmentObject model` + `model.store.*` 时,store
  的 `@Published` 变化不触发视图重渲染(PodLens 同款隐患)。必须
  `.environmentObject(model.store)` 单独注入,视图直接声明
  `@EnvironmentObject store`。
- **`raco rivet build` 缓存(上游 #129 同款)**:改 Swift 后
  `raco rivet package` 可能不重编壳、打包出旧二进制。验收/发版前先
  `raco rivet clean` 再 package;拿 `strings` 核对新符号真在二进制里。
- **WKWebView 亮暗跟随**:prefers-color-scheme 读的是
  `NSApp.effectiveAppearance`,`preferredColorScheme` 在 macOS 不可靠;
  亮暗双验证用 `THREADLY_APPEARANCE=dark|light` 环境变量(勿改用户全局
  系统外观)。
- **GUI 自动化**:cliclick 点击前必须先 AXRaise + frontmost,否则点到
  前台窗口;截被遮挡窗口用 `screencapture -l <CGWindowID>`
  (CGWindowListCopyWindowInfo 查 id)。
- **WinUI 3 的 WebView2 控件在 Windows App SDK 里**
  (`Microsoft.UI.Xaml.Controls.WebView2`,XAML 默认命名空间直接写
  `<WebView2>`);`Microsoft.Web.WebView2` NuGet 只提供 CoreWebView2 与
  loader,没有 XAML 控件也没有 winrt 投影头——pch 不要 include 它。
  控件用代码创建并 try/catch:缺 loader/运行时只降级阅读器,不能炸壳。
- **GTK4 的 WebKitGTK 是 `webkitgtk-6.0`**(pkg-config 名、apt 包
  `libwebkitgtk-6.0-dev`);`webkit2gtk-4.1` 是 GTK3+libsoup3,别碰。
  伞头文件是小写 `#include <webkit/webkit.h>`。
- **Linux CI 的 embed Racket**(setup-embed-racket 产出的 minimal)不带
  `raco make`(compiler-lib)和 `raco ctool`(cext-lib),`raco rivet
  build` 前要 `raco pkg install --auto --no-docs compiler-lib cext-lib`;
  Linux CMake 经 `add_subdirectory` + `rivet::platform` 消费 Rivet 平台
  库(rivet#238),仓里不再手抄 Rivet 源清单;WebKitGTK 由宿主自己链
  (`webkitgtk-6.0` PkgConfig::WEBKIT)。
- **本机 git 突然报 Xcode license**(Xcode/CLT 后台升级后 `/usr/bin/git`
  被挡,exit 69):临时用
  `/Applications/Xcode.racket/Contents/Developer/usr/bin/git`,根治需要用户
  跑 `sudo xcodebuild -license accept`(agent 无 sudo)。

## 组合定位（Portfolio placement）

2026-11-18 起，以产品交付质量为目标，不推进收费版、试用、商业授权或结账。既有 LICENSE 和发行签名验证保持不变。当前权威是[产品组合策略](https://github.com/turlamai/turlamai.github.io/blob/master/PORTFOLIO.zh-CN.md)。

## 产品交付与下一步（2026-11-18）

请以当前代码与验收证据推进用户主流程、恢复、跨平台原生体验、签名更新、文档和产品主页，不按任何历史商业规划开发。

## 交互契约与验证状态（issue #1/#2，2026-10-25 切片）

导航身份与恢复的契约（三宿主同语义，不等像素）：读线程的加载、帖子、
总数、错误与回复目标一律绑定捕获的主题身份；被取代的加载完成即丢弃。
切换主题时旧帖不留屏（新标题 + spinner），失败时读者视图给
Retry / Back to list；重试原位进行，侧栏选择与列表位置不动；每主题
回复草稿在失败加载、关闭撰写器、切换主题后保留，帖子发出后才清除。
退出登录、回到列表会作废在途的线程加载；"load all" 尾段同样绑定身份。
引擎侧 429 上抛不重试、断网回落带缓存、密钥不出现在任何错误/日志/反馈
（`tests/auth-test.rkt` 有输出侧回归测试）。

| 验证项 | macOS | Windows | Linux |
|---|---|---|---|
| 延迟响应 fixture（慢 A 快 B / 迟到 A 错误 / 离线重试 / 作废 / 草稿 / load-all 身份） | ✅ `swift test`（7 例，红绿验证：去守卫即复现 issue #2 描述的三种失败） | ❌ 未运行（CI 仅编译门） | ❌ 未运行（CI 仅 headless 启动冒烟） |
| 构建/启动 | ✅ `raco rivet build` + 新 UI 字符串进二进制 + CI launch smoke | ✅ CI 编译门 | ✅ CI 编译门 + headless boot |
| 打包产物实机验收（安装后读/搜/登录失败/退出/更新） | ❌ 未做（留给发布门禁） | ❌ 未做 | ❌ 未做 |

fixture 位于 `macos-host/Tests/RivetHostTests/`（脚本化 RivetAPI 传输，
无网络无后端）；CI 在 macOS job 构建后跑 `swift test`。Windows/Linux
的等价 fixture 未建（宿主测试基建不存在），其竞态修复与 macOS 同模式
（请求 id / open generation 校验），当前以编译门 + 代码同构性背书——
这是明确的未验证项，不是等价声明。

## Documentation languages

Public default documentation is English; maintain complete Chinese user paths in `*.zh-CN.md`, with reciprocal links. Update both languages when prices, quotas, installation, recovery, privacy or supported platforms change. API/protocol identifiers and commands remain unchanged; do not maintain a second normative protocol or implementation. Follow the [family language policy](https://github.com/turlamai/turlamai.github.io/blob/master/docs/DOCUMENTATION-LANGUAGES.md). Existing internal notes are not a claim that every document is bilingual.

## Public product documentation

The paired `docs/USER-GUIDE.md` / `docs/USER-GUIDE.zh-CN.md` own the public installation, first-use, data/recovery, privacy and availability path. Keep the homepage and both README entry points aligned with them when behavior changes. Detailed technical contracts and the current implementation queue retain their existing owners. Do not publish target prices, a purchase link or a ready/secure/platform claim before its release evidence exists.
