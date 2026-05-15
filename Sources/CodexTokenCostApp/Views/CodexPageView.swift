import Charts
import SwiftUI
import CodexTokenCostCore

struct CodexPageView: View {
    @ObservedObject var model: CodexSessionModel
    let palette: TokenCostPalette
    @State private var sessionPageIndex = 0
    @State private var sessionSortField: CodexSessionSortField = .updatedAt
    @State private var sessionSortDirection: TokenCostSortDirection = .descending
    @State private var hoveredTrendPoint: CodexDailyTrendPoint?

    private let sessionPageSize = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                if let warning = model.settingsLoadWarningMessage {
                    warningCard(message: warning)
                }
                summaryCard
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
            title: "Codex",
            subtitle: model.sourceRootsDescription,
            trailing: AnyView(statusPill),
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("只读取当前配置的 session 目录和手动 session 文件，按每个 session 的最后一条有效 `token_count` 做累计快照。")
                    .font(.callout)
                    .foregroundStyle(palette.subtitle)
                Text("默认会自动扫描 `~/.codex/sessions` 和 `~/.codex/archived_sessions`，不需要先手动配置。")
                    .font(.caption)
                    .foregroundStyle(palette.subtitle)
                Text("目录：\(model.sourceRootsDescription)")
                    .font(.caption)
                    .foregroundStyle(palette.title)
                    .lineLimit(2)
                Text("手动文件：\(model.manualSourcePathsDescription)")
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
            title: "总览",
            subtitle: "session 级 token 聚合",
            trailing: nil,
            palette: palette
        ) {
            if let payload = model.payload {
                let summary = payload.summary
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    TokenMetricCard(
                        title: "Session 数",
                        value: "\(summary.sessionCount)",
                        subtitle: "已扫描文件数",
                        tint: palette.accent,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "总 Token",
                        value: TokenCostFormatters.tokens(summary.totalActualTokens),
                        subtitle: "不含缓存输入",
                        tint: palette.accentSecondary,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "Input",
                        value: TokenCostFormatters.tokens(summary.totalInputTokens),
                        subtitle: "输入 token",
                        tint: .green,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "Output",
                        value: TokenCostFormatters.tokens(summary.totalOutputTokens),
                        subtitle: "输出 token",
                        tint: .orange,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "Reasoning",
                        value: TokenCostFormatters.tokens(summary.totalReasoningOutputTokens),
                        subtitle: "诊断维度",
                        tint: .purple,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "Cached Input",
                        value: TokenCostFormatters.tokens(summary.totalCachedInputTokens),
                        subtitle: "缓存输入 token",
                        tint: .blue,
                        palette: palette
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
            title: "每日 Token 趋势",
            subtitle: "按 updatedAt 的日期桶聚合 · 仅统计实际 Token",
            trailing: nil,
            palette: palette
        ) {
            if let payload = model.payload {
                let points = CodexDashboardAnalytics.dailyTrendPoints(from: payload)

                if points.isEmpty {
                    Text("暂无趋势数据")
                        .foregroundStyle(palette.subtitle)
                        .frame(maxWidth: .infinity, minHeight: 200, alignment: .leading)
                } else {
                    ZStack(alignment: .topTrailing) {
                        Chart {
                            ForEach(points) { point in
                                AreaMark(
                                    x: .value("日期", point.date),
                                    y: .value("Actual", point.actualTokens)
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
                                    x: .value("日期", point.date),
                                    y: .value("Actual", point.actualTokens)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(palette.accent)
                                .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                            }

                            if let hoveredTrendPoint {
                                RuleMark(x: .value("日期", hoveredTrendPoint.date))
                                    .foregroundStyle(palette.subtitle.opacity(0.55))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                                PointMark(
                                    x: .value("日期", hoveredTrendPoint.date),
                                    y: .value("Actual", hoveredTrendPoint.actualTokens)
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
            title: "Session 列表",
            subtitle: "共 \(model.payload?.summary.sessionCount ?? 0) 个 session · 默认 20 条/页 · 支持按时间、读写与总量排序",
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
                        title: "Session 分页"
                    )
                }
            } else {
                Text("暂无 Codex session 数据")
                    .foregroundStyle(palette.subtitle)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            }
        }
    }

    private var statusPill: some View {
        Text(model.isRefreshing ? "刷新中" : "就绪")
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
        return "Plan: " + parts.joined(separator: " · ")
    }

    private func warningCard(message: String) -> some View {
        TokenSectionCard(
            title: "设置读取警告",
            subtitle: "Codex 会继续使用安全回退值，但原始配置不会被静默覆盖",
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

            sessionMetricColumn(title: "Input", value: TokenCostFormatters.tokens(session.usage.inputTokens), width: 92)
            sessionMetricColumn(title: "Output", value: TokenCostFormatters.tokens(session.usage.outputTokens), width: 92)
            sessionMetricColumn(title: "Reasoning", value: TokenCostFormatters.tokens(session.usage.reasoningOutputTokens), width: 104)
            sessionMetricColumn(title: "Cached", value: TokenCostFormatters.tokens(session.usage.cachedInputTokens), width: 92)
            sessionMetricColumn(title: "Actual", value: TokenCostFormatters.tokens(session.actualTokens), width: 92)
            sessionMetricColumn(title: "Total", value: TokenCostFormatters.tokens(session.usage.totalTokens), width: 92)
            sessionMetricColumn(title: "Events", value: "\(session.tokenCountEvents)", width: 74)
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
        let startedAt = session.startedAt ?? "未提供"
        let countSummary = "token_count \(session.validTokenCountEvents)/\(session.tokenCountEvents)"
        if let nickname = session.agentNickname, !nickname.isEmpty {
            return "\(nickname) · 开始 \(startedAt) · \(countSummary)"
        }
        return "开始 \(startedAt) · \(countSummary)"
    }
}

private extension CodexPageView {
    var sessionHeaderRow: some View {
        HStack(spacing: 12) {
            sessionSortButton(title: "时间", field: .updatedAt, width: 124)
            Text("Session")
                .font(.caption)
                .foregroundStyle(palette.subtitle)
                .frame(width: 286, alignment: .leading)
            sessionSortButton(title: "Input", field: .input, width: 92, alignment: .trailing)
            sessionSortButton(title: "Output", field: .output, width: 92, alignment: .trailing)
            sessionSortButton(title: "Reasoning", field: .reasoning, width: 104, alignment: .trailing)
            sessionSortButton(title: "Cached", field: .cachedInput, width: 92, alignment: .trailing)
            sessionSortButton(title: "Actual", field: .actualTokens, width: 92, alignment: .trailing)
            sessionSortButton(title: "Total", field: .totalTokens, width: 92, alignment: .trailing)
            sessionSortButton(title: "Events", field: .tokenCountEvents, width: 74, alignment: .trailing)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(point.dateString)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.title)

            tooltipLine(color: palette.accent, title: "Actual", value: TokenCostFormatters.tokens(point.actualTokens))
            tooltipLine(color: .green, title: "Input", value: TokenCostFormatters.tokens(point.inputTokens))
            tooltipLine(color: .orange, title: "Output", value: TokenCostFormatters.tokens(point.outputTokens))
            tooltipLine(color: .purple, title: "Reasoning", value: TokenCostFormatters.tokens(point.reasoningOutputTokens))
            tooltipLine(color: .blue, title: "Cached Input", value: TokenCostFormatters.tokens(point.cachedInputTokens))
            tooltipLine(color: palette.subtitle, title: "Sessions", value: "\(point.sessionCount)")
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
