import SwiftUI
import CodexTokenCostCore

struct TotalView: View {
    @ObservedObject var openCodeModel: TokenCostModel
    @ObservedObject var codexModel: CodexSessionModel
    @ObservedObject var appPreferencesModel: AppPreferencesModel
    let palette: TokenCostPalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                overviewSettingsCard
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

    private var openCodePricingMode: OverviewPricingMode {
        appPreferencesModel.preferences.openCodePricingMode
    }

    private var resolvedOpenCodePlan: ResolvedBillingPlan {
        appPreferencesModel.preferences.resolvedBillingPlan(for: .opencode)
    }

    private var resolvedCodexPlan: ResolvedBillingPlan {
        appPreferencesModel.preferences.resolvedBillingPlan(for: .codex)
    }

    private var openCodePlanName: String {
        switch openCodePricingMode {
        case .api:
            return AppLocalization.text("overview.openCode.apiPlan")
        case .subscription:
            return resolvedOpenCodePlan.displayName
        }
    }

    private var openCodeOverviewCost: Double? {
        guard let openCodeSummary else {
            return nil
        }

        switch openCodePricingMode {
        case .api:
            return openCodeSummary.totalCost
        case .subscription:
            return resolvedOpenCodePlan.monthlyUSD
        }
    }

    private var codexOverviewCost: Double? {
        guard codexSummary != nil else {
            return nil
        }
        return resolvedCodexPlan.monthlyUSD
    }

    private var openCodeActualInputTokens: Double? {
        openCodePayload?.totalActualInputTokens
    }

    private var combinedActualInputTokens: Double? {
        guard let openCodeActualInputTokens, let codexSummary else {
            return nil
        }
        return openCodeActualInputTokens + codexSummary.totalActualInputTokens
    }

    private var combinedCost: Double? {
        guard let openCodeOverviewCost, let codexOverviewCost else {
            return nil
        }
        return openCodeOverviewCost + codexOverviewCost
    }

    private var overviewSettingsCard: some View {
        TokenSectionCard(
            title: AppLocalization.text("overview.settings.title"),
            subtitle: AppLocalization.text("overview.settings.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalization.text("overview.settings.openCodePricingMode"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.subtitle)

                    Picker(
                        AppLocalization.text("overview.settings.openCodePricingMode"),
                        selection: appPreferencesModel.openCodePricingModeBinding
                    ) {
                        ForEach(OverviewPricingMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 12) {
                    TokenMetricCard(
                        title: AppLocalization.text("overview.settings.openCodePlan"),
                        value: openCodePlanName,
                        subtitle: resolvedOpenCodePlan.priceDescription,
                        tint: palette.accent,
                        palette: palette,
                        compact: true
                    )

                    TokenMetricCard(
                        title: AppLocalization.text("overview.settings.codexPlan"),
                        value: resolvedCodexPlan.displayName,
                        subtitle: AppLocalization.format(
                            "overview.settings.codexPlanSubtitle",
                            resolvedCodexPlan.priceDescription
                        ),
                        tint: palette.accentSecondary,
                        palette: palette,
                        compact: true
                    )
                }
            }
        }
    }

    private var overviewCard: some View {
        TokenSectionCard(
            title: AppLocalization.text("overview.summary.title"),
            subtitle: AppLocalization.text("overview.summary.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                TokenMetricCard(
                    title: AppLocalization.text("overview.summary.openCodeCost"),
                    value: openCodeOverviewCost.map(TokenCostFormatters.currency) ?? AppLocalization.text("common.unavailable"),
                    subtitle: openCodeActualInputTokens.map {
                        AppLocalization.format(
                            "overview.summary.openCodeCostSubtitle",
                            TokenCostFormatters.tokens($0),
                            openCodePlanName
                        )
                    } ?? AppLocalization.text("overview.summary.missingData"),
                    tint: palette.accent,
                    palette: palette
                )
                TokenMetricCard(
                    title: AppLocalization.text("overview.summary.codexCost"),
                    value: codexOverviewCost.map(TokenCostFormatters.monthlyCurrency) ?? AppLocalization.text("common.unavailable"),
                    subtitle: codexSummary.map {
                        AppLocalization.format(
                            "overview.summary.codexCostSubtitle",
                            TokenCostFormatters.tokens($0.totalActualInputTokens),
                            resolvedCodexPlan.displayName
                        )
                    } ?? AppLocalization.text("overview.summary.missingData"),
                    tint: palette.accentSecondary,
                    palette: palette
                )
                TokenMetricCard(
                    title: AppLocalization.text("overview.summary.totalCost"),
                    value: combinedCost.map(TokenCostFormatters.currency) ?? AppLocalization.text("common.unavailable"),
                    subtitle: AppLocalization.format(
                        "overview.summary.totalCostSubtitle",
                        openCodePlanName,
                        resolvedCodexPlan.displayName
                    ),
                    tint: .orange,
                    palette: palette
                )
                TokenMetricCard(
                    title: AppLocalization.text("overview.summary.totalActualTokens"),
                    value: combinedActualInputTokens.map(TokenCostFormatters.tokens) ?? AppLocalization.text("common.unavailable"),
                    subtitle: AppLocalization.text("overview.summary.totalActualTokensSubtitle"),
                    tint: .green,
                    palette: palette
                )
            }
        }
    }

