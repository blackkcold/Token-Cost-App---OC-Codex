import Foundation

struct OpenCodeGoDashboardUsage {
    let rolling: UsageWindow?
    let weekly: UsageWindow?
    let monthly: UsageWindow?

    struct UsageWindow {
        let usagePercent: Double
        let resetInSec: Int
        let resetDate: Date
    }

    var maxUsagePercent: Double? {
        [rolling?.usagePercent, weekly?.usagePercent, monthly?.usagePercent]
            .compactMap { $0 }.max()
    }
}

enum OpenCodeGoDashboardFetcher {
    private static let modelsURL = URL(string: "https://opencode.ai/zen/go/v1/models")!

    static func fetch(apiKey: String, workspaceID: String, cookie: String) async throws -> OpenCodeGoDashboardUsage {
        let modelCount = try await fetchModelCount(apiKey: apiKey)
        guard modelCount > 0 else {
            throw BalanceFetchError.unavailable("无可用 Go 模型")
        }

        return try await fetchDashboardUsage(workspaceID: workspaceID, cookie: cookie)
    }

    private static func fetchModelCount(apiKey: String) async throws -> Int {
        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw BalanceFetchError.unavailable("Go API 不可用")
        }

        let object = try JSONSerialization.jsonObject(with: data)
        if let dict = object as? [String: Any] {
            if let arr = dict["data"] as? [Any] { return arr.count }
            if let arr = dict["models"] as? [Any] { return arr.count }
        }
        if let arr = object as? [Any] { return arr.count }
        throw BalanceFetchError.unavailable("无法解析模型列表")
    }

    private static func fetchDashboardUsage(workspaceID: String, cookie: String) async throws -> OpenCodeGoDashboardUsage {
        guard let url = URL(string: "https://opencode.ai/workspace/\(workspaceID)/go") else {
            throw BalanceFetchError.unavailable("Invalid workspace URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("auth=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BalanceFetchError.unavailable("无效响应")
        }
        switch httpResponse.statusCode {
        case 200: break
        case 302, 401, 403:
            throw BalanceFetchError.unavailable("Cookie 已过期，请重新配置")
        default:
            throw BalanceFetchError.unavailable("HTTP \(httpResponse.statusCode)")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw BalanceFetchError.unavailable("无法解析页面")
        }

        guard let usage = parseWindows(from: html) else {
            throw BalanceFetchError.unavailable("未找到配额数据")
        }

        return usage
    }

    // MARK: - HTML Parsing

    private static func parseWindows(from html: String) -> OpenCodeGoDashboardUsage? {
        // Format 1: self.__next_f.push([1,"{...}"])
        let pattern1 = #"self\.__next_f\.push\(\[1,"(\{.*?\})"\]\)"#
        if let json = firstMatch(pattern: pattern1, in: html) {
            let cleaned = json
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
            if let usage = parseUsageJSON(cleaned) { return usage }
        }

        // Format 2: $R[n]($R[m],$R[k]={...});
        let pattern2 = #"\$R\[\d+\]\s*=\s*\{[^}]*rollingUsage[^}]*\}"#
        if let match = firstMatchRaw(pattern: pattern2, in: html) {
            if let usage = parseUsageJSON(match) { return usage }
        }

        return nil
    }

    private static func parseUsageJSON(_ json: String) -> OpenCodeGoDashboardUsage? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        func parseWindow(_ dict: [String: Any]?) -> OpenCodeGoDashboardUsage.UsageWindow? {
            guard let dict else { return nil }
            let pct: Double? = {
                if let d = dict["usagePercent"] as? Double { return d }
                if let s = dict["usagePercent"] as? String, let d = Double(s) { return d }
                if let i = dict["usagePercent"] as? Int { return Double(i) }
                return nil
            }()
            let sec: Int? = {
                if let i = dict["resetInSec"] as? Int { return i }
                if let s = dict["resetInSec"] as? String, let i = Int(s) { return i }
                return nil
            }()
            guard let pct, let sec else { return nil }
            return OpenCodeGoDashboardUsage.UsageWindow(
                usagePercent: pct,
                resetInSec: sec,
                resetDate: Date().addingTimeInterval(Double(sec))
            )
        }

        return OpenCodeGoDashboardUsage(
            rolling: parseWindow(obj["rollingUsage"] as? [String: Any]),
            weekly: parseWindow(obj["weeklyUsage"] as? [String: Any]),
            monthly: parseWindow(obj["monthlyUsage"] as? [String: Any])
        )
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func firstMatchRaw(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 0), in: text)
        else { return nil }
        return String(text[range])
    }
}

struct BalanceFetchError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    static func unavailable(_ msg: String) -> BalanceFetchError {
        BalanceFetchError(message: msg)
    }
}
