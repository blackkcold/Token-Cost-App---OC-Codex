import Charts
import SwiftUI
import CodexTokenCostCore

struct CodexPageView: View {
    @ObservedObject var model: CodexSessionModel
    @ObservedObject var balanceManager: BalanceManager
    let palette: TokenCostPalette
    @State private var sessionPageIndex = 0
    @State private var sessionSortField: CodexSessionSortField = .updatedAt
    @State private var sessionSortDirection: TokenCostSortDirection = .descending
    @State private var hoveredTrendPoint: CodexDailyTrendPoint?

    private let sessionPageSize = 20
    private var summaryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 150), spacing: 12), count: 6)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                if let warning = model.settingsLoadWarningMessage {
                    warningCard(message: warning)
                }
                summaryCard
                BalanceOverviewCard(
                    snapshots: balanceManager.snapshots.filter { $0.provider == .codex },
                    lastRefreshTime: balanceManager.lastRefreshTime,
                    palette: palette
                )
                dailyTrendCard
                sessionsCard
            }
            .padding(20)
        }
        .task {
            model.bootstrapIfNeeded()
            model.refreshIfNeeded()
        }
        .onChange(of: model.payload?.summary.updatedAt ?? "") { _, _ in
            sessionPageIndex = 0
            hoveredTrendPoint = nil
        }
    }

    private var headerCard: some View {
        TokenSectionCard(
            title: AppLocalization.text("common.codex"),
            subtitle: model.sourceRootsDescription,
            trailing: AnyView(statusPill),
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text("codex.header.body"))
                    .font(.callout)
                    .foregroundStyle(palette.subtitle)
                Text(AppLocalization.text("codex.header.autoscan"))
                    .font(.caption)
                    .foregroundStyle(palette.subtitle)
                Text(AppLocalization.format("codex.header.sourceRoots", model.sourceRootsDescription))
                    .font(.caption)
                    .foregroundStyle(palette.title)
                    .lineLimit(2)
                Text(AppLocalization.format("codex.header.manualFiles", model.manualSourcePathsDescription))
                    .font(.caption)
                    .foregroundStyle(palette.subtitle)
                    .lineLimit(2)
                if let error = model.lastErrorMessage, error != model.settingsLoadWarningMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text(model.statusMessage)
                        .font(.caption)
                        .foregroundStyle(palette.subtitle)
                }
            }
        }
    }

    private var summaryCard: some View {
        TokenSectionCard(
            title: AppLocalization.text("codex.summary.title"),
            subtitle: AppLocalization.text("codex.summary.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            if let payload = model.payload {
                let summary = payload.summary
                LazyVGrid(columns: summaryColumns, spacing: 12) {
                    TokenMetricCard(
                        title: AppLocalization.text("codex.summary.actualTokens"),
                        value: TokenCostFormatters.tokens(summary.totalActualTokens),
                        subtitle: AppLocalization.text("codex.summary.actualTokensSubtitle"),
                        tint: palette.accent,
                        palette: palette,
                        compact: true
                    )
                    TokenMetricCard(
                        title: AppLocalization.text("codex.summary.actualInput"),
                        value: TokenCostFormatters.tokens(summary.totalActualInputTokens),
                        subtitle: AppLocalization.text("codex.summary.actualInputSubtitle"),
                        tint: .green,
                        palette: palette,
                        compact: true
                    )
                    TokenMetricCard(
                        title: AppLocalization.text("codex.summary.outputTokens"),
                        value: TokenCostFormatters.tokens(summary.totalOutputTokens),
                        subtitle: AppLocalization.text("codex.summary.outputTokensSubtitle"),
                        tint: .orange,
                        palette: palette,
                        compact: true
                    )
                    TokenMetricCard(
                        title: AppLocalization.text("codex.summary.reasoningTokens"),
                        value: TokenCostFormatters.tokens(summary.totalReasoningOutputTokens),
                        subtitle: AppLocalization.text("codex.summary.reasoningTokensSubtitle"),
                        tint: .purple,
                        palette: palette,
                        compact: true
                    )
                    TokenMetricCard(
                        title: AppLocalization.text("codex.summary.cachedInput"),
                        value: TokenCostFormatters.tokens(summary.totalCachedInputTokens),
                        subtitle: AppLocalization.text("codex.summary.cachedInputSubtitle"),
                        tint: .blue,
                        palette: palette,
                        compact: true
                    )
                    TokenMetricCard(
                        title: AppLocalization.text("codex.summary.sessionCount"),
                        value: "\(summary.sessionCount)",
                        subtitle: AppLocalization.text("codex.summary.sessionCountSubtitle"),
                        tint: palette.accentSecondary,
                        palette: palette,
                        compact: true
                    )
                }

                if !summary.planTypeCounts.isEmpty {
                    Text(planSummary(summary.planTypeCounts))
                        .font(.caption)
                        .foregroundStyle(palette.subtitle)
                        .padding(.top, 4)
                }
            } else {
                Text(model.statusMessage)
                    .foregroundStyle(palette.subtitle)
            }
        }
    }

    private var dailyTrendCard: some View {
        TokenSectionCard(
            title: AppLocalization.text("codex.trend.title"),
            subtitle: AppLocalization.text("codex.trend.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            if let payload = model.payload {
                let points = CodexDashboardAnalytics.dailyTrendPoints(from: payload)

                if points.isEmpty {
                    Text(AppLocalization.text("common.noData"))
                        .foregroundStyle(palette.subtitle)
                        .frame(maxWidth: .infinity, minHeight: 200, alignment: .leading)
                } else {
                    ZStack(alignment: .topTrailing) {
                        Chart {
                            ForEach(points) { point in
                                AreaMark(
                                    x: .value(AppLocalization.text("chart.label.date"), point.date),
                                    y: .value(AppLocalization.text("chart.label.actual"), point.actualTokens)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            palette.accent.opacity(0.30),
                                            palette.accent.opacity(0.04)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                LineMark(
                                    x: .value(AppLocalization.text("chart.label.date"), point.date),
                                    y: .value(AppLocalization.text("chart.label.actual"), point.actualTokens)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(palette.accent)
                                .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                            }

                            if let hoveredTrendPoint {
                                RuleMark(x: .value(AppLocalization.text("chart.label.date"), hoveredTrendPoint.date))
                                    .foregroundStyle(palette.subtitle.opacity(0.55))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                                PointMark(
                                    x: .value(AppLocalization.text("chart.label.date"), hoveredTrendPoint.date),
                                    y: .value(AppLocalization.text("chart.label.actual"), hoveredTrendPoint.actualTokens)
                                )
                                .symbolSize(60)
                                .foregroundStyle(palette.accent)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 260)
                        .padding(.top, 4)
                        .chartOverlay { proxy in
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(.clear)
                                    .contentShape(Rectangle())
                                    .onContinuousHover { phase in
                                        switch phase {
                                        case .active(let location):
                                            updateTrendSelection(location: location, proxy: proxy, geometry: geometry, points: points)
                                        case .ended:
                                            hoveredTrendPoint = nil
                                        }
                                    }
                            }
                        }

                        if let hoveredTrendPoint {
                            CodexTrendTooltipCard(point: hoveredTrendPoint, palette: palette)
                                .padding(.trailing, 8)
                                .padding(.top, 8)
                        }
                    }
                }
            } else {
                Text(model.statusMessage)
                    .foregroundStyle(palette.subtitle)
                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .leading)
            }
        }
    }

    private var sessionsCard: some View {
        TokenSectionCard(
            title: AppLocalization.text("codex.sessions.title"),
            subtitle: AppLocalization.format("codex.sessions.subtitle", model.payload?.summary.sessionCount ?? 0),
            trailing: nil,
            palette: palette
        ) {
            if let payload = model.payload, !payload.sessions.isEmpty {
                let sessions = CodexDashboardAnalytics.sortSessions(
                    payload.sessions,
                    field: sessionSortField,
                    direction: sessionSortDirection
                )
                let pageCount = max((sessions.count + sessionPageSize - 1) / sessionPageSize, 1)
                let clampedPage = min(max(sessionPageIndex, 0), pageCount - 1)
                let startIndex = clampedPage * sessionPageSize
                let endIndex = min(startIndex + sessionPageSize, sessions.count)
                let pageSessions = Array(sessions[startIndex..<endIndex])

                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 8) {
                            sessionHeaderRow
                            ForEach(pageSessions) { session in
                                CodexSessionRow(session: session, palette: palette)
                            }
                        }
                        .frame(minWidth: 1150, alignment: .leading)
                    }

                    PaginationControls(
                        pageIndex: $sessionPageIndex,
                        itemCount: sessions.count,
                        pageSize: sessionPageSize,
                        palette: palette,
                        title: AppLocalization.text("codex.sessions.paginationTitle")
                    )
                }
            } else {
                Text(AppLocalization.text("common.noData"))
                    .foregroundStyle(palette.subtitle)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            }
        }
    }

    private var statusPill: some View {
        Text(model.isRefreshing ? AppLocalization.text("common.refreshing") : AppLocalization.text("common.ready"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(model.isRefreshing ? palette.accent : palette.subtitle)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background((model.isRefreshing ? palette.accent : palette.subtitle).opacity(0.12), in: Capsule())
    }

    private func planSummary(_ counts: [String: Int]) -> String {
        let parts = counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .map { "\($0.key) × \($0.value)" }
        return AppLocalization.format("codex.summary.planSummary", parts.joined(separator: " · "))
    }

    private func warningCard(message: String) -> some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.warning.title"),
            subtitle: AppLocalization.text("settings.codex.warning.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CodexSessionRow: View {
    let session: CodexSessionSummary
    let palette: TokenCostPalette

    var body: some View {
        HStack(spacing: 12) {
            Text(CodexDashboardAnalytics.displayTimestamp(for: session.updatedAt))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 124, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(session.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.title)
                        .lineLimit(1)

                    if let planType = session.planType {
                        Text(planType)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.12), in: Capsule())
                    }
                }

                Text(rowSubtitle)
                    .font(.caption)
                    .foregroundStyle(palette.subtitle)
                    .lineLimit(1)
            }
            .frame(width: 286, alignment: .leading)

            sessionMetricColumn(title: AppLocalization.text("sort.codex.input"), value: TokenCostFormatters.tokens(session.usage.inputTokens), width: 92)
            sessionMetricColumn(title: AppLocalization.text("sort.codex.output"), value: TokenCostFormatters.tokens(session.usage.outputTokens), width: 92)
            sessionMetricColumn(title: AppLocalization.text("sort.codex.reasoning"), value: TokenCostFormatters.tokens(session.usage.reasoningOutputTokens), width: 104)
            sessionMetricColumn(title: AppLocalization.text("sort.codex.cachedInput"), value: TokenCostFormatters.tokens(session.usage.cachedInputTokens), width: 92)
            sessionMetricColumn(title: AppLocalization.text("sort.codex.actualTokens"), value: TokenCostFormatters.tokens(session.actualTokens), width: 92)
            sessionMetricColumn(title: AppLocalization.text("sort.codex.totalTokens"), value: TokenCostFormatters.tokens(session.usage.totalTokens), width: 92)
            sessionMetricColumn(title: AppLocalization.text("sort.codex.tokenCountEvents"), value: "\(session.tokenCountEvents)", width: 74)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    private func sessionMetricColumn(
        title: String,
        value: String,
        width: CGFloat
    ) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(palette.subtitle)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.title)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(width: width, alignment: .trailing)
    }

    private var rowSubtitle: String {
        let startedAt = session.startedAt ?? AppLocalization.text("common.unavailable")
        let countSummary = AppLocalization.format("codex.session.countSummary", session.validTokenCountEvents, session.tokenCountEvents)
        if let nickname = session.agentNickname, !nickname.isEmpty {
            return AppLocalization.format("codex.session.startedNamed", nickname, startedAt, countSummary)
        }
        return AppLocalization.format("codex.session.started", startedAt, countSummary)
    }
}

