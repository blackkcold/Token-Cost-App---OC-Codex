# S3 安全方案：认证凭证存储

> 版本: v0.1.2
> 状态: 已采纳 Keychain 方案，1Password 为可选增强
> 关联: 余额监控功能 — OpenCode Go Dashboard 凭证

---

## 背景

OpenCode Go 余量监控需要两个凭据：
- `workspaceID`（`wrk_...`）— 非敏感
- `authCookie`（`Fe26.2**...`）— 敏感，类比密码

当前 `AppPreferences` 将所有字段以明文 JSON 写入 `app-preferences.json`，存在以下风险：

| 风险 | 说明 |
|------|------|
| 磁盘取证 | `.json` 文件明文可读，任何拥有文件读权限的进程均可获取 |
| 备份泄露 | Time Machine / iCloud 备份包含明文 cookie |
| 本地恶意软件 | 读取 `~/Library/Application Support/` 即可获取 |

---

## 方案 A：macOS Keychain（采纳）

### 原理

使用 macOS 内置的 `Security.framework` (`SecItemAdd` / `SecItemCopyMatching`)，将敏感凭证存储在系统钥匙串中。钥匙串数据由用户的 macOS 登录密码加密，仅在解锁后解密。

### API 封装

```swift
// Sources/CodexTokenCostCore/Balance/SecureCredentialStore.swift

import Foundation
import Security

enum SecureCredentialStore {
    private static let service = "com.yanghaoran.CodexTokenCost.opencode-go"

    // MARK: - Workspace ID

    static func saveWorkspaceID(_ id: String) {
        save(account: "workspace-id", value: id)
    }

    static func getWorkspaceID() -> String? {
        read(account: "workspace-id")
    }

    // MARK: - Auth Cookie

    static func saveAuthCookie(_ cookie: String) {
        save(account: "auth-cookie", value: cookie)
    }

    static func getAuthCookie() -> String? {
        read(account: "auth-cookie")
    }

    // MARK: - 凭证发现（启动时按优先级查找）

    static func discoverCredentials() -> (workspaceID: String?, cookie: String?) {
        // 1. Keychain（用户已保存）
        if let id = getWorkspaceID(), let cookie = getAuthCookie() {
            return (id, cookie)
        }

        // 2. 环境变量（调试/CI 使用）
        let env = ProcessInfo.processInfo.environment
        let envID = env["OPENCODE_GO_WORKSPACE_ID"]
        let envCookie = env["OPENCODE_GO_AUTH_COOKIE"]
        if let id = envID, let cookie = envCookie {
            saveWorkspaceID(id)
            saveAuthCookie(cookie)
            return (id, cookie)
        }

        // 3. opencode-bar 配置文件（自动导入）
        if let imported = importFromOpenCodeBarConfig() {
            return imported
        }

        return (nil, nil)
    }

    // MARK: - Private

    private static func save(account: String, value: String) {
        // 先删除旧值
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 写入新值
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    private static func importFromOpenCodeBarConfig() -> (String, String)? {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode-bar/opencode-go.json")
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let id = json["workspaceId"] as? String
            ?? json["workspaceID"] as? String
            ?? json["workspace_id"] as? String
        let cookie = json["authCookie"] as? String
            ?? json["auth_cookie"] as? String
            ?? json["cookie"] as? String

        guard let id, let cookie else { return nil }

        saveWorkspaceID(id)
        saveAuthCookie(cookie)
        return (id, cookie)
    }
}
```

### 数据流变化

```
修复前:
  用户输入 → AppPreferences → app-preferences.json
                                   ↑ cookie 明文落盘

修复后:
  用户输入 → Keychain (系统加密)
  环境变量 → 自动导入 Keychain
  opencode-bar config → 自动导入 Keychain
  AppPreferences 仅存 workspaceID（非敏感）
```

### 安全性分析

