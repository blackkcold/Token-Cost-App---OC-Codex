# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- `Tests/` 目录 — 预留测试目录

### Changed
- **项目目录重组**: `Package.swift`、`Sources/`、`Resources/` 从 `app/` 移至项目根，符合 SPM 标准
- `dist/` 从 `app/` 移至项目根，发布产物与源码分离
- `script/build_and_run_codex.sh` 路径引用更新（`APP_PACKAGE_DIR` → 根目录）
- 构建脚本移除自定义环境变量（`HOME`, `XDG_CACHE_HOME`, `CLANG_MODULE_CACHE_PATH`），使用系统默认
- 发布产物按版本号管理（`dist/releases/v0.1.0/`）

### Removed
- 废弃的 `app/` 目录及构建缓存（`.build-codex/`, `.spm-*`, `.module-cache-*` 等）
- 旧的构建脚本冗余配置

## [0.1.1] - 2026-05-15

### Fixed
- OpenCode 和 Codex 的最新会话窗口统一扩展到最近 100 条，修正堆叠图与最近明细的分页截断
- Codex 总览改为展示实际 Input 口径，并同步到总览页，避免缓存输入与实际输入混淆
- 统一会话明细标题为 `最新会话明细`，并修正 Codex 总览与缓存分析的默认一行布局
- Codex 趋势 hover 提示收敛为更紧凑的聚合信息

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

[unreleased]: https://github.com/blackkcold/Codex-Token-Cost-App/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/blackkcold/Codex-Token-Cost-App/releases/tag/v0.1.1
[0.1.0]: https://github.com/blackkcold/Codex-Token-Cost-App/releases/tag/v0.1.0
