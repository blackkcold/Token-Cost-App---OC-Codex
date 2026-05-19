# Token Cost App - OC Codex

跨平台的 AI 编程工具 token 用量和费用可视化仪表盘。支持 OpenCode 和 Codex 双数据源。

## 功能特性

- **双源统计** — 同时读取 OpenCode (SQLite) 和 Codex (JSONL Session) 数据
- **费用分析** — 按实际 API 定价和订阅成本双重口径计算费用；支持 OpenCode、ChatGPT/Codex、MiniMax、Xiaomi MiMo 的官方订阅 / Token Plan 预设，并可用 DIY 月费应对价格变更
- **可视化仪表盘** — 每日趋势图、Provider 性价比排行、模型分布饼图、堆叠条形图
- **中英双语** — 界面可在中文 / 英语之间切换，术语保持一致
- **多主题** — 海湾蓝、森林绿、暮光橙、极光紫 4 种主题色
- **本地离线** — 纯本地运行，不联网、不上传数据
- **只读安全** — 只读取，不修改任何源数据

## 快速开始

### 系统要求

- macOS 14.0 (Sonoma) 或更高版本

### 下载安装

从 [GitHub Releases](../../releases) 页面下载对应版本 `.zip`，解压后运行 `.app` 文件。命名和打包规则见 [开发手册](docs/开发手册.md)。

### 从源码构建

```bash
git clone https://github.com/blackkcold/Token-Cost-App-OC-Codex.git
cd Token-Cost-App-OC-Codex

# 仅构建 app
bash script/build_and_run_codex.sh build

# 编译并运行
bash script/build_and_run_codex.sh run

# 仅编译
swift build
```

## 配置说明

启动后，应用会自动扫描以下默认位置：

| 来源 | 类型 | 默认路径 |
|------|------|---------|
| OpenCode | SQLite 数据库 | `~/.local/share/opencode/`, `~/Library/Application Support/OpenCode/` |
| Codex | JSONL Session 文件 | `~/.codex/sessions/`, `~/.codex/archived_sessions/` |

可在 **设置面板** 中：
- 添加自定义扫描目录或数据库文件
- 调整扫描深度和快照保留数
- 切换界面语言和总览页 OpenCode 计价口径
- 管理各 Provider 计费方案：OpenCode Go / Zen、ChatGPT Plus / Pro / Business Codex、MiniMax Token Plan、Xiaomi MiMo Token Plan，或输入自定义 USD 月费
- 打开内置只读计费参考文档，离线查看当前内置价格口径
- 切换界面主题
- 管理 Codex session 来源

## 技术栈

- **语言**: Swift 6.0
- **UI**: SwiftUI + AppKit
- **构建**: Swift Package Manager
- **数据库**: SQLite3 (系统内置)

## 项目结构

```
Token-Cost-App-OC-Codex/
├── Sources/                   # 源码
│   ├── CodexTokenCostCore/    # 核心模块
│   ├── CodexTokenCostApp/     # 主应用
│   └── CodexTokenCostHelper/  # 辅助进程
├── docs/                      # 文档
├── script/                    # 构建脚本
├── dist/releases/             # 正式 release + 本地时间戳快照
└── .github/workflows/         # CI/CD
```

详见 [开发手册](docs/开发手册.md) 和 [架构逻辑链图](docs/架构逻辑链图.md)。

## 许可证

MIT License - 详见 [LICENSE](LICENSE)
