import AppKit
import SwiftUI
import CodexTokenCostCore

struct MenuBarView: View {
    @ObservedObject var openCodeModel: TokenCostModel
    @ObservedObject var codexModel: CodexSessionModel
    @ObservedObject var appPreferencesModel: AppPreferencesModel
    @ObservedObject var balanceManager: BalanceManager
    let palette: TokenCostPalette
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if appPreferencesModel.preferences.balanceEnabled,
               !balanceManager.snapshots.isEmpty {
                Divider()
                balanceSummary
            }

            Divider()

            Button {
                activateMainWindow()
            } label: {
                Label(AppLocalization.text("menu.openMainWindow"), systemImage: "window")
            }

            Button {
                openCodeModel.rescanSources()
                codexModel.refresh()
            } label: {
                Label(AppLocalization.text("menu.refreshAll"), systemImage: "arrow.clockwise")
            }
            .disabled(openCodeModel.isBootstrapping || openCodeModel.isRefreshing || codexModel.isBootstrapping || codexModel.isRefreshing)

            Button {
                openSettings()
            } label: {
                Label(AppLocalization.text("menu.openSettings"), systemImage: "gearshape")
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(AppLocalization.text("menu.quit"), systemImage: "xmark.circle")
            }
        }
        .frame(width: 280)
        .padding(12)
    }

    private func activateMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title.contains("Token Cost") || $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private var balanceSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("实时余额")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.subtitle)

            ForEach(balanceManager.snapshots) { snapshot in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(gradientColor(for: snapshot.gradient))
                            .frame(width: 5, height: 5)
                        Text(snapshot.provider.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(palette.title)
                    }

                    if snapshot.primaryWindowUsagePercent != nil {
                        HStack(spacing: 4) {
                            if let pct = snapshot.primaryWindowUsagePercent {
                                miniBar(label: snapshot.primaryWindowLabel, pct: pct)
                            }
                            if let pct = snapshot.secondaryWindowUsagePercent {
                                miniBar(label: snapshot.secondaryWindowLabel, pct: pct)
                            }
                            if let pct = snapshot.tertiaryWindowUsagePercent {
                                miniBar(label: snapshot.tertiaryWindowLabel, pct: pct)
                            }
                        }
                    } else if let cost = snapshot.totalCostUSD {
                        Text("$\(String(format: "%.2f", cost)) 累计")
                            .font(.caption2)
                            .foregroundStyle(palette.subtitle)
                    } else {
                        Text(snapshot.shortSummary)
                            .font(.caption2)
                            .foregroundStyle(palette.subtitle)
                    }
                }
            }

            HStack {
                Spacer()
                Button {
                    Task { await balanceManager.refresh() }
                } label: {
                    HStack(spacing: 4) {
                        if balanceManager.isRefreshing {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        }
                        Text(AppLocalization.text("menu.refreshBalance"))
                    }
                    .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(balanceManager.isRefreshing ? palette.subtitle : palette.accent)
                .disabled(balanceManager.isRefreshing)
            }
        }
    }

    private func miniBar(label: String?, pct: Double) -> some View {
        HStack(spacing: 2) {
            if let label {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(palette.subtitle)
                    .frame(width: 18, alignment: .leading)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(palette.trackBackground)
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(gradientColor(for: pct < 0.5 ? .low : pct < 0.8 ? .moderate : pct < 0.95 ? .high : .critical))
                        .frame(width: geo.size.width * CGFloat(min(pct, 1.0)), height: 5)
                }
            }
            .frame(width: 36, height: 5)
            Text("\(Int(pct * 100))%")
                .font(.system(size: 9))
                .foregroundStyle(palette.subtitle)
                .frame(width: 24, alignment: .trailing)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(CodexAppPaths.appDisplayName)
                .font(.headline)
                .foregroundStyle(palette.title)

            Text(openCodeModel.statusMessage)
                .font(.caption)
                .foregroundStyle(palette.subtitle)
                .lineLimit(2)

            Text(codexModel.statusMessage)
                .font(.caption2)
                .foregroundStyle(palette.subtitle)
                .lineLimit(2)

            if let source = openCodeModel.selectedSource, let payload = openCodeModel.selectedPayload {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.title)
                        Text(TokenCostFormatters.tokens(payload.summary.totalActualTokens))
                            .font(.caption)
                            .foregroundStyle(palette.subtitle)
                    }
                    Spacer()
                }
            } else if let payload = codexModel.payload {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppLocalization.text("common.codex"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.title)
                        Text(TokenCostFormatters.tokens(payload.summary.totalActualTokens))
                            .font(.caption)
                            .foregroundStyle(palette.subtitle)
                    }
                    Spacer()
                }
            }
        }
    }

    private func gradientColor(for gradient: UsageGradient) -> Color {
        switch gradient {
        case .unused: return .gray
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        case .exceeded: return .red
        case .unknown: return .gray
        }
    }
}
