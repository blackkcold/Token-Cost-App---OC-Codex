import SwiftUI
import CodexTokenCostCore

struct TotalView: View {
    @ObservedObject var openCodeModel: TokenCostModel
    @ObservedObject var codexModel: CodexSessionModel
    let palette: TokenCostPalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                overviewCard
                openCodeCard
                codexCard
            }
            .padding(20)
        }
        .task {
            openCodeModel.bootstrapIfNeeded()
            codexModel.bootstrapIfNeeded()
        }
    }

    private var openCodePayload: DashboardPayload? {
        openCodeModel.selectedPayload
    }

    private var codexPayload: CodexDashboardPayload? {
        codexModel.payload
    }

    private var openCodeSummary: DashboardPayload.Summary? {
        openCodePayload?.summary
    }

    private var codexSummary: CodexDashboardPayload.Summary? {
        codexPayload?.summary
    }

    private var combinedActualTokens: Double? {
        guard let openCodeSummary, let codexSummary else {
            return nil
        }
        return openCodeSummary.totalActualTokens + codexSummary.totalActualTokens
    }

    private var combinedCost: Double? {
        guard let openCodeSummary, codexSummary != nil else {
            return nil
        }
        return openCodeSummary.totalCost + CodexBilling.gptPlusMonthlyCost
    }

    private var overviewCard: some View {
        TokenSectionCard(
            title: "总计",
            subtitle: "统一按实际 token 对照，缓存输入单独展示",
            trailing: nil,
            palette: palette
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                TokenMetricCard(
                    title: "OpenCode 合计",
                    value: openCodeSummary.map { TokenCostFormatters.currency($0.totalCost) } ?? "未提供",
                    subtitle: openCodeSummary.map { "实际 \(TokenCostFormatters.tokens($0.totalActualTokens))" } ?? "USD 口径",
                    tint: palette.accent,
                    palette: palette
                )
                TokenMetricCard(
                    title: "Codex 合计",
                    value: codexSummary.map { _ in TokenCostFormatters.monthlyCurrency(CodexBilling.gptPlusMonthlyCost) } ?? "未提供",
                    subtitle: codexSummary.map { "实际 \(TokenCostFormatters.tokens($0.totalActualTokens))" } ?? "固定订阅",
                    tint: palette.accentSecondary,
                    palette: palette
                )
                TokenMetricCard(
                    title: "总成本",
                    value: combinedCost.map(TokenCostFormatters.currency) ?? "未提供",
                    subtitle: "OpenCode + GPT Plus",
                    tint: .orange,
                    palette: palette
                )
                TokenMetricCard(
                    title: "总实际 Token",
                    value: combinedActualTokens.map(TokenCostFormatters.tokens) ?? "未提供",
                    subtitle: "OpenCode + Codex，不含缓存输入",
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
            if let summary = openCodeSummary {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    TokenMetricCard(
                        title: "实际 Token",
                        value: TokenCostFormatters.tokens(summary.totalActualTokens),
                        subtitle: "不含缓存输入",
                        tint: palette.accent,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "总成本",
                        value: TokenCostFormatters.currency(summary.totalCost),
                        subtitle: "有效成本口径",
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
                    TokenMetricCard(
                        title: "消息数",
                        value: "\(summary.totalMessages)",
                        subtitle: "活跃 \(summary.activeDays) 天",
                        tint: .orange,
                        palette: palette
                    )
                }
                Text("日期区间 \(summary.dateRange.start ?? "未提供") → \(summary.dateRange.end ?? "未提供")")
                    .font(.caption)
                    .foregroundStyle(palette.subtitle)
                    .padding(.top, 4)
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
            if let summary = codexSummary {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    TokenMetricCard(
                        title: "Input Token",
                        value: TokenCostFormatters.tokens(summary.totalInputTokens),
                        subtitle: "实际输入",
                        tint: palette.accent,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "Output Token",
                        value: TokenCostFormatters.tokens(summary.totalOutputTokens),
                        subtitle: "实际输出",
                        tint: palette.accentSecondary,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "Reasoning Token",
                        value: TokenCostFormatters.tokens(summary.totalReasoningOutputTokens),
                        subtitle: "推理输出",
                        tint: .purple,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: "Cached Input",
                        value: TokenCostFormatters.tokens(summary.totalCachedInputTokens),
                        subtitle: "缓存输入",
                        tint: .orange,
                        palette: palette
                    )
                }
                HStack {
                    Text("Session 数 \(summary.sessionCount)")
                        .font(.caption)
                        .foregroundStyle(palette.subtitle)
                    Spacer(minLength: 12)
                    Text("更新于 \(summary.updatedAt)")
                        .font(.caption)
                        .foregroundStyle(palette.subtitle)
                }
                .padding(.top, 4)
            } else {
                Text(codexModel.statusMessage)
                    .foregroundStyle(palette.subtitle)
            }
        }
    }
}
