import Foundation
import Security

public enum SecureCredentialStore {
    private static let service = "com.yanghaoran.CodexTokenCost.opencode-go"

    public static func saveWorkspaceID(_ id: String) {
        save(account: "workspace-id", value: id, service: service)
    }
    static func saveWorkspaceID(_ id: String, service: String) {
        save(account: "workspace-id", value: id, service: service)
    }

    public static func getWorkspaceID() -> String? {
        read(account: "workspace-id", service: service)
    }
    static func getWorkspaceID(service: String) -> String? {
        read(account: "workspace-id", service: service)
    }

    public static func saveAuthCookie(_ cookie: String) {
        save(account: "auth-cookie", value: cookie, service: service)
    }
    static func saveAuthCookie(_ cookie: String, service: String) {
        save(account: "auth-cookie", value: cookie, service: service)
    }

    public static func getAuthCookie() -> String? {
        read(account: "auth-cookie", service: service)
    }
    static func getAuthCookie(service: String) -> String? {
        read(account: "auth-cookie", service: service)
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

        let extracted = BrowserCookieExtractor.extractCredentials()
        let finalID = extracted.workspaceID ?? getWorkspaceID()
        let finalCookie = extracted.cookie ?? getAuthCookie()
        if let id = finalID, let cookie = finalCookie {
            if extracted.workspaceID == nil { saveWorkspaceID(id) }
            if extracted.cookie == nil { saveAuthCookie(cookie) }
            return (id, cookie)
        }

        return (nil, nil)
    }

    public static func deleteWorkspaceID() {
        delete(account: "workspace-id", service: service)
    }
    static func deleteWorkspaceID(service: String) {
        delete(account: "workspace-id", service: service)
    }

    static func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func save(account: String, value: String, service: String) {
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

    private static func delete(account: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func read(account: String, service: String) -> String? {
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
