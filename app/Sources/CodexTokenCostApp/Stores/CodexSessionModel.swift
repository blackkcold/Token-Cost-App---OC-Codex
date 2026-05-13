import AppKit
import Foundation
import CodexTokenCostCore

@MainActor
final class CodexSessionModel: ObservableObject {
    @Published var settings: TokenCostSettings
    @Published var payload: CodexDashboardPayload?
    @Published var discoverySources: [TokenCostSource] = []
    @Published var isBootstrapping = false
    @Published var isRefreshing = false
    @Published var lastErrorMessage: String?
    @Published var statusMessage: String
    @Published var shouldPromptForSourceConfirmation = false

    private let fileManager = FileManager.default
    private let settingsStore: SettingsStore
    private let snapshotStore: CodexSnapshotStore
    private var didBootstrap = false

    init() {
        self.settingsStore = SettingsStore(
            runtimeRoot: CodexAppPaths.runtimeRoot,
            settingsRelativePath: "config/codex-settings.json",
            defaultSettings: { TokenCostSettings.codexDefaults() }
        )
        self.snapshotStore = CodexSnapshotStore(runtimeRoot: CodexAppPaths.runtimeRoot)
        let loadedSettings = settingsStore.load()
        self.settings = loadedSettings.sourceFamily == .codex ? loadedSettings : TokenCostSettings.codexDefaults()
        self.statusMessage = "等待初始化"
        try? CodexAppPaths.ensureRuntimeDirectories()
    }

    var canRefresh: Bool {
        !isRefreshing
    }

    var sourceRootsDescription: String {
        let roots = settings.effectiveSourceRoots
        if roots.isEmpty {
            return "未配置 session 目录"
        }
        return roots.joined(separator: " · ")
    }

