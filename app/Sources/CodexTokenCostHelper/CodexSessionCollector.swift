import Foundation
import CodexTokenCostCore

public enum CodexSessionCollectorError: LocalizedError {
    case invalidArgument(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArgument(let message):
            return message
        }
    }
}

public final class CodexSessionCollector {
    private let fileManager = FileManager.default
    private let sourceRoots: [URL]
    private let manualSourcePaths: [URL]
    private let profile: TokenCostSourceProfile

    public init(
        sourceRoots: [URL] = [],
        manualSourcePaths: [URL] = [],
        profile: TokenCostSourceProfile = .codex
    ) {
        self.sourceRoots = sourceRoots
        self.manualSourcePaths = manualSourcePaths
        self.profile = profile
    }

    public func loadPayload() throws -> CodexDashboardPayload {
        let files = discoverSessionFiles()
        let sessions = files.compactMap { parseSessionFile($0) }
        return buildPayload(from: sessions)
    }

    private func discoverSessionFiles() -> [URL] {
        var seen = Set<String>()
        var urls: [URL] = []

        for configuredPath in effectiveSourceRoots + effectiveManualSourcePaths {
            collectConfiguredPath(configuredPath, seen: &seen, into: &urls)
        }

        return urls.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if lhsDate == rhsDate {
                return lhs.path < rhs.path
            }
            return lhsDate > rhsDate
        }
    }

    private func collectConfiguredPath(_ configuredPath: URL, seen: inout Set<String>, into urls: inout [URL]) {
        let canonical = TokenCostPathUtilities.canonicalURL(configuredPath)
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: canonical.path, isDirectory: &isDirectory) else {
            return
        }

        if isDirectory.boolValue {
            collectSessionFiles(in: canonical, seen: &seen, into: &urls)
            return
        }

        guard profile.matchesCandidateFile(canonical) else {
            return
        }

        appendIfNeeded(canonical, seen: &seen, into: &urls)
    }

    private func collectSessionFiles(in root: URL, seen: inout Set<String>, into urls: inout [URL]) {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for case let itemURL as URL in enumerator {
            let canonical = TokenCostPathUtilities.canonicalURL(itemURL)
            guard TokenCostPathUtilities.isDescendant(canonical, of: root) else {
                continue
            }
            guard profile.matchesCandidateFile(canonical) else {
                continue
            }
            appendIfNeeded(canonical, seen: &seen, into: &urls)
        }
    }

    private func appendIfNeeded(_ url: URL, seen: inout Set<String>, into urls: inout [URL]) {
        let key = TokenCostPathUtilities.canonicalURL(url).path
        guard seen.insert(key).inserted else {
            return
        }
        urls.append(TokenCostPathUtilities.canonicalURL(url))
    }

    private func parseSessionFile(_ url: URL) -> CodexSessionSummary? {
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            var accumulator = SessionAccumulator()
            accumulator.updatedAt = modificationTimestamp(for: url) ?? ISO8601DateFormatter().string(from: Date())

            for line in contents.split(whereSeparator: \.isNewline) {
                guard let data = line.data(using: .utf8),
                      let event = try? decoder.decode(SessionLine.self, from: data) else {
                    continue
                }

                switch event.type {
                case "session_meta":
                    if event.payload.id != nil || event.payload.agentNickname != nil || event.payload.timestamp != nil {
                        accumulator.apply(sessionMeta: event.payload, fallbackPath: url)
                        let timestamp = event.payload.timestamp ?? event.timestamp
                        accumulator.startedAt = accumulator.startedAt ?? timestamp
                    }
                case "event_msg":
                    if event.payload.payloadType == "token_count" {
                        accumulator.tokenCountEvents += 1
                        accumulator.updatedAt = event.timestamp
                        if let info = event.payload.info,
                           let usage = info.totalTokenUsage ?? info.lastTokenUsage {
                            accumulator.validTokenCountEvents += 1
                            accumulator.usage = CodexTokenUsage(
                                inputTokens: usage.inputTokens ?? 0,
                                cachedInputTokens: usage.cachedInputTokens ?? 0,
                                outputTokens: usage.outputTokens ?? 0,
                                reasoningOutputTokens: usage.reasoningOutputTokens ?? 0,
                                totalTokens: usage.totalTokens ?? 0
                            )
                            accumulator.planType = event.payload.rateLimits?.planType ?? accumulator.planType
                            accumulator.modelContextWindow = info.modelContextWindow ?? accumulator.modelContextWindow
                        } else if accumulator.planType == nil {
                            accumulator.planType = event.payload.rateLimits?.planType
                        }
                    }
                default:
                    continue
                }
            }

            guard accumulator.hasAnyData else {
                return nil
            }

            let sessionID = accumulator.sessionID.isEmpty ? TokenCostPaths.stableIdentifier(for: TokenCostPathUtilities.canonicalURL(url).path) : accumulator.sessionID
            let shortID = String(sessionID.prefix(8))
            let label = accumulator.agentNickname?.isEmpty == false
                ? "\(accumulator.agentNickname!) · \(shortID)"
                : shortID

            return CodexSessionSummary(
                sessionID: sessionID,
                label: label,
                agentNickname: accumulator.agentNickname,
                startedAt: accumulator.startedAt,
                updatedAt: accumulator.updatedAt,
                planType: accumulator.planType,
                tokenCountEvents: accumulator.tokenCountEvents,
                validTokenCountEvents: accumulator.validTokenCountEvents,
                usage: accumulator.usage,
                modelContextWindow: accumulator.modelContextWindow
            )
        } catch {
            FileHandle.standardError.write(Data("Skipping Codex session file \(url.path): \(error.localizedDescription)\n".utf8))
            return nil
        }
    }

    private func buildPayload(from sessions: [CodexSessionSummary]) -> CodexDashboardPayload {
        let sortedSessions = sessions.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
            return lhs.updatedAt > rhs.updatedAt
        }

        let summary = sortedSessions.reduce(into: CodexDashboardPayload.Summary(
            sessionCount: 0,
            tokenCountEvents: 0,
            validTokenCountEvents: 0,
            totalInputTokens: 0,
            totalCachedInputTokens: 0,
            totalOutputTokens: 0,
            totalReasoningOutputTokens: 0,
            totalTokens: 0,
            planTypeCounts: [:],
            firstSessionStartedAt: nil,
            lastSessionUpdatedAt: nil,
            sourceRootLabel: sourceDescription(),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )) { result, session in
            result.sessionCount += 1
            result.tokenCountEvents += session.tokenCountEvents
            result.validTokenCountEvents += session.validTokenCountEvents
            result.totalInputTokens += session.usage.inputTokens
            result.totalCachedInputTokens += session.usage.cachedInputTokens
            result.totalOutputTokens += session.usage.outputTokens
            result.totalReasoningOutputTokens += session.usage.reasoningOutputTokens
            result.totalTokens += session.usage.totalTokens
            if let planType = session.planType, !planType.isEmpty {
                result.planTypeCounts[planType, default: 0] += 1
            }
            if let startedAt = session.startedAt {
                if let current = result.firstSessionStartedAt {
                    result.firstSessionStartedAt = min(current, startedAt)
                } else {
                    result.firstSessionStartedAt = startedAt
                }
            }
            if let current = result.lastSessionUpdatedAt {
                result.lastSessionUpdatedAt = max(current, session.updatedAt)
            } else {
                result.lastSessionUpdatedAt = session.updatedAt
            }
        }

        return CodexDashboardPayload(summary: summary, sessions: sortedSessions)
    }

    private func sourceDescription() -> String {
        let roots = effectiveSourceRoots.isEmpty
            ? [profile.sourceRootsLabel]
            : effectiveSourceRoots.map { TokenCostPathUtilities.canonicalURL($0).path }
        let manuals = effectiveManualSourcePaths.map { TokenCostPathUtilities.canonicalURL($0).path }
        let parts = roots + manuals
        return parts.joined(separator: " · ")
    }

    private var effectiveSourceRoots: [URL] {
        deduplicatedURLs(from: sourceRoots + profile.defaultSourceRoots.map { TokenCostPathUtilities.expandedURL(from: $0) })
    }

    private var effectiveManualSourcePaths: [URL] {
        deduplicatedURLs(from: manualSourcePaths + profile.defaultManualSourcePaths.map { TokenCostPathUtilities.expandedURL(from: $0) })
    }

    private func deduplicatedURLs(from urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var results: [URL] = []

        for url in urls {
            let canonical = TokenCostPathUtilities.canonicalURL(url)
            guard seen.insert(canonical.path).inserted else {
                continue
            }
            results.append(canonical)
        }

        return results
    }

    private func modificationTimestamp(for url: URL) -> String? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else {
            return nil
        }
        return ISO8601DateFormatter().string(from: date)
    }
}

