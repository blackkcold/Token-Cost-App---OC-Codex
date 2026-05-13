import SwiftUI
import CodexTokenCostCore

struct CodexTokenCostCommands: Commands {
    @ObservedObject var openCodeModel: TokenCostModel
    @ObservedObject var codexModel: CodexSessionModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some Commands {
        CommandMenu(CodexAppPaths.appDisplayName) {
            Button("刷新 OpenCode") {
                openCodeModel.refreshSelectedSource()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!openCodeModel.canRefreshSelectedSource)

            Button("重新扫描 OpenCode") {
                openCodeModel.rescanSources()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("刷新 Codex") {
                codexModel.refresh()
            }
            .keyboardShortcut("r", modifiers: [.command, .option])

            Divider()

            Button("打开主窗口") {
                openWindow(id: "main")
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("打开设置") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}
