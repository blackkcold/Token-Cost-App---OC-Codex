import SwiftUI
import CodexTokenCostCore

struct TotalView: View {
    @ObservedObject var openCodeModel: TokenCostModel
    @ObservedObject var codexModel: CodexSessionModel
    let palette: TokenCostPalette

    private var openCodePayload: DashboardPayload? {
        openCodeModel.selectedPayload
    }

    private var codexPayload: CodexDashboardPayload? {
        codexModel.payload
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                openCodeCard
                codexCard
                unitBoundaryCard
            }
            .padding(20)
        }
        .task {
            openCodeModel.bootstrapIfNeeded()
            codexModel.bootstrapIfNeeded()
        }
    }

    private var headerCard: some View {
        TokenSectionCard(
            title: "总计",
            subtitle: "并列汇总 OpenCode 与 Codex，不混算 USD 和订阅 token",
            trailing: nil,
            palette: palette
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                TokenMetricCard(
                    title: "OpenCode 总成本",
                    value: openCodePayload.map { TokenCostFormatters.currency($0.summary.totalCost) } ?? "未提供",
                    subtitle: "USD 口径",
                    tint: palette.accent,
                    palette: palette
                )
                TokenMetricCard(
                    title: "OpenCode 总 Token",
                    value: openCodePayload.map { TokenCostFormatters.tokens($0.summary.totalActualTokens) } ?? "未提供",
                    subtitle: "实际输入 + 输出",
                    tint: palette.accentSecondary,
                    palette: palette
                )
                TokenMetricCard(
                    title: "Codex 总 Token",
                    value: codexPayload.map { TokenCostFormatters.tokens($0.summary.totalTokens) } ?? "未提供",
                    subtitle: "session 累计快照",
                    tint: .orange,
                    palette: palette
                )
                TokenMetricCard(
                    title: "Codex Session 数",
                    value: codexPayload.map { "\($0.summary.sessionCount)" } ?? "未提供",
                    subtitle: "只读 ~/.codex/sessions",
                    tint: .green,
                    palette: palette
                )
            }
        }
    }

    private var openCodeCard: some View {
        TokenSectionCard(
            title: "OpenCode",
            subtitle: "继续沿用现有 SQLite 统计",
            trailing: nil,
            palette: palette
        ) {
            if let payload = openCodePayload {
                let summary = payload.summary
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    TokenMetricCard(
                        title: "消息数",
                        value: "\(summary.totalMessages)",
                        subtitle: "请求数",
                        tint: palette.accent,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "活跃天数",
                        value: "\(summary.activeDays)",
                        subtitle: "日期区间 \(summary.dateRange.start ?? "未提供")",
                        tint: palette.accentSecondary,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "缓存 Token",
                        value: TokenCostFormatters.tokens(summary.totalCacheTokens),
                        subtitle: "read + write",
                        tint: .green,
                        palette: palette
                    )
                }
            } else {
                Text(openCodeModel.statusMessage)
                    .foregroundStyle(palette.subtitle)
            }
        }
    }

    private var codexCard: some View {
        TokenSectionCard(
            title: "Codex",
            subtitle: "只展示 session 级聚合，不落原始 JSONL",
            trailing: nil,
            palette: palette
        ) {
            if let payload = codexPayload {
                let summary = payload.summary
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    TokenMetricCard(
                        title: "Input Token",
                        value: TokenCostFormatters.tokens(summary.totalInputTokens),
                        subtitle: "累积输入",
                        tint: palette.accent,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "Cached Token",
                        value: TokenCostFormatters.tokens(summary.totalCachedInputTokens),
                        subtitle: "缓存输入",
                        tint: palette.accentSecondary,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "Reasoning Token",
                        value: TokenCostFormatters.tokens(summary.totalReasoningOutputTokens),
                        subtitle: "诊断维度",
                        tint: .purple,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "Plan",
                        value: dominantPlanType(summary.planTypeCounts),
                        subtitle: "rate_limits.plan_type",
                        tint: .orange,
                        palette: palette
                    )
                }
            } else {
                Text(codexModel.statusMessage)
                    .foregroundStyle(palette.subtitle)
            }
        }
    }

    private var unitBoundaryCard: some View {
        TokenSectionCard(
            title: "单位边界",
            subtitle: "避免把不同计费单位硬合并成一个数",
            trailing: nil,
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenCode 继续按 SQLite 里的 token / cost 口径展示。Codex 只按本地 session 快照展示 token 聚合，并保留 plan type。")
                    .font(.callout)
                    .foregroundStyle(palette.subtitle)
                Text("如果后续需要统一口径，应单独加一个明确标注的 normalized 指标，不在总计页默认混算。")
                    .font(.callout)
                    .foregroundStyle(palette.subtitle)
            }
        }
    }

    private func dominantPlanType(_ counts: [String: Int]) -> String {
        guard let top = counts.max(by: { $0.value < $1.value }) else {
            return "未提供"
        }
        return "\(top.key) × \(top.value)"
    }
}
