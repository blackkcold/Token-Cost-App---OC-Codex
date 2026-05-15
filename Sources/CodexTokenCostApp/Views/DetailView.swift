import Charts
import SwiftUI
import CodexTokenCostCore

struct DetailView: View {
    @ObservedObject var model: TokenCostModel
    let palette: TokenCostPalette

    @State private var detailSortField: TokenCostDetailSortField = .date
    @State private var detailSortDirection: TokenCostSortDirection = .descending
    @State private var hoveredTrendPoint: TokenCostDashboardAnalytics.TrendPoint?
    @State private var detailPageIndex = 0
    @State private var stackedPageIndex = 0
    @State private var modelComparisonExpanded = false

    private let recentWindowLimit = 50
    private let sectionPageSize = 20
    private let modelComparisonCollapsedLimit = 10
    private var overviewColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 140), spacing: 12), count: 5)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let source = model.selectedSource {
                    sourceHeader(source)

                    if let payload = model.selectedPayload {
                        let analytics = TokenCostDashboardAnalytics(
                            payload: payload,
                            showZeroUsageXiaomiProvider: model.settings.showZeroUsageXiaomiProvider
                        )

                        overviewSection(analytics)
                        trendSection(analytics)
                        cacheSection(analytics)
                        providerRankingSection(analytics)
                        modelComparisonSection(analytics)
                        distributionSection(analytics)
                        stackedSection(analytics)
                        detailSection(analytics)
                    } else if model.isBootstrapping || model.isRefreshing {
                        loadingCard
                    } else {
                        emptyPayloadCard(source: source)
                    }
                } else {
                    emptyStateCard
                }
            }
            .padding(20)
        }
        .task {
            model.bootstrapIfNeeded()
            model.refreshSelectedSourceIfNeeded()
        }
        .onChange(of: model.selectedPayload?.summary.updatedAt ?? "") { _, _ in
            detailPageIndex = 0
            stackedPageIndex = 0
            modelComparisonExpanded = false
            hoveredTrendPoint = nil
        }
    }

    private func sourceHeader(_ source: TokenCostSource) -> some View {
        TokenSectionCard(
            title: source.name,
            subtitle: source.displayPath,
            trailing: AnyView(SourceStatusPill(source: source, palette: palette)),
            palette: palette
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                TokenMetricCard(
                    title: "状态",
                    value: source.statusMessage,
                    subtitle: source.isReadOnly ? "只读访问" : "可写",
                    tint: palette.accent,
                    palette: palette
                )
                TokenMetricCard(
                    title: "修改时间",
                    value: source.lastModified ?? "未提供",
                    subtitle: "\(source.sourceFamily.displayName) · \(source.locationKind.displayName)",
                    tint: palette.accentSecondary,
                    palette: palette
                )
                TokenMetricCard(
                    title: "来源路径",
                    value: source.sourceURL.lastPathComponent,
                    subtitle: source.locationURL?.path ?? source.displayPath,
                    tint: .orange,
                    palette: palette
                )
            }
        }
    }

    private func overviewSection(_ analytics: TokenCostDashboardAnalytics) -> some View {
        TokenSectionCard(title: "总览", subtitle: "与 legacy dashboard 的主卡片对齐", trailing: nil, palette: palette) {
            LazyVGrid(columns: overviewColumns, spacing: 12) {
                TokenMetricCard(
                    title: "实际 Token",
                    value: TokenCostFormatters.tokens(analytics.overview.totalActualTokens),
                    subtitle: "不含缓存 · \(analytics.overview.totalMessages) 次请求",
                    tint: palette.accent,
                    palette: palette,
                    compact: true
                )
                TokenMetricCard(
                    title: "总成本",
                    value: TokenCostFormatters.currency(analytics.overview.totalCost),
                    subtitle: "有效成本口径",
                    tint: .green,
                    palette: palette,
                    compact: true
                )
                TokenMetricCard(
                    title: "日均消耗",
                    value: TokenCostFormatters.tokens(analytics.overview.dailyAverage),
                    subtitle: "活跃 \(analytics.overview.activeDays) 天",
                    tint: palette.accentSecondary,
                    palette: palette,
                    compact: true
                )
                TokenMetricCard(
                    title: "预估月消耗",
                    value: TokenCostFormatters.tokens(analytics.overview.monthlyEstimate),
                    subtitle: "按 30 天估算",
                    tint: .orange,
                    palette: palette,
                    compact: true
                )
                TokenMetricCard(
                    title: "平均每次请求",
                    value: TokenCostFormatters.tokens(analytics.overview.averagePerRequest),
                    subtitle: "平均 Token / request",
                    tint: .purple,
                    palette: palette,
                    compact: true
                )
            }
        }
    }

    private func trendSection(_ analytics: TokenCostDashboardAnalytics) -> some View {
        let points = analytics.trendPoints
        return TokenSectionCard(title: "每日 Token 趋势", subtitle: "平滑曲线 + hover 提示", trailing: nil, palette: palette) {
            if points.isEmpty {
                Text("暂无趋势数据")
                    .foregroundStyle(palette.subtitle)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ZStack(alignment: .topTrailing) {
                    Chart {
                        ForEach(points) { point in
                            AreaMark(
                                x: .value("日期", point.date),
                                y: .value("实际 Token", point.actualTokens)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        palette.accent.opacity(0.32),
                                        palette.accent.opacity(0.04)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("日期", point.date),
                                y: .value("实际 Token", point.actualTokens)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(palette.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                            LineMark(
                                x: .value("日期", point.date),
                                y: .value("缓存命中", point.cacheReadTokens)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 4]))
                        }

                        if let hoveredTrendPoint {
                            RuleMark(x: .value("日期", hoveredTrendPoint.date))
                                .foregroundStyle(palette.subtitle.opacity(0.55))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            PointMark(
                                x: .value("日期", hoveredTrendPoint.date),
                                y: .value("实际 Token", hoveredTrendPoint.actualTokens)
                            )
                            .symbolSize(60)
                            .foregroundStyle(palette.accent)

                            PointMark(
                                x: .value("日期", hoveredTrendPoint.date),
                                y: .value("缓存命中", hoveredTrendPoint.cacheReadTokens)
                            )
                            .symbolSize(48)
                            .foregroundStyle(.green)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
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
                        TrendTooltipCard(point: hoveredTrendPoint, palette: palette)
                            .padding(.trailing, 8)
                            .padding(.top, 8)
                    }
                }
            }
        }
    }

    private func cacheSection(_ analytics: TokenCostDashboardAnalytics) -> some View {
        TokenSectionCard(title: "缓存分析", subtitle: "命中、写入、节省成本", trailing: nil, palette: palette) {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                    TokenMetricCard(
                        title: "缓存命中",
                        value: TokenCostFormatters.tokens(analytics.cache.cacheReadTokens),
                        subtitle: "读取命中 Token",
                        tint: .green,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "缓存写入",
                        value: TokenCostFormatters.tokens(analytics.cache.cacheWriteTokens),
                        subtitle: "写入 Token",
                        tint: .orange,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "缓存总量",
                        value: TokenCostFormatters.tokens(analytics.cache.totalCacheTokens),
                        subtitle: "读 + 写",
                        tint: palette.accentSecondary,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "缓存命中率",
                        value: TokenCostFormatters.percent(analytics.cache.cacheHitRate),
                        subtitle: "read / (actual + read)",
                        tint: palette.accent,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "节省成本",
                        value: TokenCostFormatters.currency(analytics.cache.cacheSavedCost),
                        subtitle: "按平均单价估算",
                        tint: .purple,
                        palette: palette
                    )
                }

                VStack(spacing: 10) {
                    ForEach(analytics.providerCacheRows) { row in
                        DistributionRow(
                            title: row.displayName,
                            value: row.cacheReadTokens,
                            total: max(row.actualTokens + row.cacheReadTokens, 1),
                            tint: TokenCostSeriesPalette.color(for: row.colorKey),
                            palette: palette,
                            suffix: "\(row.cacheWriteLabel) · \(TokenCostFormatters.percent(row.cacheRate))"
                        )
                    }
                }
            }
        }
    }

    private func providerRankingSection(_ analytics: TokenCostDashboardAnalytics) -> some View {
        TokenSectionCard(title: "Provider 性价比排行", subtitle: "按 tokens/$ 排序", trailing: nil, palette: palette) {
            if analytics.providerRankRows.isEmpty {
                Text("暂无 Provider 数据")
                    .foregroundStyle(palette.subtitle)
            } else {
                VStack(spacing: 10) {
                    let maxRatio = analytics.providerRankRows.map(\.tokensPerDollar).max() ?? 1
                    ForEach(analytics.providerRankRows) { row in
                        DistributionRow(
                            title: row.displayName,
                            value: row.tokensPerDollar,
                            total: max(maxRatio, 1),
                            tint: TokenCostSeriesPalette.color(for: row.colorKey),
                            palette: palette,
                            suffix: providerRankSuffix(row),
                            valueLabel: TokenCostFormatters.millionRate(row.tokensPerDollar)
                        )
                    }
                }
            }
        }
    }

    private func modelComparisonSection(_ analytics: TokenCostDashboardAnalytics) -> some View {
        let rows = modelComparisonRows(for: analytics)
        let subtitle = modelComparisonExpanded
            ? "按有效成本分摊后的 tokens/$ · 全量 \(analytics.modelComparisonRows.count) 个模型"
            : "按有效成本分摊后的 tokens/$ · 默认 Top \(modelComparisonCollapsedLimit)"

        return TokenSectionCard(
            title: "模型价格对比",
            subtitle: subtitle,
            trailing: modelComparisonTrailing(for: analytics),
            palette: palette
        ) {
            if rows.isEmpty {
                Text("暂无模型数据")
                    .foregroundStyle(palette.subtitle)
            } else {
                VStack(spacing: 10) {
                    let maxRatio = rows.map(\.tokensPerDollar).max() ?? 1
                    ForEach(rows) { row in
                        DistributionRow(
                            title: row.displayName,
                            value: row.tokensPerDollar,
                            total: max(maxRatio, 1),
                            tint: TokenCostSeriesPalette.color(for: row.colorKey),
                            palette: palette,
                            suffix: "\(row.provider) · \(modelCostLabel(row))",
                            valueLabel: TokenCostFormatters.millionRate(row.tokensPerDollar)
                        )
                    }
                }
            }
        }
    }

    private func distributionSection(_ analytics: TokenCostDashboardAnalytics) -> some View {
        let modelSlices = analytics.modelSlices
        let providerSlices = analytics.providerSlices
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
            pieCard(
                title: "模型分布",
                subtitle: "圆环图 + 明细",
                slices: modelSlices
            )

            pieCard(
                title: "Provider 分布",
                subtitle: "按总 Token 聚合",
                slices: providerSlices
            )
        }
    }

    private func stackedSection(_ analytics: TokenCostDashboardAnalytics) -> some View {
        let window = recentStackedWindow(from: analytics)
        let pageCount = max((window.dates.count + sectionPageSize - 1) / sectionPageSize, 1)
        let clampedPage = min(max(stackedPageIndex, 0), pageCount - 1)
        let startIndex = clampedPage * sectionPageSize
        let endIndex = min(startIndex + sectionPageSize, window.dates.count)
        let visibleDates = Array(window.dates[startIndex..<endIndex])
        let visibleDateIndexes = Array(startIndex..<endIndex)
        let maxTotal = window.dates.indices
            .map { dayTotal(at: $0, series: window.series) }
            .max() ?? 1

        return TokenSectionCard(
            title: "每日模型堆叠",
            subtitle: "基于最近 \(recentWindowLimit) 条明细，默认 20 天/页",
            trailing: nil,
            palette: palette
        ) {
            if window.series.isEmpty || window.dates.isEmpty {
                Text("暂无堆叠数据")
                    .foregroundStyle(palette.subtitle)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    stackedLegend(window.series)
                    VStack(spacing: 8) {
                        ForEach(Array(visibleDates.enumerated()), id: \.offset) { offset, dateLabel in
                            let index = visibleDateIndexes[offset]
                            StackedDayRow(
                                dateLabel: dateLabel,
                                total: dayTotal(at: index, series: window.series),
                                maxTotal: max(maxTotal, 1),
                                series: window.series,
                                dateIndex: index
                            )
                        }
                    }
                    PaginationControls(
                        pageIndex: $stackedPageIndex,
                        itemCount: window.dates.count,
                        pageSize: sectionPageSize,
                        palette: palette,
                        title: "模型堆叠分页"
                    )
                }
            }
        }
    }

    private func detailSection(_ analytics: TokenCostDashboardAnalytics) -> some View {
        let windowRows = recentDetailWindowRows(from: analytics)
        let rows = sortDetailRows(
            windowRows,
            field: detailSortField,
            direction: detailSortDirection
        )
        let pageCount = max((rows.count + sectionPageSize - 1) / sectionPageSize, 1)
        let clampedPage = min(max(detailPageIndex, 0), pageCount - 1)
        let startIndex = clampedPage * sectionPageSize
        let endIndex = min(startIndex + sectionPageSize, rows.count)
        let visibleRows = Array(rows[startIndex..<endIndex])

        return TokenSectionCard(
            title: "最近 50 条明细",
            subtitle: "最近 \(recentWindowLimit) 条窗口，默认 20 条/页，可在窗口内排序",
            trailing: AnyView(detailSortControls),
            palette: palette
        ) {
            if visibleRows.isEmpty {
                Text("暂无明细数据")
                    .foregroundStyle(palette.subtitle)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        VStack(spacing: 8) {
                            detailHeaderRow
                            ForEach(visibleRows) { row in
                                detailRow(row)
                            }
                        }
                        .frame(minWidth: 1090, alignment: .leading)
                    }
                    PaginationControls(
                        pageIndex: $detailPageIndex,
                        itemCount: rows.count,
                        pageSize: sectionPageSize,
                        palette: palette,
                        title: "明细分页"
                    )
                }
            }
        }
    }

    private var detailSortControls: some View {
        HStack(spacing: 8) {
            Picker("排序字段", selection: $detailSortField) {
                ForEach(TokenCostDetailSortField.allCases) { field in
                    Text(field.displayName).tag(field)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: detailSortField) { _, newValue in
                if newValue == .date {
                    detailSortDirection = .descending
                } else {
                    detailSortDirection = .descending
                }
                detailPageIndex = 0
            }

            Button {
                detailSortDirection = detailSortDirection == .descending ? .ascending : .descending
                detailPageIndex = 0
            } label: {
                Label(detailSortDirection.displayName, systemImage: detailSortDirection.systemImage)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var detailHeaderRow: some View {
        HStack(spacing: 12) {
            sortButton(title: "日期", field: .date, width: 96)
            sortButton(title: "模型", field: .model, width: 150)
            sortButton(title: "Provider", field: .provider, width: 132)
            sortButton(title: "Input", field: .input, width: 88, alignment: .trailing)
            sortButton(title: "Output", field: .output, width: 88, alignment: .trailing)
            sortButton(title: "Cache Read", field: .cacheRead, width: 100, alignment: .trailing)
            sortButton(title: "Cache Write", field: .cacheWrite, width: 100, alignment: .trailing)
            sortButton(title: "Total", field: .total, width: 98, alignment: .trailing)
            sortButton(title: "Cost", field: .cost, width: 96, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(palette.subtitle)
        .padding(.horizontal, 12)
    }

    private func sortButton(
        title: String,
        field: TokenCostDetailSortField,
        width: CGFloat,
        alignment: Alignment = .leading
    ) -> some View {
        Button {
            if detailSortField == field {
                detailSortDirection = detailSortDirection == .descending ? .ascending : .descending
            } else {
                detailSortField = field
                detailSortDirection = field == .date ? .descending : .descending
            }
            detailPageIndex = 0
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if detailSortField == field {
                    Image(systemName: detailSortDirection.systemImage)
                        .font(.caption2)
                }
            }
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
    }

    private func detailRow(_ row: DashboardPayload.RawRow) -> some View {
        HStack(spacing: 12) {
            Text(row.date).frame(width: 96, alignment: .leading)
            Text(row.model).frame(width: 150, alignment: .leading).lineLimit(1)
            Text(row.provider).frame(width: 132, alignment: .leading).lineLimit(1)
            Text(TokenCostFormatters.tokens(row.input)).frame(width: 88, alignment: .trailing)
            Text(TokenCostFormatters.tokens(row.output)).frame(width: 88, alignment: .trailing)
            Text(TokenCostFormatters.tokens(row.cacheRead)).frame(width: 100, alignment: .trailing)
            Text(TokenCostFormatters.tokens(row.cacheWrite)).frame(width: 100, alignment: .trailing)
            Text(TokenCostFormatters.tokens(row.total)).frame(width: 98, alignment: .trailing)
            Text(row.cost > 0 ? TokenCostFormatters.currency(row.cost) : "-")
                .frame(width: 96, alignment: .trailing)
                .foregroundStyle(row.cost > 0 ? .green : palette.subtitle)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(palette.cardStroke.opacity(0.65), lineWidth: 1)
        )
    }

    private func pieCard(
        title: String,
        subtitle: String,
        slices: [TokenCostDashboardAnalytics.DistributionSlice]
    ) -> some View {
        TokenSectionCard(title: title, subtitle: subtitle, trailing: nil, palette: palette) {
            if slices.isEmpty {
                Text("暂无数据")
                    .foregroundStyle(palette.subtitle)
            } else {
                let total = slices.reduce(0) { $0 + $1.value }
                VStack(alignment: .leading, spacing: 14) {
                    ZStack {
                        Chart(slices) { slice in
                            SectorMark(
                                angle: .value("Token", slice.value),
                                innerRadius: .ratio(0.62),
                                angularInset: 1.2
                            )
                            .foregroundStyle(TokenCostSeriesPalette.color(for: slice.colorKey))
                        }
                        .frame(height: 220)

                        VStack(spacing: 4) {
                            Text("总计")
                                .font(.caption)
                                .foregroundStyle(palette.subtitle)
                            Text(TokenCostFormatters.tokens(total))
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(palette.title)
                        }
                    }

                    VStack(spacing: 8) {
                        ForEach(slices) { slice in
                            PieLegendRow(
                                title: slice.label,
                                value: slice.value,
                                percentage: slice.percentage,
                                color: TokenCostSeriesPalette.color(for: slice.colorKey),
                                palette: palette
                            )
                        }
                    }
                }
            }
        }
    }

    private func stackedLegend(_ series: [DetailStackSeries]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 10)], spacing: 10) {
            ForEach(Array(series.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(item.isOther ? TokenCostSeriesPalette.otherColor() : TokenCostSeriesPalette.color(forRank: index))
                        Circle()
                            .strokeBorder(palette.cardStroke.opacity(0.95), lineWidth: 1.2)
                    }
                    .frame(width: 10, height: 10)
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(palette.subtitle)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(palette.accentSoft, in: Capsule())
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(palette.cardStroke.opacity(0.9), lineWidth: 1.1)
                )
            }
        }
    }

    private func providerRankSuffix(_ row: TokenCostDashboardAnalytics.ProviderRankRow) -> String {
        let costText = providerCostLabel(row)
        let actualText = TokenCostFormatters.tokens(row.actualTokens)
        return "\(actualText) 实际 · \(costText)"
    }

    private func providerCostLabel(_ row: TokenCostDashboardAnalytics.ProviderRankRow) -> String {
        guard let cost = row.effectiveCost else {
            return "未配置定价"
        }
        if row.isSynthetic {
            return "\(TokenCostFormatters.currency(cost)) API计费"
        }
        if row.isSubscription {
            return "\(TokenCostFormatters.currency(cost))/月订阅"
        }
        return TokenCostFormatters.currency(cost)
    }

    private func modelCostLabel(_ row: TokenCostDashboardAnalytics.ModelComparisonRow) -> String {
        guard row.allocatedCost > 0 else {
            return "未配置定价"
        }
        return TokenCostFormatters.currency(row.allocatedCost)
    }

    private func updateTrendSelection(
        location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        points: [TokenCostDashboardAnalytics.TrendPoint]
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

    private func dayTotal(at index: Int, series: [DetailStackSeries]) -> Double {
        series.reduce(0) { partialResult, item in
            partialResult + (item.values[safe: index] ?? 0)
        }
    }

    private func modelComparisonRows(for analytics: TokenCostDashboardAnalytics) -> [TokenCostDashboardAnalytics.ModelComparisonRow] {
        if modelComparisonExpanded {
            return analytics.modelComparisonRows
        }
        return Array(analytics.modelComparisonRows.prefix(modelComparisonCollapsedLimit))
    }

    private func modelComparisonTrailing(for analytics: TokenCostDashboardAnalytics) -> AnyView? {
        guard analytics.modelComparisonRows.count > modelComparisonCollapsedLimit else {
            return nil
        }

        return AnyView(
            Button {
                modelComparisonExpanded.toggle()
            } label: {
                Label(
                    modelComparisonExpanded ? "收起" : "查看更多",
                    systemImage: modelComparisonExpanded ? "chevron.up" : "chevron.down"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        )
    }

    private func recentDetailWindowRows(from analytics: TokenCostDashboardAnalytics) -> [DashboardPayload.RawRow] {
        Array(
            analytics.sortedDetailRows(sortField: .date, direction: .descending)
                .prefix(recentWindowLimit)
        )
    }

    private func sortDetailRows(
        _ rows: [DashboardPayload.RawRow],
        field: TokenCostDetailSortField,
        direction: TokenCostSortDirection
    ) -> [DashboardPayload.RawRow] {
        let sorted = rows.sorted { lhs, rhs in
            compareDetailRows(lhs, rhs, field: field)
        }
        return direction == .ascending ? sorted : Array(sorted.reversed())
    }

    private func compareDetailRows(
        _ lhs: DashboardPayload.RawRow,
        _ rhs: DashboardPayload.RawRow,
        field: TokenCostDetailSortField
    ) -> Bool {
        switch field {
        case .date:
            return compareString(lhs.date, rhs.date)
        case .model:
            return compareString(lhs.model, rhs.model)
        case .provider:
            return compareString(lhs.provider, rhs.provider)
        case .input:
            return compareNumeric(lhs.input, rhs.input)
        case .output:
            return compareNumeric(lhs.output, rhs.output)
        case .cacheRead:
            return compareNumeric(lhs.cacheRead, rhs.cacheRead)
        case .cacheWrite:
            return compareNumeric(lhs.cacheWrite, rhs.cacheWrite)
        case .total:
            return compareNumeric(lhs.total, rhs.total)
        case .cost:
            return compareNumeric(lhs.cost, rhs.cost)
        }
    }

    private func compareString(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private func compareNumeric(_ lhs: Double, _ rhs: Double) -> Bool {
        lhs < rhs
    }

    private func recentStackedWindow(from analytics: TokenCostDashboardAnalytics) -> RecentStackedWindow {
        let windowRows = recentDetailWindowRows(from: analytics)
        let groupedByDate = Dictionary(grouping: windowRows, by: \.date)
        let sortedDates = groupedByDate.keys.sorted(by: >)

        var totalByModel: [String: Double] = [:]
        for row in windowRows {
            let key = stackedModelKey(row.model)
            totalByModel[key, default: 0] += row.total
        }

        let topModelKeys = totalByModel
            .map { ($0.key, $0.value) }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.localizedCaseInsensitiveCompare(rhs.0) == .orderedAscending
                }
                return lhs.1 > rhs.1
            }
            .prefix(8)
            .map { $0.0 }

        let topModelSet = Set(topModelKeys)
        var series: [DetailStackSeries] = topModelKeys.map { modelKey in
            let values = sortedDates.map { date in
                groupedByDate[date, default: []].reduce(0) { partialResult, row in
                    stackedModelKey(row.model) == modelKey ? partialResult + row.total : partialResult
                }
            }
            return DetailStackSeries(
                label: modelKey,
                values: values,
                total: values.reduce(0, +),
                colorKey: modelKey,
                isOther: false
            )
        }

        let otherValues = sortedDates.map { date in
            groupedByDate[date, default: []].reduce(0) { partialResult, row in
                topModelSet.contains(stackedModelKey(row.model)) ? partialResult : partialResult + row.total
            }
        }

        if otherValues.contains(where: { $0 > 0 }) {
            series.append(
                DetailStackSeries(
                    label: "其他",
                    values: otherValues,
                    total: otherValues.reduce(0, +),
                    colorKey: "other-models",
                    isOther: true
                )
            )
        }

        return RecentStackedWindow(dates: sortedDates, series: series)
    }

    private func stackedModelKey(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unknown" : trimmed
    }

    private var loadingCard: some View {
        TokenSectionCard(title: "正在刷新", subtitle: "helper 进程正在读取 SQLite", trailing: nil, palette: palette) {
            HStack {
                ProgressView()
                Text("请稍候")
                    .foregroundStyle(palette.subtitle)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
        }
    }

    private func emptyPayloadCard(source: TokenCostSource) -> some View {
        TokenSectionCard(title: "没有可显示的数据", subtitle: source.statusMessage, trailing: nil, palette: palette) {
            Text("该数据库当前没有可用的 token 记录，或者 schema 不兼容。")
                .foregroundStyle(palette.subtitle)
                .frame(maxWidth: .infinity, minHeight: 140)
        }
    }

    private var emptyStateCard: some View {
        TokenSectionCard(title: "尚未选择来源", subtitle: "请先在左侧选择一个数据库", trailing: nil, palette: palette) {
            VStack(spacing: 12) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(palette.subtitle)
                Text("从左侧选择一个可用数据库来源。")
                    .foregroundStyle(palette.subtitle)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
        }
    }
}

private struct TrendTooltipCard: View {
    let point: TokenCostDashboardAnalytics.TrendPoint
    let palette: TokenCostPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(point.dateString)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.title)

            tooltipLine(color: palette.accent, title: "实际 Token", value: TokenCostFormatters.tokens(point.actualTokens))
            tooltipLine(color: .green, title: "缓存命中", value: TokenCostFormatters.tokens(point.cacheReadTokens))
            tooltipLine(color: .orange, title: "缓存写入", value: TokenCostFormatters.tokens(point.cacheWriteTokens))
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

private struct RecentStackedWindow {
    var dates: [String]
    var series: [DetailStackSeries]
}

private struct DetailStackSeries: Identifiable {
    var id: String { colorKey }

    var label: String
    var values: [Double]
    var total: Double
    var colorKey: String
    var isOther: Bool
}

private struct PieLegendRow: View {
    let title: String
    let value: Double
    let percentage: Double
    let color: Color
    let palette: TokenCostPalette

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(palette.title)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(TokenCostFormatters.tokens(value))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.title)

            Text(TokenCostFormatters.percent(percentage))
                .font(.caption)
                .foregroundStyle(palette.subtitle)
                .frame(width: 54, alignment: .trailing)
        }
    }
}

private struct StackedDayRow: View {
    let dateLabel: String
    let total: Double
    let maxTotal: Double
    let series: [DetailStackSeries]
    let dateIndex: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(dateLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let dayValues = series.map { $0.values[safe: dateIndex] ?? 0 }
                let totalForDay = dayValues.reduce(0, +)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(Color.primary.opacity(0.06))

                    HStack(spacing: 1) {
                        ForEach(Array(series.enumerated()), id: \.offset) { index, item in
                            let value = item.values[safe: dateIndex] ?? 0
                            if value > 0 {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(item.isOther ? TokenCostSeriesPalette.otherColor() : TokenCostSeriesPalette.color(forRank: index))
                                    .frame(width: width * (value / max(maxTotal, 1)))
                            }
                        }
                    }
                    .frame(width: width * (totalForDay / max(maxTotal, 1)), alignment: .leading)
                }
            }
            .frame(height: 12)

            Text(TokenCostFormatters.tokens(total))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
