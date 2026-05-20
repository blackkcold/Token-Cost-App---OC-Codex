# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.5.1] - 2026-05-20

> 当前下一版目标为 `v0.5.1`，以下为相对 `v0.5.0` 的累计变更。

### Added
- **浏览器凭证自动导入**：从 Edge / Chrome / Brave / Arc 自动提取 opencode.ai 的 Cookie 和 Workspace ID，通过 Keychain + PBKDF2 + AES-128-CBC 本地解密后存入钥匙串（`BrowserCookieExtractor.swift`、`CommonCryptoBridge.c`、`SecureCredentialStore.swift`、`SettingsView.swift`）
- **OpenCode Go 设置页测试连接按钮**：独立校验凭证配置，不触发全量刷新和 backoff（`SettingsView.swift`、`BalanceManager.swift`）

### Changed
- **菜单栏刷新按钮合并**：将菜单栏中三个独立按钮合并为一个「刷新全部」按钮，快捷键简化为单一 `Cmd+R`（`MenuBarView.swift`、`TokenCostCommands.swift`）
- **菜单栏余额区域增加刷新按钮**：在余额摘要底部增加「刷新余额」按钮（`MenuBarView.swift`）
- **模型分布与 Provider 分布饼图卡片等高**：替换为 `HStack` + `PreferenceKey` 方案（`DetailView.swift`）
- **版本更新检查交互重构**：保留启动自动静默检查（24h 缓存），新增工具栏「检查更新」手动按钮（即时调 API 忽略缓存）；有更新时显示「更新」/「稍后」双按钮替代原直接下载；无更新时显示「已是最新版本 vX.Y.Z」3 秒自动消失；新增 `manualCheck()`、`dismissUpdate()` 方法，`checkForUpdate()` 改为静默模式（`UpdateCheckerModel.swift`、`ContentView.swift`、`Localizable.strings`）

### Fixed
- **OpenCode Zen 费用 Go 模型成本扣减不完全**：增强模型名称匹配（`OpenCodeGoBalanceProvider.swift`）
- **OpenCode Go 凭证链路修复**：`workspaceID` 保存时同步写入 Keychain（`AppPreferencesModel.swift`、`SecureCredentialStore.swift`）
- **OpenCode Go 仪表盘 HTML 解析修复**：从 Next.js 格式迁移到 SolidJS SSR hydration，三轮窗口各两组正则并改为容错模式（`OpenCodeGoDashboardFetcher.swift`）
- **Dashboard 解析失败分层错误提示**：区分「格式变更」vs「cookie/workspace 不匹配或未订阅」，并增加 DEBUG HTML dump（`OpenCodeGoDashboardFetcher.swift`）
- **浏览器导入交叉合并修复**：当浏览器只找到 cookie 而 workspaceID 已在 Keychain（或反之）时，不再丢弃部分凭据，改为自动拼合完整凭证（`SecureCredentialStore.swift`、`SettingsView.swift`）

## [v0.5.0] - 2026-05-19

