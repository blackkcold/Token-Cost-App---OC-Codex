# Token Cost App - OC Codex — 项目速查

## 仓库结构
- `Package.swift` — SPM 清单，三个 target: `CodexTokenCostCore`, `CodexTokenCostApp`, `CodexTokenCostHelper`
- `Sources/CodexTokenCostCore/` — 核心模块：数据模型、SQLite 客户端、来源发现、设置持久化、分析引擎
- `Sources/CodexTokenCostApp/` — 主应用：SwiftUI 视图、Store、App 入口
- `Sources/CodexTokenCostHelper/` — 辅助进程：CLI 采集 Codex session JSONL
- `script/build_and_run_codex.sh` — 本地构建/运行/调试脚本
- `docs/` — 架构图和开发手册

## 构建命令
```bash
swift build            # Debug 构建
swift build -c release # Release 构建
bash script/build_and_run_codex.sh run   # 构建并运行
```

## 编码约定
- 所有公开 API 使用 `public` 修饰符，内部实现使用 `private`
- 数据模型遵循 `Codable, Hashable, Identifiable, Sendable`
- UI 组件使用 `TokenCostPalette` 统一主题色，不硬编码颜色
- 文件操作统一经过 `SafeFileStore` 进行沙箱内读写
- 来源扫描通过 `SourceDiscoveryService` 集中管理

## 关键入口
- App 入口：`Sources/CodexTokenCostApp/App/TokenCostApp.swift` — `@main`
- Helper 入口：`Sources/CodexTokenCostHelper/main.swift`
- 数据模型：`Sources/CodexTokenCostCore/Models.swift`
- 分析引擎：`Sources/CodexTokenCostCore/DashboardAnalytics.swift`
