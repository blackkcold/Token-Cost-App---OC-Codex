import Foundation
import AppKit
import CodexTokenCostCore

@MainActor
final class UpdateCheckerModel: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case noUpdate
        case updateAvailable(version: String)
        case downloading(progress: Double)
        case downloadComplete
        case error(message: String)
    }

    @Published var state: State = .idle
    @Published var latestVersion: String = ""

    private var releasePageURL: URL?
    private var releaseAssetURL: URL?

    var errorMessage: String {
        if case .error(let msg) = state { return msg }
        return ""
    }

    // MARK: - Check

    func checkForUpdate() {
        // Respect 24h cache
        if let cache = UpdateChecker.loadCache() {
            if !UpdateChecker.shouldCheckAgain(lastCheck: cache.lastCheckDate) {
                // Within cache window — use last known version
                if UpdateChecker.isUpdateAvailable(latestVersion: cache.lastSeenVersion) {
                    latestVersion = cache.lastSeenVersion
                    state = .updateAvailable(version: cache.lastSeenVersion)
                }
                return
            }
        }

        state = .checking

        Task { [weak self] in
            guard let self else { return }
            do {
                guard let release = try await UpdateChecker.checkLatestRelease() else {
                    self.state = .noUpdate
                    return
                }

                let cache = UpdateCheckCache(
                    lastCheckDate: Date(),
                    lastSeenVersion: release.tagName
                )
                UpdateChecker.saveCache(cache)

                if UpdateChecker.isUpdateAvailable(latestVersion: release.tagName) {
                    self.latestVersion = release.tagName
                    self.releasePageURL = URL(string: release.htmlUrl)

                    if let zipAsset = UpdateChecker.findZipAsset(in: release) {
                        self.releaseAssetURL = URL(string: zipAsset.browserDownloadUrl)
                    }

                    self.state = .updateAvailable(version: release.tagName)
                } else {
                    self.state = .noUpdate
                }
            } catch {
                // Network errors → silently stay idle/no-update
                print("[UpdateCheckerModel] Check failed: \(error.localizedDescription)")
                self.state = .noUpdate
            }
        }
    }

    // MARK: - Download

    func startDownload() {
        guard let url = releaseAssetURL else {
            state = .error(message: "No download URL available")
            return
        }

        state = .downloading(progress: 0)

        Task { [weak self] in
            guard let self else { return }
            do {
                let _ = try await UpdateChecker.downloadUpdate(from: url) { progress in
                    Task { @MainActor [weak self] in
                        self?.state = .downloading(progress: progress)
                    }
                }
                self.state = .downloadComplete
            } catch {
                print("[UpdateCheckerModel] Download failed: \(error.localizedDescription)")
                self.state = .error(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Install

    func openDownloadedApp() {
        guard let appURL = UpdateChecker.downloadedAppURL() else {
            state = .error(message: "Downloaded app not found")
            return
        }

        print("[UpdateCheckerModel] Opening downloaded app: \(appURL.path)")
        NSWorkspace.shared.open(appURL)
    }

    // MARK: - Open release page (fallback)

    func openReleasePage() {
        guard let url = releasePageURL else { return }
        NSWorkspace.shared.open(url)
    }
}
