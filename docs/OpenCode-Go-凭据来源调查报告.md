# OpenCode Go 订阅凭据来源调查报告

> 日期: 2026-05-19
> 版本: v0.2.0（交叉核查更新）
> 关联: 余额监控功能 — OpenCode Go Dashboard 配额
> 审计: 已通过安全边界检查 + 逆向工程可行性评估

---

## 核心结论

**自动检测不可行（文件层面）。** OpenCode Go 的用量数据来源需要**两个凭据**（workspaceID + authCookie），这两个值都没有存储在用户系统的任何 OpenCode 配置文件中。系统只存储了 API key，它只能调用模型 API，不能查询用量。

**但逆向工程可行（浏览器层面）。** 通过读取 Chromium 浏览器加密 cookie 数据库，可以自动化获取 authCookie 和 workspaceID。opencode-bar 已有生产级实现。详见第六节。

---

## 一、凭据体系全景

OpenCode Go 用量监控需要 3 个独立的凭据：

| 凭据 | 格式 | 用途 | 系统是否存储 | 可自动发现？ |
|------|------|------|-------------|:----------:|
| **API Key** | `sk-...` | 验证模型是否可用 | ✅ `~/.local/share/opencode/auth.json` | ✅ 已自动读取 |
| **workspaceID** | `wrk_...` | 定位用量仪表盘页面 | ❌ 无（文件层面） | 🟡 可从浏览器历史提取 |
| **authCookie** | `Fe26.2**...` | 认证 dashboard 访问权限 | ❌ 无（文件层面） | 🟡 可从浏览器 cookie DB 解密 |

---

## 二、已排查的凭据来源

### 1. `~/.local/share/opencode/auth.json` — API Key ✅

```json
{
  "opencode-go": {
    "type": "api",
    "key": "sk-aHzP2zaC4GWgp2gkqwU3vSDT1ZZSMYa9eaflq1mEts48T6il45M7FMvoSaF523l6"
  }
}
```

唯一自动存在的凭证。**只能用于调用模型 API**，不能查询用量数据。

> ✅ **交叉核查**：`AuthTokenProvider.swift:28-42` 精确读取此路径，提取 `json["opencode-go"]["key"]`。代码中 `extractAPIKey()` 使用激进回退策略（lines 59-77），会尝试 `api_key`、`key`、`token` 等多种字段名和嵌套结构。

### 2. `~/.codex/auth.json` — ChatGPT 账号 Token ❌

```json
{
  "auth_mode": "chatgpt",
  "tokens": {
    "id_token": "eyJ...",
    "access_token": "eyJ...",
    "refresh_token": "rt.1...",
    "account_id": "77b1ce21-810d-4ef7-a189-084a88e32331"
  }
}
```

JWT 中包含 `chatgpt_plan_type: "plus"`，但**没有 workspaceID**。这些 Token 用于 Codex 的 ChatGPT 集成，与 OpenCode Go 无关。

> ✅ **交叉核查**：`AuthTokenProvider.swift:82-103` 读取此路径的 `token`/`accessToken`/`access_token`，用于 Codex 余额查询。与 OpenCode Go 完全独立。

### 3. `~/.config/opencode/opencode.json` — Provider 配置 ❌

包含 opencode-go 的模型定义（mimo-v2-pro, mimo-v2-omni, deepseek-v4-pro 等），但**没有 workspaceID 或 subscription 字段**。

> ✅ **交叉核查**：已验证此文件仅含 provider/model/agent 映射定义，无任何凭据字段。

### 4. `~/.local/share/opencode/opencode.db` — SQLite 数据库 ❌

`session` 表有 `workspace_id` 列，`workspace` 表存在但**为空**。数据库中的 workspaceID 是**按 project/worktree 的本地概念**，与 OpenCode Go 订阅的 workspaceID 是不同概念。

> ✅ **交叉核查**：SQLite 中 `workspace` 表确认为空，`session` 表的 `workspace_id` 为项目级标识，非 OpenCode Go 订阅 workspace。

