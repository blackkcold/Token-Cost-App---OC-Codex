# 安全策略

## 支持的版本

| 版本   | 支持状态       |
|--------|--------------|
| 0.5.0  | 当前稳定版 |
| 0.1.1  | 当前稳定版，接受安全报告和修复 |
| 0.1.0  | 当前稳定版，接受安全报告和修复 |
| 更早版本 | 不再保证支持   |

## 报告安全漏洞

如发现安全漏洞，请通过以下方式报告：

1. **不要**在公开 Issue 中报告安全漏洞。
2. 发送邮件到项目维护者，或使用 GitHub [Private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability) 功能。
3. 请提供详细描述，包括复现步骤、影响范围和可能的修复建议。

我们会在 48 小时内确认收到报告，并在 1 周内给出初步评估结果。

## 安全设计原则

- 本应用**只读**访问 OpenCode 数据库和 Codex session 文件
- 不修改任何源数据文件
- 配置和快照仅写入本地 `Application Support` 目录
- 语言设置、总览计价偏好和 Provider 计费方案选择只写入本地 `config/app-preferences.json`，不接触源数据
- 总览页的实际 token 只是从已有来源数据派生的展示值（按 `input + output + reasoning` 计算），不会回写数据库、session 文件或网络
- 本地化资源只读加载，不会向网络或外部服务传输文案
- 内置计费文档只从 app bundle 资源读取，不开放任意本地文件路径，也不联网更新价格
- 不收集、不上传任何使用数据
- 余额监控功能（v0.1.2+）默认关闭 (`balanceEnabled=false`)，维持纯本地承诺。开启后通过 HTTPS 直接调用各 Provider 官方 API 端点（api.opencode.ai、chatgpt.com 等）获取实时余额；API key 从本地 auth.json 临时读取至内存，30 秒后清除，不持久化到磁盘或日志；所有网络请求使用 ephemeral URLSession，不经过第三方服务器；余额快照仅驻留内存，不写入任何本地文件
- OpenCode Go 配额监控的 authCookie 凭证使用 macOS Keychain (`Security.framework`) 加密存储（`kSecClassGenericPassword` + `kSecAttrAccessibleWhenUnlocked`），不写入明文 JSON 配置文件。workspaceID 为非敏感标识符，可明文存储于 `AppPreferences`
- 版本更新检查功能（v0.5.0+）仅向 GitHub 公开 API (`api.github.com/repos/blackkcold/Token-Cost-App-OC-Codex/releases/latest`) 发起匿名 GET 请求获取最新 Release 元数据，不携带认证凭据、不收集不上传任何用户数据；下载的 `.zip` 文件经大小与 Content-Length 交叉校验后存放于本地 `Application Support` 沙箱内的 `updates/` 目录，不解压后自动运行；检查频率缓存为每 24 小时一次，防止 API 限流
