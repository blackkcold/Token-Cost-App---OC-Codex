import XCTest
import Security
import SQLite3
import CCryptoBridge
@testable import CodexTokenCostCore

final class CodexTokenCostCoreTests: XCTestCase {
    func testActualTokensSubtractCachedInputPerSession() {
        let usage = CodexTokenUsage(
            inputTokens: 100,
            cachedInputTokens: 25,
            outputTokens: 7,
            reasoningOutputTokens: 3,
            totalTokens: 135
        )

        XCTAssertEqual(usage.actualInputTokens, 75)
        XCTAssertEqual(usage.actualTokens, 85)
    }

    func testDashboardPayloadTotalActualInputTokens() {
        let payload = DashboardPayload(
            summary: DashboardPayload.Summary(
                totalTokens: 250,
                totalActualTokens: 999,
                totalCacheReadTokens: 40,
                totalCacheWriteTokens: 10,
                totalCacheTokens: 50,
                totalCost: 0,
                totalMessages: 2,
                activeDays: 1,
                dateRange: .init(start: "2026-05-15", end: "2026-05-15"),
                updatedAt: "2026-05-15T12:00:00Z"
            ),
            dailyTotals: [:],
            modelTotals: [:],
            providerCosts: [:],
            providerTotals: [:],
            rawData: [
                DashboardPayload.RawRow(
                    date: "2026-05-15",
                    model: "m1",
                    provider: "p1",
                    input: 120,
                    output: 10,
                    reasoning: 0,
                    cacheRead: 30,
                    cacheWrite: 5,
                    cacheWriteMissingCount: 0,
                    cacheWriteReportedCount: 1,
                    total: 135,
                    cost: 0,
                    msgCount: 1
                ),
                DashboardPayload.RawRow(
                    date: "2026-05-15",
                    model: "m2",
                    provider: "p2",
                    input: 80,
                    output: 5,
                    reasoning: 0,
                    cacheRead: 10,
                    cacheWrite: 5,
                    cacheWriteMissingCount: 0,
                    cacheWriteReportedCount: 1,
                    total: 90,
                    cost: 0,
                    msgCount: 1
                )
            ]
        )

        XCTAssertEqual(payload.totalInputTokens, 200)
        XCTAssertEqual(payload.totalActualInputTokens, 200)
    }

    func testDashboardSummaryTrendAndSessionsShareTheSameActualTokenMath() {
        let firstSession = makeSession(
            sessionID: "session-a",
            updatedAt: "2026-05-15T09:00:00Z",
            usage: CodexTokenUsage(
                inputTokens: 100,
                cachedInputTokens: 25,
                outputTokens: 7,
                reasoningOutputTokens: 3,
                totalTokens: 135
            )
        )
        let secondSession = makeSession(
            sessionID: "session-b",
            updatedAt: "2026-05-15T11:00:00Z",
            usage: CodexTokenUsage(
                inputTokens: 50,
                cachedInputTokens: 10,
                outputTokens: 1,
                reasoningOutputTokens: 0,
                totalTokens: 61
            )
        )

        let payload = CodexDashboardPayload(
            summary: CodexDashboardPayload.Summary(
                sessionCount: 2,
                tokenCountEvents: 2,
                validTokenCountEvents: 2,
                totalInputTokens: 150,
                totalCachedInputTokens: 35,
                totalOutputTokens: 8,
                totalReasoningOutputTokens: 3,
                totalTokens: 196,
                planTypeCounts: [:],
                firstSessionStartedAt: "2026-05-15T09:00:00Z",
                lastSessionUpdatedAt: "2026-05-15T11:00:00Z",
                sourceRootLabel: "Test",
                updatedAt: "2026-05-15T12:00:00Z"
            ),
            sessions: [firstSession, secondSession]
        )

        let trendPoints = CodexDashboardAnalytics.dailyTrendPoints(from: payload)
        let sessionActualTotal = payload.sessions.reduce(0) { $0 + $1.actualTokens }

        XCTAssertEqual(payload.summary.totalActualInputTokens, 115)
        XCTAssertEqual(payload.summary.totalActualTokens, 126)
        XCTAssertEqual(sessionActualTotal, 126)
        XCTAssertEqual(trendPoints.count, 1)
        XCTAssertEqual(trendPoints.first?.sessionCount, 2)
        XCTAssertEqual(trendPoints.first?.actualTokens, 126)
    }