### Fixed
- **总计页总成本未计入 MiniMax / Xiaomi MiMo 订阅费用**：`TotalView.combinedCost` 此前只计算 OpenCode + Codex 两个 provider，现已纳入全部四个 provider 的已订阅方案费用 (`TotalView.swift`)
- **总计页 OpenCode 计价卡片 subtitle 在 API 模式下误显订阅价格**：`overviewSettingsCard` 的 OpenCode 小卡片 subtitle 此前始终显示 `resolvedOpenCodePlan.priceDescription`（如 $10/月），现根据 `openCodePricingMode` 动态切换：API 模式显示「按量计费」，订阅模式显示方案价格
- **Codex 总览卡片的 subtitle 依赖 Codex 数据源存在**：`codexOverviewCost` 此前 guard `codexSummary != nil`，导致无 Codex 数据时 `combinedCost` 整体为 nil。现已移除该依赖，Codex 订阅费用独立于数据源
- **定价文档弹窗表格分隔符被错误渲染为数据行**：`PricingDocView.buildTable()` 未过滤 markdown 表格的 `|---|---|` 分隔符行，导致分隔符行作为数据行渲染。现已增加过滤逻辑，跳过仅由 `-`/`:`/空格组成的行（`PricingDocView.swift`）
- **总计页指标卡片布局未对齐/溢出**：三个卡片区（总计/OpenCode/Codex）的 `LazyVGrid` 使用 `.adaptive(minimum:)` 导致宽窗口时超过 4 列，且副标题较长的卡片高度不一致。现已改为固定 4 列 `GridItem(.flexible())` + 每个 `TokenMetricCard` 统一 `maxHeight: .infinity` 对齐（`TotalView.swift`）
- **OpenCode 详情页来源修改时间显示 UTC 而非本地时间**：`SourceDiscoveryService.modificationDate(for:)` 使用 `ISO8601DateFormatter().string(from:)` 输出 UTC 时间字符串，UI 层直接显示未做本地时区转换。现新增 `TokenCostFormatters.localDateTime(_:)` 方法，解析 ISO 8601 字符串后以 `DateFormatter`（不设 `timeZone`，自动跟随系统时区）格式化为本地时间显示（`Components.swift`、`DetailView.swift`）
- **OpenCode 详情页第一行来源卡片高度不对齐**：`sourceHeader` 中 `LazyVGrid` 使用 `.adaptive(minimum: 220)` 导致来源路径卡片因长文本换行而高于同行其他卡片。现改为固定 3 列 `GridItem(.flexible())` 等宽 + 每张卡片 `.frame(maxHeight: .infinity, alignment: .topLeading)` 统一行高（`DetailView.swift`）

### Added
- **未订阅选项**：设置页四个 Provider 计费卡片新增「订阅该方案」Toggle 开关。关闭后该 Provider 不会计入总成本（`monthlyUSD = nil`），灵活应对实际未订阅的场景
- **`BillingPlanSelection.isSubscribed` 字段**：向前兼容旧 JSON（缺少 key 时默认 true，保持旧用户行为不变）
- **全局工具栏刷新按钮**：从原有 OpenCode 页 toolbar 重新扫描按钮扩展为全局刷新。总计页→「刷新全部」（同时重扫 OpenCode + 刷新 Codex），OpenCode 页→「重新扫描」，Codex 页→「刷新 Codex」；`SidebarView` 原有本地 toolbar 已移除（`ContentView.swift`、`SidebarView.swift`）
- **刷新进度条**：当 OpenCode 或 Codex 处于扫描/刷新状态时，TabView 上方显示线性进度指示器，参考 Apple HIG 定位在内容区顶部（`ContentView.swift`）
- 新增本地化 key：`tab.action.refreshAll`（中英双语）、`overview.plan.apiCost`、`overview.summary.totalCostAllSubscribedSubtitle`、`settings.billing.subscribed`、`settings.billing.notSubscribed`、`settings.billing.notSubscribedDescription`（中英双语）
- **余额实时监控**：新增 `BalanceManager` 协调器和三个 Provider 余额查询器（OpenCode Go / Codex / OpenCode Zen）。从本地 `auth.json` 安全读取 API key，通过 HTTPS 调用各 Provider 官方 API 获取实时余额/credit/用量百分比。余额快照仅驻留内存，不持久化到磁盘。仪表盘、各详情页、菜单栏均展示余额梯度色条和百分比。设置页可开关余额监控并调整刷新间隔（默认关闭，保持纯本地承诺）
- **余额可视化卡片**：`BalanceOverviewCard` 可折叠组件，按梯度色条（灰/绿/黄/橙/红）展示使用百分比；不可用 Provider 单独显示状态和原因
- **菜单栏余额摘要**：余额开启后在菜单栏显示各 Provider 使用百分比和梯度标签，一目了然
- **版本更新检查**：启动时每天一次自动检查 GitHub Release 最新版本；工具栏以胶囊标签显示「更新」，点击自动下载并以标签背景左→右渐进填充可视化进度；下载后校验文件完整性，点击「安装」打开新版本 .app。涉及文件：`UpdateChecker.swift`、`UpdateCheckerModel.swift`、`ContentView.swift`、`TokenCostApp.swift`、本地化 `Localizable.strings`（中英双语）

