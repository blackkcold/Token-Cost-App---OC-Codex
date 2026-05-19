# 安全方案：Cookie Keychain 存储（替代明文 JSON）

> 版本: v0.1.2  
> 创建日期: 2026-05-19  
> 状态: 已审核，待实现

---

## 背景

OpenCode Go 余额监控需要 `workspaceID` + `authCookie` 两个凭证，其中 `authCookie` 是浏览器 cookie，明文存储在 `app-preferences.json` 中存在安全风险。

## 方案：macOS Keychain

### 对比

| 方案 | 安全性 | 复杂度 | 兼容 opencode-bar |
|------|--------|--------|-----------------|
| **A. Keychain** | 🔒 系统级加密 | 中 (~50行) | ✅ 自动导入 |
| B. 仅环境变量 | 🟡 依赖 Shell | 低 | ✅ |
| C. 明文 JSON | 🔴 明文 | 低 | ✅ |

**选择方案 A。**

---

## 设计：SecureCredentialStore

### 文件位置

```
Sources/CodexTokenCostCore/Balance/SecureCredentialStore.swift
```

### 接口

```swift
import Foundation
import Security

enum SecureCredentialStore {
    private static let service = "com.yanghaoran.CodexTokenCost.opencode-go"

    static func saveWorkspaceID(_ id: String) { ... }
    static func getWorkspaceID() -> String? { ... }
    static func saveAuthCookie(_ cookie: String) { ... }
    static func getAuthCookie() -> String? { ... }
    static func deleteAll() { ... }

    /// 凭证发现：Keychain → 环境变量 → opencode-bar 配置
    static func discoverCredentials() -> (workspaceID: String?, cookie: String?)
}
```

### 凭证发现优先级

```
1. Keychain（已保存过）
2. 环境变量 OPENCODE_GO_WORKSPACE_ID + OPENCODE_GO_AUTH_COOKIE
3. ~/.config/opencode-bar/opencode-go.json（如果 opencode-bar 已配置）
   → 自动导入到 Keychain
```

---

## Keychain API 核心实现

```swift
// 存储
static func save(_ value: String, account: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecValueData as String: Data(value.utf8),
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
    ]
    // 先尝试删除旧项，再添加新项
    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
}

// 读取
static func get(account: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
}
```

---

## 数据流变化

```
修复前:
  用户输入 → AppPreferences (明文JSON) → DashboardFetcher
                                ↑
                          cookie 明文落盘 ✗

修复后:
  用户输入 → Keychain (系统加密) → DashboardFetcher
  环境变量 → 自动导入 Keychain
  opencode-bar config → 自动导入 Keychain
  
  AppPreferences 只存 workspaceID (非敏感)
```

---

## SettingsView 变更

```swift
// authCookie 用 SecureField（输入内容不可见）
@State private var authCookieInput: String = ""
SecureField("auth cookie", text: $authCookieInput)
    .textFieldStyle(.roundedBorder)
    .onAppear { authCookieInput = SecureCredentialStore.getAuthCookie() ?? "" }

// workspaceID 用普通 TextField
@State private var workspaceIDInput: String = ""
TextField("wrk_...", text: $workspaceIDInput)
    .textFieldStyle(.roundedBorder)
    .onAppear { workspaceIDInput = SecureCredentialStore.getWorkspaceID() ?? "" }

Button("保存凭证") {
    SecureCredentialStore.saveWorkspaceID(workspaceIDInput)
    SecureCredentialStore.saveAuthCookie(authCookieInput)
}
```

---

## 安全性分析

| 威胁 | Keychain 方案 | 明文方案 |
|------|-------------|---------|
| 本地进程读取 cookie | ❌ 需要 keychain-access entitlement（除非同一 Team ID） | ✅ 读 JSON 即可 |
| 磁盘取证 | 🔒 Keychain 加密（用户登录密码派生密钥） | 🔴 明文可见 |
| 备份泄露 | 🔒 Keychain 不包含在普通文件备份中 | 🔴 备份含明文 cookie |
| 内存攻击 | 🟡 内存中短暂存在（fetch 期间） | 🟡 同样存在 |
| cookie 过期 | 🔒 同明文：标记不可用 + 提示 | 🔒 同左 |

---

## 改动清单

| 文件 | 改动 |
|------|------|
| `SecureCredentialStore.swift` (新) | Keychain 封装 + 凭证发现 |
| `AppPreferences.swift` | 移除 `opencodeGoAuthCookie`；保留 `opencodeGoWorkspaceID` |
| `AppPreferencesModel.swift` | 移除 cookie binding |
| `SettingsView.swift` | workspaceID + authCookie SecureField；保存到 Keychain |
| `OpenCodeGoDashboardFetcher.swift` | 从 Keychain 读取凭证 |
| `CHANGELOG.md` | 记录安全加固 |

---

## 依赖

- `Security.framework`（系统自带，无需额外引入）
- macOS 10.0+（Keychain API 历史久远，无版本限制）
