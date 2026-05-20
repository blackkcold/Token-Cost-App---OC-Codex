import SwiftUI
import CodexTokenCostCore

struct CodexTokenCostCommands: Commands {
    @ObservedObject var openCodeModel: TokenCostModel
    @ObservedObject var codexModel: CodexSessionModel
    @ObservedObject var appPreferencesModel: AppPreferencesModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some Commands {
        CommandMenu(AppLocalization.text("menu.appTitle")) {
            Button(AppLocalization.text("menu.refreshAll")) {
                openCodeModel.rescanSources()
                codexModel.refresh()
            }
            .keyboardShortcut("r", modifiers: [.command])

            Divider()

            Button(AppLocalization.text("menu.openMainWindow")) {
                openWindow(id: "main")
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button(AppLocalization.text("menu.openSettings")) {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}