| 威胁 | Keychain 方案 | 明文方案 |
|------|-------------|---------|
| 本地进程读取 cookie | ❌ 需要 keychain-access entitlement | ✅ 读 `.json` 即可 |
| 磁盘取证 | 🔒 用户登录密码派生密钥加密 | 🔴 明文可见 |
| 备份泄露 | 🔒 不包含在普通文件备份中 | 🔴 备份含明文 |
| iCloud Keychain 同步 | 🔒 端到端加密（可选） | ❌ 不适用 |
| 内存攻击 | 🟡 内存中短暂存在 | 🟡 同样存在 |

### SettingsView 对应改动

```swift
// workspaceID — 普通 TextField
TextField("例如 wrk_01ABC...", text: $workspaceIDInput)
    .textFieldStyle(.roundedBorder)

// authCookie — SecureField（输入时掩码显示）
SecureField("输入 auth cookie (Fe26.2...)", text: $authCookieInput)
    .textFieldStyle(.roundedBorder)

// 保存按钮
Button("保存到钥匙串") {
    SecureCredentialStore.saveWorkspaceID(workspaceIDInput)
    SecureCredentialStore.saveAuthCookie(authCookieInput)
}
```

---

## 方案 B：1Password CLI 集成（可选增强，后续版本）

### 原理

使用 1Password CLI (`op`) 从 1Password 保险库读取凭证。需要用户预先安装 1Password 桌面 App 和 CLI，并在 1Password 中创建对应条目。

### 安装与检出

```bash
# 安装 CLI
brew install 1password-cli

# 验证
which op     # → /opt/homebrew/bin/op
op --version # → 2.x
```

### 条目结构（用户手动创建）

```
Vault: Private (或其他)
  Item: OpenCode Go Token Cost
    Field: workspaceID  → wrk_01ABCDEF0123456789ABCDEFG
    Field: cookie       → Fe26.2**...
```

### Swift Process 调用

```swift
func readFrom1Password(field: String) -> String? {
    let process = Process()
    process.executableURL = URL(filePath: "/opt/homebrew/bin/op")
    process.arguments = ["read", "op://Private/OpenCode Go Token Cost/\(field)"]
    let pipe = Pipe()
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        return nil
    }
}
```

### 会话管理

```bash
# 登录（使用 Touch ID 生物识别，有效期 30 天）
op signin --account my.1password.com --session-expires-in 43200m

# 也可用环境变量传递 session token
eval $(op signin --account my.1password.com)

# 后续读取无需再认证
op read "op://Private/OpenCode Go Token Cost/cookie"

# 退出会话
op signout
```

### 优缺点

| 优点 | 缺点 |
|------|------|
| 跨设备同步（1Password 云） | 需要用户安装 1Password + CLI |
| 端到端加密 | 首次/过期后需交互登录 |
| 多凭证统一管理 | 桌面 App 依赖（需已解锁） |
| 可同时用于 opencode-bar | 30 天需用户重新 biometry |

---

## 凭证发现优先级（终版）

```
app 启动 → DashboardFetcher 需要凭证:
  ├── 1. Keychain（优先）
  │     └── 首次输入后自动保存，永不过期
  ├── 2. 1Password CLI（可选，后续版本）
  │     └── op read "op://Private/OpenCode Go Token Cost/cookie"
  ├── 3. 环境变量（调试/CI）
  │     └── OPENCODE_GO_WORKSPACE_ID / OPENCODE_GO_AUTH_COOKIE
  ├── 4. opencode-bar 配置文件（自动导入）
  │     └── ~/.config/opencode-bar/opencode-go.json
  └── 5. 无可用凭证 → 提示用户在设置中输入
```

---

## 相关文件

| 文件 | 用途 |
|------|------|
| `Sources/CodexTokenCostCore/Balance/SecureCredentialStore.swift` | Keychain API 封装 |
| `Sources/CodexTokenCostCore/AppPreferences.swift` | 移除 `opencodeGoAuthCookie` 字段 |
| `Sources/CodexTokenCostApp/Stores/AppPreferencesModel.swift` | 移除 cookie binding |
| `Sources/CodexTokenCostApp/Views/SettingsView.swift` | 新增 Go 凭证输入区域 |
| `Sources/CodexTokenCostCore/Balance/Providers/OpenCodeGoDashboardFetcher.swift` | 调用 `SecureCredentialStore` 获取凭证 |