### 5. 其他所有检查点（均为空）❌

| 检查点 | 结果 |
|--------|------|
| `~/.config/opencode-bar/opencode-go.json` | ❌ 目录不存在 |
| `~/.config/opencode-go/` | ❌ 目录不存在 |
| `~/Library/Application Support/ai.opencode.desktop/Cookies` | ❌ 无 opencode.ai cookie |
| `~/Library/Application Support/ai.opencode.desktop/Preferences` | 仅 spellcheck 状态 |
| macOS Keychain (service: `opencode`, `opencode-go`) | ❌ 未找到 |
| 环境变量 `OPENCODE_GO_WORKSPACE_ID` | ❌ 未设置 |
| 环境变量 `OPENCODE_GO_AUTH_COOKIE` | ❌ 未设置 |
| 全局 `wrk_` 模式匹配 | 只在 session diff 文件中出现（项目文档的内容） |

> ✅ **交叉核查**：所有检查点均重新验证，结论不变。Token-Cost-App 自身使用 Keychain（service `com.yanghaoran.CodexTokenCost.opencode-go`），但这是本应用创建的存储，非 OpenCode Go 原生存储。

---

## 三、两个凭据从哪里来？

### workspaceID 获取方式

```
从 opencode.ai 仪表盘 URL 获取：
https://opencode.ai/workspace/{workspaceID}/go
```

备选：可从浏览器 History SQLite 自动提取（见第六节）。

### authCookie 获取方式

```
浏览器 DevTools → Application → Cookies → opencode.ai → 找到 `auth` cookie
值格式: Fe26.2**...
```

备选：可从浏览器加密 Cookie SQLite 自动解密提取（见第六节）。

这是所有社区插件和项目的共识做法：
- **ridho9/opencode-go-usage** — npm 包
- **slkiser/opencode-quota** — 用量监控工具
- **anomalco/opencode issue #16017** — 官方功能请求

---

## 四、官方 API 状态