### Changed
- `BillingPlanSelection` 从编译器合成 `Codable` 改为手动实现，以支持 `isSubscribed` 字段的向前兼容解码
- `ResolvedBillingPlan` 新增 `isSubscribed: Bool` 字段
- **定价文档弹窗重写**：`PricingDocView` 从单次 `AttributedString(markdown:)` 渲染改为分段解析，自定义标题、引用块、表格布局。表格使用原生 `HStack`+`Divider` 渲染，解决 markdown 表格文字堆叠问题。弹窗添加图标、调整最小尺寸（`PricingDocView.swift`）
- `AppPreferences` 新增 `balanceEnabled`、`balanceRefreshMinutes` 和 `opencodeGoWorkspaceID` 字段（向后兼容）
- `AppPreferencesModel` 新增对应双向绑定
- 全局传参链扩展：`TokenCostApp` → `ContentView` → `TotalView` / `OpenCodePageView` / `CodexPageView` / `SettingsView` / `MenuBarView` 均新增 `balanceManager` 参数
- `BalanceManager` 为 `@MainActor class: ObservableObject`，通过 `@Published` 广播状态
- **OpenCode Go 从 API 模式迁移到 Dashboard 配额模式**：通过 `GET /zen/go/v1/models` 验证 API key，通过 `GET /workspace/{id}/go` 解析 HTML 获取 5小时/每周/每月三个额度窗口
- **OpenCode Go 凭证安全存储**：`SecureCredentialStore` 使用 macOS Keychain (`Security.framework`) 加密存储 authCookie；workspaceID 明文保存于 `AppPreferences`；支持环境变量和 opencode-bar 配置文件自动导入
- **OpenCode Zen 费用去重**：总费用减去 Go 模型成本
- **菜单栏余额条形图**：用紧凑进度条替代纯文字显示
- `BalanceSnapshot` 新增 `tertiaryWindow*` 三字段支持 Go 每月窗口
- SECURITY.md 新增 Keychain 安全声明
- **Release 目录重组**：`dist/` → `release/`，对齐 news-bar 项目结构。新增 `release/latest/`（始终指向最新构建）、`release/versions.json`（结构化版本元数据）、`release/release-notes/`（集中管理）。RELEASE_NOTES 从项目根迁入 `release/release-notes/`。更新 `.gitignore` 规则、CI/CD 脚本路径、开发手册和 README

## [v0.1.1] - 2026-05-18

### Added
- `.github/workflows/ci.yml` — push/PR 时自动 `swift build` 验证编译
- `.github/workflows/release.yml` — tag 推送时自动构建 `.app` 并创建 GitHub Release
- `.github/copilot-instructions.md` — AI agent 项目速查指令
- `.github/CODEOWNERS` — 代码评审归属
- `.gitignore` — 忽略构建缓存和系统文件
- `LICENSE` — MIT License
- `SECURITY.md` — 安全漏洞上报指引
- `docs/架构逻辑链图.md` — 系统架构 Mermaid 图
- `docs/开发手册.md` — 开发指南和发布流程
- `Resources/zh-Hans.lproj/Localizable.strings` / `Resources/en.lproj/Localizable.strings` — app 级中英双语文案
- `Sources/CodexTokenCostCore/AppPreferences.swift` / `Sources/CodexTokenCostApp/Stores/AppPreferencesModel.swift` — 语言与总览计价偏好
- `Sources/CodexTokenCostCore/BillingPlanCatalog.swift` — Provider 订阅 / Token Plan 档位目录，覆盖 OpenCode Go / Zen、ChatGPT Plus / Pro / Business Codex、MiniMax Token Plan、Xiaomi MiMo Token Plan，并支持自定义 USD 月费
- `Sources/CodexTokenCostApp/Views/PricingDocView.swift` / `Sources/CodexTokenCostApp/Resources/Pricing.md` — App 内置只读计费参考文档查看器
- `Tests/` 目录 — 预留测试目录

