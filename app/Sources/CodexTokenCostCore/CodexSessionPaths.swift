import Foundation

public enum CodexSessionPaths {
    public static let sessionsRootLabel = TokenCostSourceProfile.codex.sourceRootsLabel

    public static var sessionsRoot: URL {
        TokenCostPathUtilities.canonicalURL(from: TokenCostSourceProfile.codex.defaultSourceRoots.first ?? "~/.codex/sessions")
    }
}
