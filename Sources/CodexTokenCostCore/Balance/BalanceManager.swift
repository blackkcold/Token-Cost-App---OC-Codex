import Foundation
import Combine

@MainActor
public final class BalanceManager: ObservableObject {
    private let checkers: [BalanceChecker]
    @Published public private(set) var snapshots: [BalanceSnapshot] = []
    @Published public private(set) var lastRefreshTime: Date?
    @Published public private(set) var isRefreshing: Bool = false
    private var consecutiveFailures: Int = 0

    public init(checkers: [BalanceChecker] = [
        OpenCodeGoBalanceChecker(),
        CodexBalanceChecker(),
        OpenCodeZenBalanceChecker()
    ]) {
        self.checkers = checkers
    }

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true

        if consecutiveFailures > 0, let lastRefreshTime {
            let backoff = backoffSeconds()
            if Date().timeIntervalSince(lastRefreshTime) < Double(backoff) {
                isRefreshing = false
                return
            }
        }

        let now = Date()
        let currentCheckers = checkers

        let (results, anySucceeded): ([BalanceSnapshot], Bool) = await withTaskGroup(
            of: BalanceSnapshot.self,
            returning: ([BalanceSnapshot], Bool).self
        ) { group in
            for checker in currentCheckers {
                group.addTask {
                    guard let token = AuthTokenProvider.token(for: checker.providerKind) else {
                        return BalanceSnapshot.unavailable(checker.providerKind, reason: "未找到认证信息")
                    }
                    do {
                        return try await checker.fetch(authToken: token)
                    } catch {
                        return BalanceSnapshot.unavailable(checker.providerKind, reason: error.localizedDescription)
                    }
                }
            }

            var snapshots: [BalanceSnapshot] = []
            var succeeded = false
            for await snapshot in group {
                if snapshot.isAvailable { succeeded = true }
                snapshots.append(snapshot)
            }
            return (snapshots, succeeded)
        }

        snapshots = results
        lastRefreshTime = now

        if anySucceeded {
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
        }

        isRefreshing = false
    }

    /// Test-only: fetch a snapshot for a single provider bypassing
    /// refresh backoff, concurrency guard, and global state.
    /// Uses the provided checker and auth token directly.
    public func testSnapshot(for checker: BalanceChecker, authToken: String) async -> BalanceSnapshot {
        do {
            return try await checker.fetch(authToken: authToken)
        } catch {
            return BalanceSnapshot.unavailable(checker.providerKind, reason: error.localizedDescription)
        }
    }

    public func shouldRefresh(intervalMinutes: Int) -> Bool {
        guard let lastRefreshTime else { return true }
        let elapsed = Date().timeIntervalSince(lastRefreshTime)
        return elapsed >= Double(intervalMinutes * 60)
    }

    private func backoffSeconds() -> UInt64 {
        let seconds = min(60 * pow(2.0, Double(consecutiveFailures)), 30 * 60)
        return UInt64(seconds)
    }
}
