import SwiftUI
import CodexTokenCostCore

struct OpenCodePageView: View {
    @ObservedObject var model: TokenCostModel
    let palette: TokenCostPalette

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model, palette: palette)
        } detail: {
            DetailView(model: model, palette: palette)
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            model.bootstrapIfNeeded()
        }
    }
}