    var manualSourcePathsDescription: String {
        let paths = settings.effectiveManualSourcePaths
        if paths.isEmpty {
            return "未添加手动 session 文件"
        }
        return paths.joined(separator: " · ")
    }

    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        Task { @MainActor in await bootstrap() }
    }

    func refreshIfNeeded() {
        guard settings.autoRescan else { return }
        if let payload, payload.summary.sessionCount > 0 {
            return
        }
        refresh()
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        statusMessage = "正在刷新 Codex…"
        lastErrorMessage = nil
        shouldPromptForSourceConfirmation = false

        let currentSettings = settings
        refreshDiscoverySources(using: currentSettings)

        Task.detached(priority: .userInitiated) { [weak self, currentSettings] in
            do {
                let payload = try CodexHelperRunner.loadPayload(settings: currentSettings)
                await MainActor.run { [weak self] in
                    guard let self else {
                        return
                    }
                    self.payload = payload
                    try? self.snapshotStore.saveLatest(
                        payload,
                        settings: currentSettings,
                        retention: currentSettings.snapshotRetentionCount
                    )
                    self.statusMessage = "已刷新 Codex"
                    self.lastErrorMessage = nil
                    self.shouldPromptForSourceConfirmation = payload.summary.sessionCount == 0
                    self.refreshDiscoverySources(using: currentSettings)
                    self.isRefreshing = false
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run { [weak self] in
                    guard let self else {
                        return
                    }
                    self.payload = self.snapshotStore.loadLatest(settings: currentSettings) ?? self.payload
                    self.lastErrorMessage = message
                    self.statusMessage = "刷新失败"
                    self.shouldPromptForSourceConfirmation = (self.payload?.summary.sessionCount ?? 0) == 0
                    self.refreshDiscoverySources(using: currentSettings)
                    self.isRefreshing = false
                }
            }
        }
    }

    func updateSettings(_ mutate: (inout TokenCostSettings) -> Void) {
        mutate(&settings)
        normalizeSettings()
        persistSettings()
        refreshDiscoverySources()
        shouldPromptForSourceConfirmation = (payload?.summary.sessionCount ?? 0) == 0
    }

    func addSourceRoot() {
        let panel = NSOpenPanel()
        panel.title = "选择 Codex session 目录"
        panel.prompt = "添加目录"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.message = "选择包含 Codex session JSONL 文件的目录。"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let canonicalPath = TokenCostPathUtilities.canonicalURL(url).path
        guard !settings.effectiveSourceRoots.contains(canonicalPath) else {
            return
        }

        settings.sourceRoots.append(canonicalPath)
        persistSettings()
        refreshDiscoverySources()
        refresh()
    }

    func addSourceFile() {
        let panel = NSOpenPanel()
        panel.title = "选择 Codex session 文件"
        panel.prompt = "添加文件"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.message = "选择单个 Codex session JSONL 文件。"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let canonicalPath = TokenCostPathUtilities.canonicalURL(url).path
        guard !settings.effectiveManualSourcePaths.contains(canonicalPath) else {
            return
        }

        settings.manualSourcePaths.append(canonicalPath)
        persistSettings()
        refreshDiscoverySources()
        refresh()
    }

    func removeSourceRoot(at offsets: IndexSet) {
        settings.sourceRoots.remove(atOffsets: offsets)
        persistSettings()
        refreshDiscoverySources()
        refresh()
    }

    func removeSourcePath(at offsets: IndexSet) {
        settings.manualSourcePaths.remove(atOffsets: offsets)
        persistSettings()
        refreshDiscoverySources()
        refresh()
    }

    func resetSettingsToDefaults() {
        settings = TokenCostSettings.codexDefaults()
        persistSettings()
        refreshDiscoverySources()
        refresh()
    }

    private func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }

        statusMessage = "正在初始化…"
        do {
            try CodexAppPaths.ensureRuntimeDirectories()
        } catch {
            lastErrorMessage = error.localizedDescription
        }

        settings = settingsStore.load()
        normalizeSettings()
        persistSettings()
        payload = snapshotStore.loadLatest(settings: settings)
        refreshDiscoverySources()

        if settings.autoRescan {
            refresh()
        } else if payload == nil {
            shouldPromptForSourceConfirmation = true
            statusMessage = "等待手动刷新"
        } else {
            shouldPromptForSourceConfirmation = (payload?.summary.sessionCount ?? 0) == 0
            statusMessage = "已加载本地快照"
        }
    }

    private func normalizeSettings() {
        if settings.sourceFamily != .codex {
            settings.sourceFamily = .codex
        }
        settings.snapshotRetentionCount = min(max(settings.snapshotRetentionCount, 1), 20)
        settings.sourceRoots = deduplicatedCanonicalPaths(from: settings.sourceRoots)
        settings.manualSourcePaths = deduplicatedCanonicalPaths(from: settings.manualSourcePaths)
    }

    private func deduplicatedCanonicalPaths(from paths: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []
        for path in paths {
            let canonical = TokenCostPathUtilities.canonicalPathString(from: path)
            guard seen.insert(canonical).inserted else {
                continue
            }
            results.append(canonical)
        }
        return results
    }

    private func persistSettings() {
        normalizeSettings()
        try? settingsStore.save(settings)
    }

    private func refreshDiscoverySources(using currentSettings: TokenCostSettings? = nil) {
        let settings = currentSettings ?? self.settings
        discoverySources = buildDiscoverySources(for: settings)
    }

    private func buildDiscoverySources(for settings: TokenCostSettings) -> [TokenCostSource] {
        let profile = settings.profile
        var seenIDs = Set<String>()
        var sources: [TokenCostSource] = []

        for root in settings.effectiveSourceRoots {
            appendDirectorySources(
                for: root,
                profile: profile,
                maxDepth: settings.maxScanDepth,
                maxCandidates: settings.maxScanCandidates,
                seenIDs: &seenIDs,
                into: &sources
            )
        }

        for path in settings.effectiveManualSourcePaths {
            appendManualSource(
                for: path,
                profile: profile,
                seenIDs: &seenIDs,
                into: &sources
            )
        }

        return sources.sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return statusRank(lhs.status) < statusRank(rhs.status)
        }
    }

    private func appendDirectorySources(
        for path: String,
        profile: TokenCostSourceProfile,
        maxDepth: Int,
        maxCandidates: Int,
        seenIDs: inout Set<String>,
        into sources: inout [TokenCostSource]
    ) {
        let normalized = TokenCostPathUtilities.canonicalURL(from: path)
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: normalized.path, isDirectory: &isDirectory)

        guard exists else {
            appendIfNeeded(
                makeCodexSource(
                    sourceURL: normalized,
                    locationURL: normalized,
                    locationKind: .directory,
                    profile: profile,
                    status: .missing,
                    statusMessage: "默认位置尚未创建",
                    isDefault: true
                ),
                seenIDs: &seenIDs,
                into: &sources
            )
            return
        }

        if isDirectory.boolValue {
            let discoveredFiles = discoverSessionFiles(
                in: normalized,
                profile: profile,
                maxDepth: maxDepth,
                maxCandidates: maxCandidates
            )

            if discoveredFiles.isEmpty {
                appendIfNeeded(
                    makeCodexSource(
                        sourceURL: normalized,
                        locationURL: normalized,
                        locationKind: .directory,
                        profile: profile,
                        status: .missing,
                        statusMessage: "目录存在，但未发现 session 文件",
                        isDefault: true
                    ),
                    seenIDs: &seenIDs,
                    into: &sources
                )
                return
            }

            for fileURL in discoveredFiles {
                appendIfNeeded(
                    makeCodexSource(
                        sourceURL: fileURL,
                        locationURL: normalized,
                        locationKind: .file,
                        profile: profile,
                        status: fileStatus(for: fileURL, profile: profile),
                        statusMessage: fileStatusMessage(for: fileURL, profile: profile),
                        isDefault: false
                    ),
                    seenIDs: &seenIDs,
                    into: &sources
                )
            }
            return
        }

        appendManualSource(
            for: normalized.path,
            profile: profile,
            seenIDs: &seenIDs,
            into: &sources
        )
    }

    private func appendManualSource(
        for path: String,
        profile: TokenCostSourceProfile,
        seenIDs: inout Set<String>,
        into sources: inout [TokenCostSource]
    ) {
        let normalized = TokenCostPathUtilities.canonicalURL(from: path)
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: normalized.path, isDirectory: &isDirectory)

        if exists == false {
            appendIfNeeded(
                makeCodexSource(
                    sourceURL: normalized,
                    locationURL: normalized,
                    locationKind: .file,
                    profile: profile,
                    status: .missing,
                    statusMessage: "路径不存在",
                    isDefault: false
                ),
                seenIDs: &seenIDs,
                into: &sources
            )
            return
        }

        if isDirectory.boolValue {
            let discoveredFiles = discoverSessionFiles(
                in: normalized,
                profile: profile,
                maxDepth: profile.maxScanDepth,
                maxCandidates: profile.maxScanCandidates
            )

            if discoveredFiles.isEmpty {
                appendIfNeeded(
                    makeCodexSource(
                        sourceURL: normalized,
                        locationURL: normalized,
                        locationKind: .directory,
                        profile: profile,
                        status: .missing,
                        statusMessage: "目录存在，但未发现 session 文件",
                        isDefault: false
                    ),
                    seenIDs: &seenIDs,
                    into: &sources
                )
                return
            }

            for fileURL in discoveredFiles {
                appendIfNeeded(
                    makeCodexSource(
                        sourceURL: fileURL,
                        locationURL: normalized,
                        locationKind: .file,
                        profile: profile,
                        status: fileStatus(for: fileURL, profile: profile),
                        statusMessage: fileStatusMessage(for: fileURL, profile: profile),
                        isDefault: false
                    ),
                    seenIDs: &seenIDs,
                    into: &sources
                )
            }
            return
        }

        appendIfNeeded(
            makeCodexSource(
                sourceURL: normalized,
                locationURL: normalized,
                locationKind: .file,
                profile: profile,
                status: fileStatus(for: normalized, profile: profile),
                statusMessage: fileStatusMessage(for: normalized, profile: profile),
                isDefault: false
            ),
            seenIDs: &seenIDs,
            into: &sources
        )
    }

    private func appendIfNeeded(
        _ source: TokenCostSource,
        seenIDs: inout Set<String>,
        into sources: inout [TokenCostSource]
    ) {
        guard seenIDs.insert(source.id).inserted else {
            return
        }
        sources.append(source)
    }

    private func discoverSessionFiles(
        in root: URL,
        profile: TokenCostSourceProfile,
        maxDepth: Int,
        maxCandidates: Int
    ) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let itemURL as URL in enumerator {
            let canonical = TokenCostPathUtilities.canonicalURL(itemURL)
            guard TokenCostPathUtilities.isDescendant(canonical, of: root) else {
                continue
            }
            let relativeDepth = canonical.pathComponents.count - root.pathComponents.count
            if relativeDepth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            guard profile.matchesCandidateFile(canonical) else {
                continue
            }

            results.append(canonical)
            if results.count >= maxCandidates {
                break
            }
        }
        return results.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if lhsDate == rhsDate {
                return lhs.path < rhs.path
            }
            return lhsDate > rhsDate
        }
    }

    private func makeCodexSource(
        sourceURL: URL,
        locationURL: URL?,
        locationKind: TokenCostSourceLocationKind,
        profile: TokenCostSourceProfile,
        status: TokenCostSourceStatus,
        statusMessage: String,
        isDefault: Bool
    ) -> TokenCostSource {
        let normalized = TokenCostPathUtilities.canonicalURL(sourceURL)
        return TokenCostSource(
            id: TokenCostPaths.stableIdentifier(for: normalized.path),
            name: displayName(for: normalized, kind: locationKind, isDefault: isDefault),
            sourceFamily: profile.family,
            locationKind: locationKind,
            sourceURL: normalized,
            locationURL: locationURL.map(TokenCostPathUtilities.canonicalURL),
            status: status,
            statusMessage: statusMessage,
            lastModified: modificationDate(for: normalized),
            isReadOnly: true
        )
    }

    private func fileStatus(for url: URL, profile: TokenCostSourceProfile) -> TokenCostSourceStatus {
        guard profile.matchesCandidateFile(url) else {
            return .unsupported
        }
        if fileManager.isReadableFile(atPath: url.path) {
            return .available
        }
        return .locked
    }

    private func fileStatusMessage(for url: URL, profile: TokenCostSourceProfile) -> String {
        guard profile.matchesCandidateFile(url) else {
            return "文件格式不匹配"
        }
        if fileManager.isReadableFile(atPath: url.path) {
            return "可直接读取"
        }
        return "文件存在，但当前不可读"
    }

    private func displayName(for url: URL, kind: TokenCostSourceLocationKind, isDefault: Bool) -> String {
        if isDefault {
            return url.lastPathComponent.isEmpty ? settings.profile.sourceRootsLabel : url.lastPathComponent
        }
        switch kind {
        case .directory:
            return url.lastPathComponent.isEmpty ? "session 目录" : url.lastPathComponent
        case .file:
            let fileName = url.deletingPathExtension().lastPathComponent
            return fileName.isEmpty ? url.lastPathComponent : fileName
        }
    }

    private func modificationDate(for url: URL) -> String? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else {
            return nil
        }
        return ISO8601DateFormatter().string(from: date)
    }

    private func statusRank(_ status: TokenCostSourceStatus) -> Int {
        switch status {
        case .available: return 0
        case .locked: return 1
        case .unsupported: return 2
        case .missing: return 3
        case .unknown: return 4
        }
    }
}
