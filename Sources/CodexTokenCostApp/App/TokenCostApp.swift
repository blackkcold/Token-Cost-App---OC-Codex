import AppKit
import SwiftUI
import CodexTokenCostCore

@main
struct CodexTokenCostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appPreferencesModel = AppPreferencesModel()
    @StateObject private var openCodeModel = TokenCostModel()
    @StateObject private var codexModel = CodexSessionModel()

    var body: some Scene {
        WindowGroup(CodexAppPaths.appDisplayName, id: "main") {
            ContentView(
                openCodeModel: openCodeModel,
                codexModel: codexModel,
                appPreferencesModel: appPreferencesModel
            )
        }
        .defaultSize(width: 1260, height: 860)
        .environment(\.locale, appPreferencesModel.preferences.language.locale)
        .commands {
            CodexTokenCostCommands(
                openCodeModel: openCodeModel,
                codexModel: codexModel,
                appPreferencesModel: appPreferencesModel
            )
        }

        Settings {
            SettingsView(
                openCodeModel: openCodeModel,
                codexModel: codexModel,
                appPreferencesModel: appPreferencesModel
            )
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 860)
        .environment(\.locale, appPreferencesModel.preferences.language.locale)
    }
}
