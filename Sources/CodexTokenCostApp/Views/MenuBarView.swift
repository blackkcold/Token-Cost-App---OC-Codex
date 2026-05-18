import AppKit
import SwiftUI
import CodexTokenCostCore

struct MenuBarView: View {
    @ObservedObject var openCodeModel: TokenCostModel
    @ObservedObject var codexModel: CodexSessionModel
    @ObservedObject var appPreferencesModel: AppPreferencesModel
    let palette: TokenCostPalette
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label(AppLocalization.text("menu.openMainWindow"), systemImage: "window")
            }

            Button {
                openCodeModel.refreshSelectedSource()
            } label: {
                Label(AppLocalization.text("menu.refreshOpenCode"), systemImage: "arrow.clockwise")
            }
            .disabled(!openCodeModel.canRefreshSelectedSource)

            Button {
                openCodeModel.rescanSources()
            } label: {
                Label(AppLocalization.text("menu.rescanOpenCode"), systemImage: "magnifyingglass")
            }

            Button {
                codexModel.refresh()
            } label: {
                Label(AppLocalization.text("menu.refreshCodex"), systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!codexModel.canRefresh)

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
}