    private var openCodeCard: some View {
        TokenSectionCard(
            title: AppLocalization.text("overview.openCode.title"),
            subtitle: AppLocalization.format("overview.openCode.subtitle", openCodePlanName),
            trailing: nil,
            palette: palette
        ) {
            if let summary = openCodeSummary {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    TokenMetricCard(
                        title: AppLocalization.text("overview.openCode.actualTokens"),
                        value: openCodeActualInputTokens.map(TokenCostFormatters.tokens) ?? AppLocalization.text("common.unavailable"),
                        subtitle: AppLocalization.text("overview.openCode.actualTokensSubtitle"),
                        tint: palette.accent,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: AppLocalization.text("overview.openCode.totalCost"),
                        value: TokenCostFormatters.currency(summary.totalCost),
                        subtitle: AppLocalization.text("overview.openCode.apiCostSubtitle"),
                        tint: palette.accentSecondary,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: AppLocalization.text("overview.openCode.cacheTokens"),
                        value: TokenCostFormatters.tokens(summary.totalCacheTokens),
                        subtitle: AppLocalization.text("overview.openCode.cacheTokensSubtitle"),
                        tint: .green,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: AppLocalization.text("overview.openCode.messages"),
                        value: "\(summary.totalMessages)",
                        subtitle: AppLocalization.format("overview.openCode.activeDaysSubtitle", summary.activeDays),
                        tint: .orange,
                        palette: palette
                    )
                }

                Text(AppLocalization.format(
                    "overview.openCode.dateRange",
                    summary.dateRange.start ?? AppLocalization.text("common.unavailable"),
                    summary.dateRange.end ?? AppLocalization.text("common.unavailable")
                ))
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
            title: AppLocalization.text("overview.codex.title"),
            subtitle: AppLocalization.text("overview.codex.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            if let summary = codexSummary {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    TokenMetricCard(
                        title: AppLocalization.text("overview.codex.actualInput"),
                        value: TokenCostFormatters.tokens(summary.totalActualInputTokens),
                        subtitle: AppLocalization.text("overview.codex.actualInputSubtitle"),
                        tint: palette.accent,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: AppLocalization.text("overview.codex.outputTokens"),
                        value: TokenCostFormatters.tokens(summary.totalOutputTokens),
                        subtitle: AppLocalization.text("overview.codex.outputTokensSubtitle"),
                        tint: palette.accentSecondary,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: AppLocalization.text("overview.codex.reasoningTokens"),
                        value: TokenCostFormatters.tokens(summary.totalReasoningOutputTokens),
                        subtitle: AppLocalization.text("overview.codex.reasoningTokensSubtitle"),
                        tint: .purple,
                        palette: palette
                    )
                    TokenMetricCard(
                        title: AppLocalization.text("overview.codex.cachedInput"),
                        value: TokenCostFormatters.tokens(summary.totalCachedInputTokens),
                        subtitle: AppLocalization.text("overview.codex.cachedInputSubtitle"),
                        tint: .orange,
                        palette: palette
                    )
                }
                HStack {
                    Text(AppLocalization.format("overview.codex.sessionCount", summary.sessionCount))
                        .font(.caption)
                        .foregroundStyle(palette.subtitle)
                    Spacer(minLength: 12)
                    Text(AppLocalization.format("overview.codex.updatedAt", summary.updatedAt))
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
