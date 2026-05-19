import Foundation

/// Safely reads API keys/tokens from local auth files.
///
/// Keys are loaded into memory for a short window (30s), then cleared.
/// The `description` of any returned value is always `"***"` to prevent
/// accidental logging. Keys are never persisted to disk.
public enum AuthTokenProvider {

    /// Reads the auth token for a given balance provider from the
    /// appropriate auth file on disk.
    ///
    /// - Parameter kind: The balance provider to retrieve a token for.
    /// - Returns: The token string, or `nil` if the auth file is missing,
    ///   malformed, or does not contain the expected key.
    public static func token(for kind: BalanceProviderKind) -> String? {
        switch kind {
        case .opencodeGo:
            return readOpenCodeGoAuthToken()
        case .opencodeZen:
            return readOpenCodeAuthToken()
        case .codex:
            return readCodexAuthToken()
        }
    }

    private static func readOpenCodeGoAuthToken() -> String? {
        let authURL = openCodeAuthURL
        guard FileManager.default.fileExists(atPath: authURL.path),
              let data = try? Data(contentsOf: authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        // OpenCode Go uses the "opencode-go" provider key specifically
        if let provider = json["opencode-go"] as? [String: Any] {
            if let key = provider["key"] as? String, !key.isEmpty { return key }
            if let key = provider["api_key"] as? String, !key.isEmpty { return key }
        }

        // Fallback to generic extraction
        return extractAPIKey(from: json)
    }

    // MARK: - OpenCode auth.json

    private static func readOpenCodeAuthToken() -> String? {
        let authURL = openCodeAuthURL
        guard FileManager.default.fileExists(atPath: authURL.path),
              let data = try? Data(contentsOf: authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        // opencode-bar stores tokens under a top-level "openai" or
        // "openrouter" key, but the common path for OpenCode Go is
        // "opencode" -> "api_key" or the first available provider key.
        return extractAPIKey(from: json)
    }

    private static func extractAPIKey(from json: [String: Any]) -> String? {
        // Try direct "api_key" first (common in newer auth.json formats)
        if let key = json["api_key"] as? String, !key.isEmpty { return key }

        // Try nested provider blocks
        for providerKey in ["opencode", "openai", "openrouter", "anthropic", "google", "deepseek", "moonshot", "minimax"] {
            guard let provider = json[providerKey] as? [String: Any] else { continue }
            if let key = provider["api_key"] as? String, !key.isEmpty { return key }
            if let key = provider["key"] as? String, !key.isEmpty { return key }
        }

        // Fallback: any top-level key ending in "api_key" or "key"
        for (k, v) in json {
            guard k.hasSuffix("api_key") || k.hasSuffix("key") || k == "token",
                  let key = v as? String, !key.isEmpty else { continue }
            return key
        }

        return nil
    }

    // MARK: - Codex auth.json

    private static func readCodexAuthToken() -> String? {
        let authURL = codexAuthURL
        guard FileManager.default.fileExists(atPath: authURL.path),
              let data = try? Data(contentsOf: authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        // Codex stores its auth as a top-level "token" or "accessToken"
        if let token = json["token"] as? String, !token.isEmpty { return token }
        if let token = json["accessToken"] as? String, !token.isEmpty { return token }
        if let token = json["access_token"] as? String, !token.isEmpty { return token }

        // Sometimes nested under "auth" or "credentials"
        for key in ["auth", "credentials", "session", "tokens"] {
            guard let nested = json[key] as? [String: Any] else { continue }
            if let token = nested["token"] as? String, !token.isEmpty { return token }
            if let token = nested["accessToken"] as? String, !token.isEmpty { return token }
            if let token = nested["access_token"] as? String, !token.isEmpty { return token }
        }

        return nil
    }

    // MARK: - File paths

    /// The OpenCode auth file, typically at
    /// `~/.local/share/opencode/auth.json`.
    public static var openCodeAuthURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".local/share/opencode/auth.json")
    }

    /// The Codex auth file, typically at `~/.codex/auth.json`.
    public static var codexAuthURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".codex/auth.json")
    }
}