private extension CodexPageView {
    var sessionHeaderRow: some View {
        HStack(spacing: 12) {
            sessionSortButton(title: AppLocalization.text("sort.codex.updatedAt"), field: .updatedAt, width: 124)
            Text(AppLocalization.text("codex.session.column.session"))
                .font(.caption)
                .foregroundStyle(palette.subtitle)
                .frame(width: 286, alignment: .leading)
            sessionSortButton(title: AppLocalization.text("sort.codex.input"), field: .input, width: 92, alignment: .trailing)
            sessionSortButton(title: AppLocalization.text("sort.codex.output"), field: .output, width: 92, alignment: .trailing)
            sessionSortButton(title: AppLocalization.text("sort.codex.reasoning"), field: .reasoning, width: 104, alignment: .trailing)
            sessionSortButton(title: AppLocalization.text("sort.codex.cachedInput"), field: .cachedInput, width: 92, alignment: .trailing)
            sessionSortButton(title: AppLocalization.text("sort.codex.actualTokens"), field: .actualTokens, width: 92, alignment: .trailing)
            sessionSortButton(title: AppLocalization.text("sort.codex.totalTokens"), field: .totalTokens, width: 92, alignment: .trailing)
            sessionSortButton(title: AppLocalization.text("sort.codex.tokenCountEvents"), field: .tokenCountEvents, width: 74, alignment: .trailing)
        }
        .padding(.horizontal, 12)
    }