    func testSortSessionsUsesUnifiedActualTokenMath() {
        let lowerNetActualButHigherRaw = makeSession(
            sessionID: "session-a",
            updatedAt: "2026-05-15T09:00:00Z",
            usage: CodexTokenUsage(
                inputTokens: 100,
                cachedInputTokens: 90,
                outputTokens: 0,
                reasoningOutputTokens: 0,
                totalTokens: 100
            )
        )
        let higherNetActualButLowerRaw = makeSession(
            sessionID: "session-b",
            updatedAt: "2026-05-15T11:00:00Z",
            usage: CodexTokenUsage(
                inputTokens: 15,
                cachedInputTokens: 0,
                outputTokens: 0,
                reasoningOutputTokens: 0,
                totalTokens: 15
            )
        )

        let sorted = CodexDashboardAnalytics.sortSessions(
            [lowerNetActualButHigherRaw, higherNetActualButLowerRaw],
            field: .actualTokens,
            direction: .descending
        )

        XCTAssertEqual(sorted.map(\.sessionId), ["session-b", "session-a"])
    }

    func testAppPreferencesDecodeOldConfigDefaultsBillingSelections() throws {
        let data = #"{"language":"zh-Hans","openCodePricingMode":"api"}"#.data(using: .utf8)!
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertEqual(preferences.language, .zhHans)
        XCTAssertEqual(preferences.openCodePricingMode, .api)
        XCTAssertEqual(preferences.resolvedBillingPlan(for: .opencode).monthlyUSD, 10)
        XCTAssertEqual(preferences.resolvedBillingPlan(for: .codex).monthlyUSD, 20)
        XCTAssertEqual(preferences.resolvedBillingPlan(for: .minimax).monthlyUSD ?? 0, 98 / 7.2, accuracy: 0.0001)
        XCTAssertEqual(preferences.resolvedBillingPlan(for: .xiaomiMimo).monthlyUSD ?? 0, 34.9 / 7.2, accuracy: 0.0001)
    }

    func testCustomBillingSelectionOverridesProviderCost() {
        var preferences = AppPreferences()
        preferences.setBillingSelection(
            BillingPlanSelection(
                mode: .customMonthlyUSD,
                presetID: "opencode-go",
                customMonthlyUSD: 15
            ),
            for: .opencode
        )

        XCTAssertEqual(preferences.resolvedBillingPlan(for: .opencode).monthlyUSD, 15)
        XCTAssertEqual(preferences.billingOverridesByProviderKey()["opencode-go"], 15)
    }

    func testTotalActualInputTokensSumsRowInputDirectlyWithoutCacheSubtraction() {
        let payload = DashboardPayload(
            summary: DashboardPayload.Summary(
                totalTokens: 200,
                totalActualTokens: 150,
                totalCacheReadTokens: 40,
                totalCacheWriteTokens: 10,
                totalCacheTokens: 50,
                totalCost: 0,
                totalMessages: 2,
                activeDays: 1,
                dateRange: .init(start: "2026-05-15", end: "2026-05-15"),
                updatedAt: "2026-05-15T12:00:00Z"
            ),
            dailyTotals: [:],
            modelTotals: [:],
            providerCosts: [:],
            providerTotals: [:],
            rawData: [
                DashboardPayload.RawRow(
                    date: "2026-05-15",
                    model: "m1",
                    provider: "p1",
                    input: 120,
                    output: 10,
                    reasoning: 0,
                    cacheRead: 30,
                    cacheWrite: 5,
                    cacheWriteMissingCount: 0,
                    cacheWriteReportedCount: 1,
                    total: 135,
                    cost: 0,
                    msgCount: 1
                ),
                DashboardPayload.RawRow(
                    date: "2026-05-15",
                    model: "m2",
                    provider: "p2",
                    input: 80,
                    output: 5,
                    reasoning: 0,
                    cacheRead: 10,
                    cacheWrite: 5,
                    cacheWriteMissingCount: 0,
                    cacheWriteReportedCount: 1,
                    total: 90,
                    cost: 0,
                    msgCount: 1
                )
            ]
        )

        // totalActualInputTokens should sum row.input directly, without subtracting cacheRead or cacheWrite
        XCTAssertEqual(payload.totalActualInputTokens, 200)
    }