private struct SessionLine: Decodable {
    var timestamp: String
    var type: String
    var payload: SessionLinePayload
}

private struct SessionLinePayload: Decodable {
    var payloadType: String?
    var info: TokenCountInfo?
    var rateLimits: TokenCountRateLimits?
    var id: String?
    var timestamp: String?
    var agentNickname: String?
    var originator: String?
    var modelProvider: String?

    private enum CodingKeys: String, CodingKey {
        case payloadType = "type"
        case info
        case rateLimits
        case id
        case timestamp
        case agentNickname
        case originator
        case modelProvider
    }
}

private struct TokenCountInfo: Decodable {
    var totalTokenUsage: TokenUsage?
    var lastTokenUsage: TokenUsage?
    var modelContextWindow: Int?
}

private struct TokenUsage: Decodable {
    var inputTokens: Double?
    var cachedInputTokens: Double?
    var outputTokens: Double?
    var reasoningOutputTokens: Double?
    var totalTokens: Double?
}

private struct TokenCountRateLimits: Decodable {
    var planType: String?
}

private struct SessionAccumulator {
    var sessionID: String = ""
    var agentNickname: String?
    var startedAt: String?
    var updatedAt: String = ""
    var planType: String?
    var tokenCountEvents: Int = 0
    var validTokenCountEvents: Int = 0
    var usage: CodexTokenUsage = .zero
    var modelContextWindow: Int?

    var hasAnyData: Bool {
        tokenCountEvents > 0
    }

    mutating func apply(sessionMeta: SessionLinePayload, fallbackPath: URL) {
        if let id = sessionMeta.id, !id.isEmpty {
            sessionID = id
        }
        if let nickname = sessionMeta.agentNickname, !nickname.isEmpty {
            agentNickname = nickname
        }
        if let timestamp = sessionMeta.timestamp, !timestamp.isEmpty {
            startedAt = timestamp
        }
        if sessionID.isEmpty {
            sessionID = TokenCostPaths.stableIdentifier(for: TokenCostPathUtilities.canonicalURL(fallbackPath).path)
        }
    }
}