    func sessionSortButton(
        title: String,
        field: CodexSessionSortField,
        width: CGFloat,
        alignment: Alignment = .leading
    ) -> some View {
        Button {
            if sessionSortField == field {
                sessionSortDirection = sessionSortDirection == .descending ? .ascending : .descending
            } else {
                sessionSortField = field
                sessionSortDirection = .descending
            }
            sessionPageIndex = 0
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if sessionSortField == field {
                    Image(systemName: sessionSortDirection.systemImage)
                        .font(.caption2)
                }
            }
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
    }

    func updateTrendSelection(
        location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        points: [CodexDailyTrendPoint]
    ) {
        guard let plotFrame = proxy.plotFrame else {
            hoveredTrendPoint = nil
            return
        }

        let frame = geometry[plotFrame]
        let x = location.x - frame.origin.x
        guard let selectedDate: Date = proxy.value(atX: x, as: Date.self) else {
            hoveredTrendPoint = nil
            return
        }

        hoveredTrendPoint = points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(selectedDate)) < abs(rhs.date.timeIntervalSince(selectedDate))
        }
    }
}

private struct CodexTrendTooltipCard: View {
    let point: CodexDailyTrendPoint
    let palette: TokenCostPalette

    var body: some View {
        let actualInputTokens = max(point.inputTokens - point.cachedInputTokens, 0)
        VStack(alignment: .leading, spacing: 8) {
            Text(point.dateString)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.title)

            tooltipLine(color: palette.accent, title: AppLocalization.text("codex.tooltip.actualTokens"), value: TokenCostFormatters.tokens(point.actualTokens))
            tooltipLine(color: .green, title: AppLocalization.text("codex.tooltip.actualInput"), value: TokenCostFormatters.tokens(actualInputTokens))
            tooltipLine(color: .blue, title: AppLocalization.text("codex.tooltip.cachedInput"), value: TokenCostFormatters.tokens(point.cachedInputTokens))
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.cardStroke, lineWidth: 1)
        )
        .shadow(color: palette.cardShadow, radius: 10, x: 0, y: 8)
    }

    private func tooltipLine(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
                .foregroundStyle(palette.subtitle)
            Spacer(minLength: 0)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.title)
        }
    }
}
