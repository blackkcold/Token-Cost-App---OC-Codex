# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

> 当前下一版目标为 `v0.1.1`，尚未正式发版。

### Fixed
- Codex 实际 token 口径统一：summary、trend 和 session row 现在都按净 input 计算，避免 cached input 非零时总览与明细不一致

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

[unreleased]: https://github.com/blackkcold/Codex-Token-Cost-App/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/blackkcold/Codex-Token-Cost-App/releases/tag/v0.1.0
