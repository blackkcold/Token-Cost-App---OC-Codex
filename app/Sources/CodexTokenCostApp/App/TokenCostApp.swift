import AppKit
import SwiftUI
import CodexTokenCostCore

@main
struct CodexTokenCostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var openCodeModel = TokenCostModel()
    @StateObject private var codexModel = CodexSessionModel()

    var body: some Scene {
        WindowGroup(CodexAppPaths.appDisplayName, id: "main") {
            ContentView(openCodeModel: openCodeModel, codexModel: codexModel)
        }
        .defaultSize(width: 1260, height: 860)
        .commands {
            CodexTokenCostCommands(openCodeModel: openCodeModel, codexModel: codexModel)
        }

        Settings {
            SettingsView(openCodeModel: openCodeModel, codexModel: codexModel)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 860)
    }
}
