import SwiftUI
import CodexTokenCostCore

struct CodexPageView: View {
    @ObservedObject var model: CodexSessionModel
    let palette: TokenCostPalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                summaryCard
                sessionsCard
            }
            .padding(20)
        }
        .task {
            model.bootstrapIfNeeded()
            model.refreshIfNeeded()
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
                if let error = model.lastErrorMessage {
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
                        value: TokenCostFormatters.tokens(summary.totalTokens),
                        subtitle: "最后有效 token_count",
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

    private var sessionsCard: some View {
        TokenSectionCard(
            title: "Session 列表",
            subtitle: "按最近更新时间排序",
            trailing: nil,
            palette: palette
        ) {
            if let sessions = model.payload?.sessions, !sessions.isEmpty {
                VStack(spacing: 10) {
                    ForEach(sessions) { session in
                        CodexSessionRow(session: session, palette: palette)
                    }
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
}

private struct CodexSessionRow: View {
    let session: CodexSessionSummary
    let palette: TokenCostPalette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
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
                    .lineLimit(2)

                Text("token_count \(session.validTokenCountEvents)/\(session.tokenCountEvents)")
                    .font(.caption2)
                    .foregroundStyle(palette.subtitle)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(TokenCostFormatters.tokens(session.usage.totalTokens))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.title)
                Text("Input \(TokenCostFormatters.tokens(session.usage.inputTokens)) · Output \(TokenCostFormatters.tokens(session.usage.outputTokens))")
                    .font(.caption2)
                    .foregroundStyle(palette.subtitle)
                    .lineLimit(2)
            }
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

    private var rowSubtitle: String {
        let startedAt = session.startedAt ?? "未提供"
        let updatedAt = session.updatedAt
        if let nickname = session.agentNickname, !nickname.isEmpty {
            return "\(nickname) · \(startedAt) → \(updatedAt)"
        }
        return "\(startedAt) → \(updatedAt)"
    }
}