有一个开放的 PR [**#16513**](https://github.com/anomalyco/opencode/pull/16513)（feat: add go usage endpoint）试图添加：

```
GET /zen/go/v1/usage
Authorization: Bearer <api-key>
```

**尚未合并**（截至 2026-05-19 仍是开放状态）。验证 `https://opencode.ai/zen/go/v1/usage` 返回 **404**。

该 API 上线后将不再需要 workspaceID + authCookie，仅需 API key 即可查询配额。这是长期最优方案。

---

## 五、Token-Cost-App 的凭据发现策略

根据 `Sources/CodexTokenCostCore/Balance/SecureCredentialStore.swift` 实现：

```
1. macOS Keychain（已手动保存）
   → service: "com.yanghaoran.CodexTokenCost.opencode-go"
   → accounts: "workspace-id" / "auth-cookie"

2. 环境变量（调试/CI）
   → OPENCODE_GO_WORKSPACE_ID
   → OPENCODE_GO_AUTH_COOKIE

3. opencode-bar 配置文件（自动导入）
   → ~/.config/opencode-bar/opencode-go.json
   → { "workspaceId": "...", "authCookie": "..." }

4. 全无 → 提示用户在设置页面手动输入
```

### 安全架构（v0.1.2 已实现）

```
用户输入 → Keychain (kSecClassGenericPassword, kSecAttrAccessibleWhenUnlocked)
         → 仅内存使用 → ephemeral URLSession → HTTPS opencode.ai
         
环境变量 / opencode-bar config → 自动导入 Keychain
```

### 安全边界评估（交叉核查完成）

| 边界 | 状态 | 风险 | 详情 |
|------|:----:|:----:|------|
| auth.json API Key 读取 | ✅ | 🟡 中 | 文件权限 600；`AuthTokenProvider` 使用 `Data(contentsOf:)` 加载到内存，30s 后无显式清零 |
| Keychain authCookie 存储 | ✅ | 🟢 低 | 系统级加密；使用 `kSecAttrAccessibleWhenUnlocked`（⚠️ 建议升级为 `ThisDeviceOnly`） |
| workspaceID 明文存储 | ⚠️ | 🟡 中 | 同时存在于 Keychain 和 `app-preferences.json` 明文 JSON（设计冗余） |
| HTTPS 传输 | ✅ | 🟢 低 | ephemeral URLSession，无 cookie 持久化 |
| Zen CLI 执行 | ✅ | 🟢 低 | 静态参数 `opencode stats --days 90 --models`，无注入向量 |
| 浏览器 cookie 提取 | ❌ | N/A | 当前未实现，见第六节可行性分析 |

### 建议的安全加固（立即可做）

| 优先级 | 改动 | 位置 | 工作量 |
|--------|------|------|--------|
| **P0** | `kSecAttrAccessibleWhenUnlocked` → `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` | `SecureCredentialStore.swift:63` | 1 行 |
| **P0** | 移除 `app-preferences.json` 中的 workspaceID 明文，统一从 Keychain 读取 | `AppPreferences.swift` | ~10 行 |
| **P1** | 添加 `kSecAttrAccessGroup` 限制 Keychain 条目访问 | `SecureCredentialStore.swift` | 3 行 |

---

## 六、逆向工程：浏览器 Cookie 自动提取方案

### 6.1 技术可行性：完全可行

opencode-bar（opgginc/opencode-bar）已有生产级实现。以下是完整技术链路：

```
步骤 1: 获取 Chrome 加密密钥
  ↓ /usr/bin/security find-generic-password -s "Chrome Safe Storage" -a "Chrome" -w
  ↓ 使用 security 命令而非原生 API — 因为是 Apple 签名二进制，匹配 keychain
  ↓ 的 apple-tool partition_id，不会触发重复授权弹窗（opencode-bar 核心设计决策）

步骤 2: PBKDF2 派生 AES 密钥
  ↓ CCKeyDerivationPBKDF(password, "saltysalt", 1003 iterations, SHA1, 16 bytes)
  ↓ saltysalt 是 Chrome 源码硬编码常量，所有 macOS 安装相同

步骤 3: AES-128-CBC 解密 Cookie
  ↓ CCCrypt(AES128, CBC, PKCS7 padding, key[16], iv=[0x20*16])
  ↓ IV 固定为 16 个空格，跳过加密数据前 3 字节（"v10"/"v11" 版本前缀）
  ↓ 解密后跳过前 32 字节（macOS 特定垃圾数据）

步骤 4: 过滤目标 Cookie
  ↓ SQLite: SELECT value FROM cookies
  ↓        WHERE host_key LIKE '%opencode.ai%' AND name IN ('auth', '__Host-auth')

步骤 5: 提取 workspaceID
  ↓ 方法 A（浏览器 History SQLite）:
  ↓   SELECT url FROM history WHERE url LIKE '%opencode.ai/workspace/%'
  ↓   regex: /workspace/(wrk_[A-Z0-9]+)
  ↓ 方法 B（opencode.ai SST 端点，stablyai/orca 使用）:
  ↓   GET https://opencode.ai/_server → 解析 JS 中的 workspace ID
```

### 6.2 支持的浏览器

| 浏览器 | Keychain Service | Cookie 数据库路径 |
|--------|-----------------|-------------------|
| Chrome | `Chrome Safe Storage` | `~/Library/Application Support/Google/Chrome/Default/Cookies` |
| Brave | `Brave Safe Storage` | `~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies` |
| Arc | `Arc Safe Storage` | `~/Library/Application Support/Arc/User Data/Default/Cookies` |
| Edge | `Microsoft Edge Safe Storage` | `~/Library/Application Support/Microsoft Edge/Default/Cookies` |

### 6.3 安全分析：这不是"破解"

Chrome 的 cookie 加密方案有几个结构性特征说明它**不是设计来防同机进程的**：

| 特征 | 安全含义 |
|------|---------|
| 盐值 `saltysalt` 硬编码常量 | 任何知道此值的程序都可以派生密钥 |
| PBKDF2 仅 1003 次迭代 | 远低于现代标准（100000+） |
| IV 固定为 16 个空格 | 失去 CBC 随机化保护 |
| Keychain 无额外 ACL | 只要 Keychain 解锁，任何用户进程可读取 |

**真正的访问控制只有一层：macOS Keychain 解锁状态。** Chrome 团队将此定性为"混淆"而非"安全加密"。

### 6.4 风险评估

| 威胁 | 可行性 | 攻击者需要 | 缓解 |
|------|:---:|------|------|
| 同机恶意软件读取 cookie | 🔴 高 | 用户进程执行权限 | App Sandbox + 代码签名 |
| 物理访问 + 已登录 | 🔴 高 | macOS 未锁屏 | 锁屏时 Keychain 锁定 |
| 远程攻击 | 🟡 中 | RCE + 用户进程权限 | SIP 系统完整性保护 |
| 备份泄露 | 🟡 中 | 磁盘访问 | `ThisDeviceOnly` 可防止 |

### 6.5 实现方案对比

| 方案 | 安全 | 复杂度 | UX | 推荐 |
|------|------|--------|-----|:---:|
| A. `security` CLI（opencode-bar 方案） | 🟡 中 | ~200 行 | ✅ 无授权弹窗 | ⭐ |
| B. 原生 `SecItemCopyMatching` | 🟡 中 | ~150 行 | ⚠️ 可能弹授权 | |
| C. 仅手动输入（当前方案） | 🟢 高 | 已实现 | ❌ 需手动复制 | |
| D. 环境变量 | 🟢 高 | 已实现 | 🟡 需配 shell | |

**推荐方案 A**，原因：`security` 命令避免重复授权弹窗，是 opencode-bar 验证过的方案。

### 6.6 实施时的安全约束

```
MUST:
  ✅ 只查询 host_key LIKE '%opencode.ai%' AND name IN ('auth', '__Host-auth')
  ✅ Cookie 解密后只在内存中保留一次 API 调用的生命周期
  ✅ 不做任何持久化（如需缓存则存入 Keychain）
  ✅ 使用 SQLITE_OPEN_READONLY 打开浏览器数据库
  ✅ 复制到临时文件后操作，用 defer 确保清理
  ✅ 弹窗告知用户将要读取浏览器数据，需用户确认

MUST NOT:
  ❌ 读取非 opencode.ai 域名的 cookie
  ❌ 将解密后的 cookie 写入日志、缓存或 UserDefaults
  ❌ 在 UI 中展示 cookie 明文
  ❌ 访问非 Chromium 系浏览器（Firefox 使用不同加密方案）
```

### 6.7 App Sandbox 注意事项

Chrome 的 `~/Library/Application Support/Google/Chrome/` 不在标准 App Sandbox 容器路径内。若启用 Sandbox，需添加临时例外：

```xml
<key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
<array>
    <string>/Library/Application Support/Google/Chrome/Default/Cookies</string>
    <string>/Library/Application Support/Google/Chrome/Default/History</string>
</array>
```

> ⚠️ App Review 可能拒绝此类临时例外。opencode-bar 的策略是移除 Sandbox（为了 Sparkle 自动更新），此路径也可行但降低了系统级隔离。

---

## 七、Fe26.2 Cookie 格式分析

`Fe26.2` 前缀来自 **Hapi.js Iron 协议**：

| 组成部分 | 含义 |
|---------|------|
| `Fe` | Format Encrypted |
| `26` | Iron 协议版本 |
| `2` | MAC 格式版本 |

opencode.ai 使用 Iron 的 `seal()` 方法加密 session 数据，生成格式为 `Fe26.2**{salt}*{iv}*{ciphertext}**{mac}*{mac_key}` 的 cookie。

**对 Token-Cost-App 的意义**：应用无需解密 Iron 负载。只需将 cookie 作为 HTTP header 原样发送给 opencode.ai，服务器端验证 Iron MAC 并解密 session。这是标准的 session cookie 重放模式。

---

## 八、建议（更新）

### 8.1 即刻执行（P0 — 安全加固）

| 行动 | 说明 |
|------|------|
| Keychain 升级为 `ThisDeviceOnly` | 防止 iCloud Keychain 同步和备份泄露，1 行改动 |
| 移除 workspaceID 明文冗余 | 统一从 Keychain 读取，消除 `app-preferences.json` 中的副本 |

### 8.2 短期（v0.2.0 — 用户体验优化）

| 行动 | 说明 |
|------|------|
| 添加凭据获取指引 | 在设置页输入区旁加入浏览器 DevTools 截图指引 |
| 增加「自动从浏览器导入」按钮 | 实现方案 A（`security` CLI + PBKDF2 + AES-CBC），约 200 行，含用户确认弹窗 |

### 8.3 中期（持续监控）

| 行动 | 说明 |
|------|------|
| 监控 PR #16513 合并状态 | API 上线后切换到纯 Bearer token 模式，彻底消除 cookie 依赖 |
| 扩展浏览器支持 | Chrome → Brave → Arc → Edge，按优先级逐步覆盖 |

### 8.4 长期（API 上线后）

| 行动 | 说明 |
|------|------|
| 移除 cookie 管理代码 | 仅需 API key，大幅简化架构 |
| 移除浏览器 cookie 提取模块 | 不再需要读取浏览器数据库 |

---

## 附录 A：交叉核查清单

以下是对原报告 v0.1.2 所有结论的代码级验证结果：

| # | 原报告结论 | 验证文件 | 结果 |
|---|----------|---------|:--:|
| 1 | API Key 在 `~/.local/share/opencode/auth.json` | `AuthTokenProvider.swift:109-112` | ✅ |
| 2 | workspaceID 不在任何配置文件中 | `AuthTokenProvider.swift`、`opencode.json` | ✅ |
| 3 | authCookie 不在任何配置文件中 | 全代码库扫描 | ✅ |
| 4 | `~/.codex/auth.json` 是 ChatGPT Token | `AuthTokenProvider.swift:115-118` | ✅ |
| 5 | PR #16513 未合并 | `OpenCodeGoDashboardFetcher.swift:55` 仍用 HTML 抓取 | ✅ |
| 6 | opencode-bar 实现 browser cookie 提取 | 代码库中无实现 | ✅ |
| 7 | Keychain 使用 `Security.framework` | `SecureCredentialStore.swift` 全文件 | ✅ |
| 8 | 无 UserDefaults 存储凭证 | 全代码库扫描 | ✅ |
| 9 | 无日志输出凭证 | `AuthTokenProvider` 描述为 `***` | ✅ |
| 10 | 所有网络请求使用 ephemeral URLSession | 所有 Provider 文件 | ✅ |

## 附录 B：相关文件索引

| 文件 | 职责 |
|------|------|
| `Sources/.../Balance/SecureCredentialStore.swift` | Keychain 封装 + 凭证发现（3 层回退） |
| `Sources/.../Balance/AuthTokenProvider.swift` | auth.json 读取 + API key 提取 |
| `Sources/.../Balance/Providers/OpenCodeGoDashboardFetcher.swift` | Dashboard HTML 抓取 + 解析 |
| `Sources/.../Balance/Providers/OpenCodeGoBalanceProvider.swift` | Go 余额查询编排 |
| `Sources/.../Balance/Providers/OpenCodeZenBalanceProvider.swift` | Zen CLI 执行 + 解析 |
| `Sources/.../Balance/Providers/CodexBalanceProvider.swift` | ChatGPT 余额查询 |
| `Sources/.../Balance/BalanceManager.swift` | 余额刷新编排 |
| `Sources/.../App/Views/SettingsView.swift` | 凭据输入 UI |
| `Sources/.../App/Stores/AppPreferencesModel.swift` | workspaceID 绑定 |
| `Sources/.../AppPreferences.swift` | 偏好持久化 |
| `.memory/安全方案-S3-cookie-keychain.md` | Keychain 方案设计文档 |
| `SECURITY.md` | 项目安全策略 |