    func testDashboardAnalyticsAppliesBillingOverridesWithoutChangingRawRows() {
        let payload = DashboardPayload(
            summary: DashboardPayload.Summary(
                totalTokens: 110,
                totalActualTokens: 110,
                totalCacheReadTokens: 0,
                totalCacheWriteTokens: 0,
                totalCacheTokens: 0,
                totalCost: 1,
                totalMessages: 1,
                activeDays: 1,
                dateRange: .init(start: "2026-05-15", end: "2026-05-15"),
                updatedAt: "2026-05-15T12:00:00Z"
            ),
            dailyTotals: [:],
            modelTotals: [:],
            providerCosts: [:],
            providerTotals: [:],
            rawData: [
                DashboardPayload.RawRow(
                    date: "2026-05-15",
                    model: "minimax-m2.7",
                    provider: "opencode-go",
                    input: 100,
                    output: 10,
                    reasoning: 0,
                    cacheRead: 0,
                    cacheWrite: 0,
                    cacheWriteMissingCount: 0,
                    cacheWriteReportedCount: 1,
                    total: 110,
                    cost: 1,
                    msgCount: 1
                )
            ]
        )

        let analytics = TokenCostDashboardAnalytics(
            payload: payload,
            billingOverridesByProviderKey: ["opencode-go": 15]
        )

        XCTAssertEqual(analytics.overview.totalCost, 15)
        XCTAssertEqual(analytics.sortedDetailRows(sortField: .cost, direction: .descending).first?.cost, 1)
    }

    private func makeSession(
        sessionID: String,
        updatedAt: String,
        usage: CodexTokenUsage
    ) -> CodexSessionSummary {
        CodexSessionSummary(
            sessionID: sessionID,
            label: sessionID,
            agentNickname: nil,
            startedAt: updatedAt,
            updatedAt: updatedAt,
            planType: nil,
            tokenCountEvents: 1,
            validTokenCountEvents: 1,
            usage: usage,
            modelContextWindow: nil
        )
    }

    // MARK: - AppPreferences workspaceID tests

    func testAppPreferencesInitRetainsWorkspaceID() {
        let prefs = AppPreferences(opencodeGoWorkspaceID: "ws-abc-123")
        XCTAssertEqual(prefs.opencodeGoWorkspaceID, "ws-abc-123")
    }

    func testAppPreferencesInitDefaultsToNil() {
        let prefs = AppPreferences()
        XCTAssertNil(prefs.opencodeGoWorkspaceID)
    }

    func testAppPreferencesDecodePreservesWorkspaceID() throws {
        let data = #"{"language":"zh-Hans","openCodePricingMode":"api","opencode_go_workspace_id":"ws-decoded-456"}"#.data(using: .utf8)!
        let prefs = try JSONDecoder().decode(AppPreferences.self, from: data)
        XCTAssertEqual(prefs.opencodeGoWorkspaceID, "ws-decoded-456")
    }

