import Foundation
import Security

public enum SecureCredentialStore {
    private static let service = "com.yanghaoran.CodexTokenCost.opencode-go"

    public static func saveWorkspaceID(_ id: String) {
        save(account: "workspace-id", value: id)
    }

    public static func getWorkspaceID() -> String? {
        read(account: "workspace-id")
    }

    public static func saveAuthCookie(_ cookie: String) {
        save(account: "auth-cookie", value: cookie)
    }

    public static func getAuthCookie() -> String? {
        read(account: "auth-cookie")
    }

    public static func discoverCredentials() -> (workspaceID: String?, cookie: String?) {
        if let id = getWorkspaceID(), let cookie = getAuthCookie() {
            return (id, cookie)
        }

        let env = ProcessInfo.processInfo.environment
        if let id = env["OPENCODE_GO_WORKSPACE_ID"], let cookie = env["OPENCODE_GO_AUTH_COOKIE"] {
            saveWorkspaceID(id)
            saveAuthCookie(cookie)
            return (id, cookie)
        }

        if let imported = importFromOpenCodeBarConfig() {
            return imported
        }

        return (nil, nil)
    }

    static func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func save(account: String, value: String) {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

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
