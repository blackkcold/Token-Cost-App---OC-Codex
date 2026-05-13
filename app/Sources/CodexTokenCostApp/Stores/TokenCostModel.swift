import AppKit
import Foundation
import CodexTokenCostCore
import SwiftUI

@MainActor
final class TokenCostModel: ObservableObject {
    @Published var settings: TokenCostSettings
    @Published var sources: [TokenCostSource] = []
    @Published var selectedSourceID: String?
    @Published var payloadsBySourceID: [String: DashboardPayload] = [:]
    @Published var isBootstrapping = false
    @Published var isRefreshing = false
    @Published var lastErrorMessage: String?
    @Published var statusMessage: String

    private let settingsStore: SettingsStore
    private let snapshotStore: SnapshotStore
    private var didBootstrap = false

    init() {
        self.settingsStore = SettingsStore(runtimeRoot: CodexAppPaths.runtimeRoot)
        self.snapshotStore = SnapshotStore(runtimeRoot: CodexAppPaths.runtimeRoot)
        let loadedSettings = settingsStore.load()
        self.settings = loadedSettings
        self.selectedSourceID = loadedSettings.selectedSourceID
        self.statusMessage = "等待初始化"
        try? CodexAppPaths.ensureRuntimeDirectories()
    }

    var selectedSource: TokenCostSource? {
        guard let selectedSourceID else { return nil }
        return sources.first(where: { $0.id == selectedSourceID })
    }

    var selectedPayload: DashboardPayload? {
        guard let selectedSourceID else { return nil }
        return payloadsBySourceID[selectedSourceID]
    }

    var hasSources: Bool {
        !sources.isEmpty
    }

    var canRefreshSelectedSource: Bool {
        selectedSource?.isAvailable == true && !isRefreshing
    }

    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        Task { @MainActor in await bootstrap() }
    }

    func refreshSelectedSourceIfNeeded() {
        guard selectedPayload == nil else { return }
        refreshSelectedSource()
    }

    func rescanSources() {
        Task { @MainActor in await rescanSourcesAndRestoreSelection(triggerRefresh: true) }
    }

    func refreshSelectedSource() {
        guard !isRefreshing, let source = selectedSource else {
            return
        }

        guard source.isAvailable else {
            lastErrorMessage = source.statusMessage
            statusMessage = source.statusMessage
            if let cached = snapshotStore.loadLatest(sourceID: source.id) {
                payloadsBySourceID[source.id] = cached
            }
            return
        }

        isRefreshing = true
        statusMessage = "正在刷新 \(source.name)…"
        lastErrorMessage = nil

        let databasePath = source.databaseURL.path
        let sourceID = source.id
        let sourceName = source.name
        let snapshotRetention = settings.snapshotRetentionCount

        Task.detached(priority: .userInitiated) { [weak self, databasePath, sourceID, sourceName, snapshotRetention] in
            do {
                let payload = try TokenDatabaseClient().loadPayload(from: URL(fileURLWithPath: databasePath))
                await MainActor.run { [weak self] in
                    guard let self else {
                        return
                    }
                    self.payloadsBySourceID[sourceID] = payload
                    try? self.snapshotStore.saveLatest(payload, sourceID: sourceID, retention: snapshotRetention)
                    if self.selectedSourceID == sourceID {
                        self.statusMessage = "已刷新 \(sourceName)"
                    }
                    self.lastErrorMessage = nil
                    self.isRefreshing = false
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run { [weak self] in
                    guard let self else {
                        return
                    }
                    self.lastErrorMessage = message
                    self.statusMessage = "刷新失败"
                    self.isRefreshing = false
                }
            }
        }
    }

    func selectSource(id: String?) {
        selectedSourceID = id
        settings.selectedSourceID = id
        persistSettings()

        if let id, let cached = snapshotStore.loadLatest(sourceID: id) {
            payloadsBySourceID[id] = cached
        }

        if let source = selectedSource, source.isAvailable {
            refreshSelectedSource()
        } else if let source = selectedSource {
            lastErrorMessage = source.statusMessage
            statusMessage = source.statusMessage
        }
    }

    func addScanRoot() {
        let panel = NSOpenPanel()
        panel.title = "选择 OpenCode 安装目录"
        panel.prompt = "添加目录"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.message = "选择包含 OpenCode 或 OpenCode Desktop 数据库的目录。"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let path = url.path
        guard !settings.scanRoots.contains(path) else {
            return
        }

        settings.scanRoots.append(path)
        persistSettings()
        rescanSources()
    }

    func addDatabaseFile() {
        let panel = NSOpenPanel()
        panel.title = "选择数据库文件"
        panel.prompt = "添加文件"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = []
        panel.message = "选择单个 OpenCode 数据库文件。"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let path = url.path
        guard !settings.manualDatabasePaths.contains(path) else {
            return
        }

        settings.manualDatabasePaths.append(path)
        persistSettings()
        rescanSources()
    }

    func removeScanRoot(at offsets: IndexSet) {
        settings.scanRoots.remove(atOffsets: offsets)
        persistSettings()
        rescanSources()
    }

    func removeDatabasePath(at offsets: IndexSet) {
        settings.manualDatabasePaths.remove(atOffsets: offsets)
        persistSettings()
        rescanSources()
    }

    func resetSettingsToDefaults() {
        settings = TokenCostSettings()
        selectedSourceID = nil
        settings.selectedSourceID = nil
        payloadsBySourceID.removeAll()
        persistSettings()
        rescanSources()
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
        selectedSourceID = settings.selectedSourceID
        await rescanSourcesAndRestoreSelection(triggerRefresh: true)
    }

    private func rescanSourcesAndRestoreSelection(triggerRefresh: Bool) async {
        statusMessage = "正在扫描来源…"
        let currentSettings = settings
        let discovered = await Task.detached(priority: .userInitiated) {
            SourceDiscoveryService().discover(settings: currentSettings)
        }.value

        sources = discovered

        let preferredSelection: String? = {
            if let selectedSourceID, discovered.contains(where: { $0.id == selectedSourceID }) {
                return selectedSourceID
            }
            if let saved = settings.selectedSourceID, discovered.contains(where: { $0.id == saved }) {
                return saved
            }
            return discovered.first?.id
        }()

        selectedSourceID = preferredSelection
        settings.selectedSourceID = preferredSelection
        persistSettings()

        if let selectedSourceID {
            if let cached = snapshotStore.loadLatest(sourceID: selectedSourceID) {
                payloadsBySourceID[selectedSourceID] = cached
            }
        }

        if triggerRefresh {
            if let source = selectedSource, source.isAvailable {
                refreshSelectedSource()
            } else if let source = selectedSource {
                lastErrorMessage = source.statusMessage
                statusMessage = source.statusMessage
            } else {
                statusMessage = "未发现可用数据库"
            }
        }
    }

    private func persistSettings() {
        settings.maxScanDepth = max(settings.maxScanDepth, 1)
        settings.maxScanCandidates = max(settings.maxScanCandidates, 1)
        settings.snapshotRetentionCount = min(max(settings.snapshotRetentionCount, 1), 20)
        try? settingsStore.save(settings)
    }

    func updateSettings(_ mutate: (inout TokenCostSettings) -> Void) {
        mutate(&settings)
        persistSettings()
    }
}
