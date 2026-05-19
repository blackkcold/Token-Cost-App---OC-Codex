import SwiftUI
import CodexTokenCostCore

struct OpenCodePageView: View {
    @ObservedObject var model: TokenCostModel
    @ObservedObject var appPreferencesModel: AppPreferencesModel
    @ObservedObject var balanceManager: BalanceManager
    let palette: TokenCostPalette

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model, palette: palette)
        } detail: {
            DetailView(model: model, appPreferencesModel: appPreferencesModel, balanceManager: balanceManager, palette: palette)
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            model.bootstrapIfNeeded()
        }
    }
}