    func testAppPreferencesEncodeIncludesWorkspaceID() throws {
        let prefs = AppPreferences(opencodeGoWorkspaceID: "ws-encode-test")
        let data = try JSONEncoder().encode(prefs)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["opencode_go_workspace_id"] as? String, "ws-encode-test")
    }

    func testAppPreferencesEncodeOmitsNilWorkspaceID() throws {
        let prefs = AppPreferences()
        let data = try JSONEncoder().encode(prefs)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNil(json["opencode_go_workspace_id"])
    }

    // MARK: - SecureCredentialStore workspace-id round trip with isolated service

    func testWorkspaceIDRoundTripWithIsolatedService() {
        let testService = "com.test.workspace-id-test-\(UUID().uuidString)"
        defer {
            // Clean up test Keychain entries
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: testService
            ]
            SecItemDelete(query as CFDictionary)
        }

        // Initially nil
        XCTAssertNil(SecureCredentialStore.getWorkspaceID(service: testService))

        // Save and read back
        SecureCredentialStore.saveWorkspaceID("test-ws-001", service: testService)
        XCTAssertEqual(SecureCredentialStore.getWorkspaceID(service: testService), "test-ws-001")

        // Overwrite
        SecureCredentialStore.saveWorkspaceID("test-ws-002", service: testService)
        XCTAssertEqual(SecureCredentialStore.getWorkspaceID(service: testService), "test-ws-002")

        // Delete and verify nil
        SecureCredentialStore.deleteWorkspaceID(service: testService)
        XCTAssertNil(SecureCredentialStore.getWorkspaceID(service: testService))
    }

    func testDeleteWorkspaceIDDoesNotAffectOtherAccounts() {
        let testService = "com.test.isolated-delete-\(UUID().uuidString)"
        defer {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: testService
            ]
            SecItemDelete(query as CFDictionary)
        }

        // Save both workspace-id and auth-cookie
        SecureCredentialStore.saveWorkspaceID("ws-123", service: testService)
        SecureCredentialStore.saveAuthCookie("cookie-abc", service: testService)

        // Delete only workspace-id
        SecureCredentialStore.deleteWorkspaceID(service: testService)

        // Workspace-id should be gone
        XCTAssertNil(SecureCredentialStore.getWorkspaceID(service: testService))
        // Auth-cookie should still exist
        XCTAssertEqual(SecureCredentialStore.getAuthCookie(service: testService), "cookie-abc")
    }

    // MARK: - BalanceManager testSnapshot with mock checker

    @MainActor func testTestSnapshotWithMockChecker() async {
        let expectedSnapshot = BalanceSnapshot(
            provider: .opencodeGo,
            fetchedAt: Date(),
            isAvailable: true,
            usagePercent: 0.42,
            primaryWindowLabel: "5小时",
            primaryWindowUsagePercent: 0.42
        )

        let mockChecker = MockBalanceChecker(
            providerKind: .opencodeGo,
            snapshot: expectedSnapshot
        )

        let manager = BalanceManager(checkers: [])
        let snapshot = await manager.testSnapshot(for: mockChecker, authToken: "test-api-key")

        XCTAssertTrue(snapshot.isAvailable)
        XCTAssertEqual(snapshot.usagePercent, 0.42)
        XCTAssertEqual(snapshot.primaryWindowLabel, "5小时")
        XCTAssertEqual(snapshot.primaryWindowUsagePercent, 0.42)
    }

    @MainActor func testTestSnapshotWithMockFailingChecker() async {
        let mockChecker = MockBalanceChecker(
            providerKind: .opencodeGo,
            errorMessage: "mock fetch failure"
        )

        let manager = BalanceManager(checkers: [])
        let snapshot = await manager.testSnapshot(for: mockChecker, authToken: "test-key")

        XCTAssertFalse(snapshot.isAvailable)
        XCTAssertEqual(snapshot.errorMessage, "mock fetch failure")
    }

    @MainActor func testTestSnapshotBypassesBackoffAndConcurrencyGuard() async {
        let expectedSnapshot = BalanceSnapshot(
            provider: .codex,
            fetchedAt: Date(),
            isAvailable: true,
            remainingCredits: 100
        )

        let mockChecker = MockBalanceChecker(
            providerKind: .codex,
            snapshot: expectedSnapshot
        )

        let manager = BalanceManager(checkers: [])
        // Call twice rapidly — testSnapshot should not be blocked
        let snap1 = await manager.testSnapshot(for: mockChecker, authToken: "k1")
        let snap2 = await manager.testSnapshot(for: mockChecker, authToken: "k2")

        XCTAssertTrue(snap1.isAvailable)
        XCTAssertTrue(snap2.isAvailable)
        XCTAssertEqual(snap1.remainingCredits, 100)
        XCTAssertEqual(snap2.remainingCredits, 100)
    }

    @MainActor func testTestSnapshotPassesAuthTokenToChecker() async {
        // This mock captures the authToken it receives
        let mockChecker = TokenCapturingMockChecker(providerKind: .opencodeGo)

        let manager = BalanceManager(checkers: [])
        _ = await manager.testSnapshot(for: mockChecker, authToken: "secret-token-42")

        XCTAssertEqual(mockChecker.capturedAuthToken, "secret-token-42")
    }

    // MARK: - OpenCodeGoDashboardFetcher parseWindows (SolidJS SSR)

    func testParseWindowsAllThreeSolidJS() {
        let html = """
        <html><body>
        <script>rollingUsage:$R[42]={usagePercent:65,resetInSec:2520};</script>
        <script>weeklyUsage:$R[43]={usagePercent:30,resetInSec:259200};</script>
        <script>monthlyUsage:$R[44]={usagePercent:12,resetInSec:1728000};</script>
        </body></html>
        """

        let usage = OpenCodeGoDashboardFetcher.parseWindows(from: html)
        XCTAssertNotNil(usage)
        XCTAssertEqual(usage?.rolling?.usagePercent, 65)
        XCTAssertEqual(usage?.rolling?.resetInSec, 2520)
        XCTAssertEqual(usage?.weekly?.usagePercent, 30)
        XCTAssertEqual(usage?.weekly?.resetInSec, 259200)
        XCTAssertEqual(usage?.monthly?.usagePercent, 12)
        XCTAssertEqual(usage?.monthly?.resetInSec, 1728000)
    }

    func testParseWindowsFieldOrderSwapped() {
        let html = """
        <script>rollingUsage:$R[42]={resetInSec:3600,usagePercent:80};</script>
        """

        let usage = OpenCodeGoDashboardFetcher.parseWindows(from: html)
        XCTAssertNotNil(usage)
        XCTAssertEqual(usage?.rolling?.usagePercent, 80)
        XCTAssertEqual(usage?.rolling?.resetInSec, 3600)
        XCTAssertNil(usage?.weekly)
        XCTAssertNil(usage?.monthly)
    }

    func testParseWindowsPartialWindowsAvailable() {
        let html = """
        <script>weeklyUsage:$R[43]={usagePercent:55,resetInSec:86400};</script>
        """

        let usage = OpenCodeGoDashboardFetcher.parseWindows(from: html)
        XCTAssertNotNil(usage)
        XCTAssertNil(usage?.rolling)
        XCTAssertEqual(usage?.weekly?.usagePercent, 55)
        XCTAssertEqual(usage?.weekly?.resetInSec, 86400)
        XCTAssertNil(usage?.monthly)
    }

    func testParseWindowsOldFormatReturnsNil() {
        let html = """
        <script>self.__next_f.push([1,"{\\"rollingUsage\\":{\\"usagePercent\\":65,\\"resetInSec\\":2520}}"])</script>
        """

        let usage = OpenCodeGoDashboardFetcher.parseWindows(from: html)
        XCTAssertNil(usage)
    }

    func testParseWindowsDecimalUsagePercent() {
        let html = """
        <script>monthlyUsage:$R[44]={usagePercent:12.5,resetInSec:1728000};</script>
        """

        let usage = OpenCodeGoDashboardFetcher.parseWindows(from: html)
        XCTAssertNotNil(usage)
        XCTAssertEqual(usage?.monthly?.usagePercent, 12.5)
        XCTAssertEqual(usage?.monthly?.resetInSec, 1728000)
    }

    // MARK: - BrowserCookieExtractor

    func testExtractWorkspaceIDFromHistoryURL() {
        let url = "https://opencode.ai/workspace/wrk_01ABCDEF0123456789/go"
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("opencode_test_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("History")
        do {
            var db: OpaquePointer?
            guard sqlite3_open(dbURL.path, &db) == SQLITE_OK, let db else { XCTFail("cannot open db"); return }
            sqlite3_exec(db, "CREATE TABLE urls (url TEXT, last_visit_time INTEGER)", nil, nil, nil)
            sqlite3_exec(db, "INSERT INTO urls VALUES ('\(url)', 1)", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA journal_mode=DELETE", nil, nil, nil)
            sqlite3_close(db)
        }

        let result = BrowserCookieExtractor.extractWorkspaceID(historyURL: dbURL)
        XCTAssertEqual(result, "wrk_01ABCDEF0123456789")
    }

    func testExtractWorkspaceIDNoMatchReturnsNil() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("opencode_test_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("History")
        do {
            var db: OpaquePointer?
            guard sqlite3_open(dbURL.path, &db) == SQLITE_OK, let db else { XCTFail("cannot open db"); return }
            sqlite3_exec(db, "CREATE TABLE urls (url TEXT, last_visit_time INTEGER)", nil, nil, nil)
            sqlite3_exec(db, "INSERT INTO urls VALUES ('https://github.com/example', 1)", nil, nil, nil)
            sqlite3_close(db)
        }

        let result = BrowserCookieExtractor.extractWorkspaceID(historyURL: dbURL)
        XCTAssertNil(result)
    }

    func testPBKDF2DerivedKeyCorrectLength() {
        let salt = Array("saltysalt".utf8)
        var dk = [UInt8](repeating: 0, count: 16)
        let pw = "test_password"
        let result = pw.withCString { ptr in
            cc_pbkdf2_sha1(ptr, strlen(ptr), salt, salt.count, 1003, &dk, 16)
        }
        XCTAssertEqual(result, 0)
        XCTAssertEqual(dk.count, 16)
    }

    func testBrowserKindOrderEdgeFirst() {
        let browsers = BrowserKind.allCases
        XCTAssertEqual(browsers.first, .edge)
        XCTAssertEqual(browsers.count, 4)
    }
}

// MARK: - Test Helpers

private struct MockBalanceChecker: BalanceChecker {
    let providerKind: BalanceProviderKind
    private let _snapshot: BalanceSnapshot?
    private let _errorMessage: String?

    init(providerKind: BalanceProviderKind, snapshot: BalanceSnapshot) {
        self.providerKind = providerKind
        self._snapshot = snapshot
        self._errorMessage = nil
    }

    init(providerKind: BalanceProviderKind, errorMessage: String) {
        self.providerKind = providerKind
        self._snapshot = nil
        self._errorMessage = errorMessage
    }

    func fetch(authToken: String) async throws -> BalanceSnapshot {
        if let errorMessage = _errorMessage {
            throw NSError(domain: "MockBalanceChecker", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        return _snapshot!
    }
}

private final class TokenCapturingMockChecker: BalanceChecker, @unchecked Sendable {
    let providerKind: BalanceProviderKind
    private(set) var capturedAuthToken: String?

    init(providerKind: BalanceProviderKind) {
        self.providerKind = providerKind
    }

    func fetch(authToken: String) async throws -> BalanceSnapshot {
        capturedAuthToken = authToken
        return BalanceSnapshot(
            provider: providerKind,
            fetchedAt: Date(),
            isAvailable: true
        )
    }
}