### Changed
- **项目目录重组**: `Package.swift`、`Sources/`、`Resources/` 从 `app/` 移至项目根，符合 SPM 标准
- `dist/` 从 `app/` 移至项目根，发布产物与源码分离
- `script/build_and_run_codex.sh` 路径引用更新（`APP_PACKAGE_DIR` → 根目录）
- 构建脚本移除自定义环境变量（`HOME`, `XDG_CACHE_HOME`, `CLANG_MODULE_CACHE_PATH`），使用系统默认
- 发布产物按版本号管理（`dist/releases/v0.1.0/`）
- 总览页新增独立 OpenCode 计价选择，仅影响总览成本对照，不改 OpenCode / Codex 独立页的 token 统计
- 设置页新增「计费方案」管理区：每个 provider 可选择官方预设档位或 DIY 自定义 USD/月费；按量计费与 contact-sales 档位可作为说明项，必要时通过自定义月费纳入总成本
- OpenCode 详情页的 Provider 成本分析支持从 AppPreferences 注入计费覆盖；未配置时继续回退到现有默认费用，保持 v0.1.1 旧口径兼容
- 主窗口、设置页、菜单、状态提示与详情页文案已接入本地化层，支持中文 / 英语切换

### Removed
- 废弃的 `app/` 目录及构建缓存（`.build-codex/`, `.spm-*`, `.module-cache-*` 等）
- 旧的构建脚本冗余配置

### Fixed
- Codex 页面中英文本地化补全：修正仍残留的标题、表头、排序文案与 tooltip
- **修复 actual token 重复扣减缓存 bug**：原公式 `actualTokens = max(input - cacheRead - cacheWrite, 0)` 在 OpenCode SQLite 数据中 `$.tokens.input` 已是非缓存值的情况下造成二次扣减，导致 totalActualTokens 趋近于零、缓存命中率虚高至 99.9%、Provider 性价比排行和 Model 价格对比全部错误。修正为 `actualTokens = input + output + reasoning`，与 OpenCode 源码 `getUsage()` 的 token 存储逻辑一致。受影响文件：`DashboardAnalytics.swift`（2处）、`TokenDatabaseClient.swift`（1处）、`Models.swift`（1处）
- 计费偏好兼容迁移：旧版 `app-preferences.json` 缺少计费选择时自动回退默认档位；若曾保存旧形态自定义费用，会迁移为新的 `BillingPlanSelection`
- **修复 totalActualInputTokens 仍用旧公式遗漏**：`DashboardPayload.totalActualInputTokens`（Models.swift:361）此前仍执行 `max(input - cacheRead - cacheWrite, 0)`，在 OpenCode SQLite 中 `input` 已非缓存的语义下造成 cache 二次扣减，直接影响 TotalView 的 OpenCode 实际输入 token 和总实际输入 token 展示。修正为直接求和 `row.input`。

## [0.1.0] - 2026-05-13

### Added
- OpenCode SQLite 数据库 token 用量可视化
  - 自动扫描系统目录发现数据库
  - 支持手动添加目录和数据库文件
  - JSON extract 聚合查询
- Codex JSONL session 文件聚合统计
  - Session 级 token usage 解析
  - 每日 token 趋势图
  - Session 列表（分页+排序+Tooltip）
- 双源总计面板（TotalView）
- 四种主题色（海湾蓝、森林绿、暮光橙、极光紫）
- 缓存分析卡片和 Provider 性价比排行
- 模型价格对比（API 定价 + 订阅成本）
- 数据分布饼图（模型分布 / Provider 分布）
- 每日模型堆叠图
- 详细数据表（50 条窗口，分页排序）
- 设置面板（OpenCode + Codex 独立配置）
- 快照保存与自动轮转（可配置保留数量）
- Helper 子进程架构（CodexTokenCostHelper）
- 构建/运行/调试脚本 `build_and_run_codex.sh`
- 安全只读设计 + SafeFileStore 沙箱文件读写

[v0.5.0]: https://github.com/blackkcold/Token-Cost-App-OC-Codex/compare/v0.1.1...v0.5.0
[v0.1.1]: https://github.com/blackkcold/Token-Cost-App-OC-Codex/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/blackkcold/Token-Cost-App-OC-Codex/releases/tag/v0.1.0
