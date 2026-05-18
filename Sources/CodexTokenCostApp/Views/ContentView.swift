import SwiftUI
import CodexTokenCostCore

enum CodexDashboardPage: String, CaseIterable, Identifiable {
    case total
    case opencode
    case codex

    var id: String { rawValue }
}

struct ContentView: View {
    @ObservedObject var openCodeModel: TokenCostModel
    @ObservedObject var codexModel: CodexSessionModel
    @ObservedObject var appPreferencesModel: AppPreferencesModel
    @Environment(\.openSettings) private var openSettings
    @State private var selectedPage: CodexDashboardPage = .total
    @State private var didOpenCodexSourcePrompt = false

    private var palette: TokenCostPalette {
        TokenCostPalette(theme: openCodeModel.settings.theme)
    }

    var body: some View {
        ZStack {
            palette.pageBackground
                .ignoresSafeArea()

            TabView(selection: $selectedPage) {
                TotalView(
                    openCodeModel: openCodeModel,
                    codexModel: codexModel,
                    appPreferencesModel: appPreferencesModel,
                    palette: palette
                )
                .tag(CodexDashboardPage.total)
                .tabItem {
                    Label(AppLocalization.text("tab.total"), systemImage: "square.grid.2x2")
                }

                OpenCodePageView(
                    model: openCodeModel,
                    appPreferencesModel: appPreferencesModel,
                    palette: palette
                )
                    .tag(CodexDashboardPage.opencode)
                    .tabItem {
                        Label(AppLocalization.text("tab.opencode"), systemImage: "externaldrive")
                    }

                CodexPageView(model: codexModel, palette: palette)
                    .tag(CodexDashboardPage.codex)
                    .tabItem {
                        Label(AppLocalization.text("tab.codex"), systemImage: "terminal")
                    }
            }
            .task {
                openCodeModel.bootstrapIfNeeded()
                codexModel.bootstrapIfNeeded()
                openCodexSourcePromptIfNeeded()
            }
            .onChange(of: codexModel.shouldPromptForSourceConfirmation) { _, shouldPrompt in
                guard shouldPrompt else { return }
                openCodexSourcePromptIfNeeded()
            }
        }
    }

    private func openCodexSourcePromptIfNeeded() {
        guard codexModel.shouldPromptForSourceConfirmation, !didOpenCodexSourcePrompt else {
            return
        }
        didOpenCodexSourcePrompt = true
        openSettings()
    }
}
