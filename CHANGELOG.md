# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.2] - Unreleased

### Fixed
- **总计页总成本未计入 MiniMax / Xiaomi MiMo 订阅费用**：`TotalView.combinedCost` 此前只计算 OpenCode + Codex 两个 provider，现已纳入全部四个 provider 的已订阅方案费用 (`TotalView.swift`)
- **总计页 OpenCode 计价卡片 subtitle 在 API 模式下误显订阅价格**：`overviewSettingsCard` 的 OpenCode 小卡片 subtitle 此前始终显示 `resolvedOpenCodePlan.priceDescription`（如 $10/月），现根据 `openCodePricingMode` 动态切换：API 模式显示「按量计费」，订阅模式显示方案价格
- **Codex 总览卡片的 subtitle 依赖 Codex 数据源存在**：`codexOverviewCost` 此前 guard `codexSummary != nil`，导致无 Codex 数据时 `combinedCost` 整体为 nil。现已移除该依赖，Codex 订阅费用独立于数据源

### Added
- **未订阅选项**：设置页四个 Provider 计费卡片新增「订阅该方案」Toggle 开关。关闭后该 Provider 不会计入总成本（`monthlyUSD = nil`），灵活应对实际未订阅的场景
- **`BillingPlanSelection.isSubscribed` 字段**：向前兼容旧 JSON（缺少 key 时默认 true，保持旧用户行为不变）
- 新增本地化 key：`overview.plan.apiCost`、`overview.summary.totalCostAllSubscribedSubtitle`、`settings.billing.subscribed`、`settings.billing.notSubscribed`、`settings.billing.notSubscribedDescription`（中英双语）

### Changed
- `BillingPlanSelection` 从编译器合成 `Codable` 改为手动实现，以支持 `isSubscribed` 字段的向前兼容解码
- `ResolvedBillingPlan` 新增 `isSubscribed: Bool` 字段

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

[v0.1.2]: https://github.com/blackkcold/Token-Cost-App-OC-Codex/compare/v0.1.1...v0.1.2
[v0.1.1]: https://github.com/blackkcold/Token-Cost-App-OC-Codex/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/blackkcold/Token-Cost-App-OC-Codex/releases/tag/v0.1.0
