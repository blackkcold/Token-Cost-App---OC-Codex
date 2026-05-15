import Foundation

public enum TokenCostSourceFamily: String, Codable, CaseIterable, Sendable {
    case opencode
    case codex

    public var displayName: String {
        switch self {
        case .opencode:
            return "OpenCode"
        case .codex:
            return "Codex"
        }
    }
}

public enum TokenCostSourceLocationKind: String, Codable, CaseIterable, Sendable {
    case file
    case directory

    public var displayName: String {
        switch self {
        case .file:
            return "文件"
        case .directory:
            return "目录"
        }
    }
}

public struct TokenCostSourceProfile: Hashable, Sendable {
    public var family: TokenCostSourceFamily
    public var displayName: String
    public var sourceRootsLabel: String
    public var manualEntriesLabel: String
    public var defaultSourceRoots: [String]
    public var defaultManualSourcePaths: [String]
    public var filenameHints: [String]
    public var allowedExtensions: Set<String>
    public var preferredLocationKind: TokenCostSourceLocationKind
    public var maxScanDepth: Int
    public var maxScanCandidates: Int

    public init(
        family: TokenCostSourceFamily,
        displayName: String,
        sourceRootsLabel: String,
        manualEntriesLabel: String,
        defaultSourceRoots: [String],
        defaultManualSourcePaths: [String],
        filenameHints: [String],
        allowedExtensions: Set<String>,
        preferredLocationKind: TokenCostSourceLocationKind,
        maxScanDepth: Int,
        maxScanCandidates: Int
    ) {
        self.family = family
        self.displayName = displayName
        self.sourceRootsLabel = sourceRootsLabel
        self.manualEntriesLabel = manualEntriesLabel
        self.defaultSourceRoots = defaultSourceRoots
        self.defaultManualSourcePaths = defaultManualSourcePaths
        self.filenameHints = filenameHints
        self.allowedExtensions = allowedExtensions
        self.preferredLocationKind = preferredLocationKind
        self.maxScanDepth = maxScanDepth
        self.maxScanCandidates = maxScanCandidates
    }

    public static let opencode = TokenCostSourceProfile(
        family: .opencode,
        displayName: "OpenCode",
        sourceRootsLabel: "安装目录",
        manualEntriesLabel: "数据库文件",
        defaultSourceRoots: [
            "~/.local/share/opencode",
            "~/Library/Application Support/OpenCode",
            "~/Library/Application Support/OpenCode Desktop",
            "~/Library/Application Support/opencode"
        ],
        defaultManualSourcePaths: [
            "~/.local/share/opencode/opencode.db"
        ],
        filenameHints: ["opencode", "open-code", "open code", "desktop"],
        allowedExtensions: ["db", "sqlite", "sqlite3"],
        preferredLocationKind: .directory,
        maxScanDepth: 3,
        maxScanCandidates: 32
    )

    public static let codex = TokenCostSourceProfile(
        family: .codex,
        displayName: "Codex",
        sourceRootsLabel: "session 目录",
        manualEntriesLabel: "session 文件",
        defaultSourceRoots: [
            "~/.codex/sessions",
            "~/.codex/archived_sessions"
        ],
        defaultManualSourcePaths: [],
        filenameHints: ["codex", "session"],
        allowedExtensions: ["jsonl"],
        preferredLocationKind: .directory,
        maxScanDepth: 6,
        maxScanCandidates: 256
    )

    public static func profile(for family: TokenCostSourceFamily) -> TokenCostSourceProfile {
        switch family {
        case .opencode:
            return .opencode
        case .codex:
            return .codex
        }
    }

    public func matchesCandidateFile(_ url: URL) -> Bool {
        let fileName = url.lastPathComponent.lowercased()
        let extensionName = url.pathExtension.lowercased()

        guard allowedExtensions.isEmpty == false else {
            return true
        }
        guard allowedExtensions.contains(extensionName) else {
            return false
        }

        switch family {
        case .codex:
            return true
        case .opencode:
            if filenameHints.isEmpty {
                return true
            }
            return filenameHints.contains { fileName.contains($0) } || fileName == "opencode.db"
        }
    }
}
