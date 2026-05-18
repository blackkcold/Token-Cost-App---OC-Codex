import XCTest
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
}
