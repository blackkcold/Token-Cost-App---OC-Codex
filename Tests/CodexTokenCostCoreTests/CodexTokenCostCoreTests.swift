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
