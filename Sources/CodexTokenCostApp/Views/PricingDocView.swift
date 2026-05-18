import SwiftUI
import CodexTokenCostCore

struct PricingDocView: View {
    @Environment(\.dismiss) private var dismiss
    let palette: TokenCostPalette
    @State private var attributedContent: AttributedString = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(attributedContent)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(AppLocalization.text("settings.billing.pricingDoc"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.text("settings.action.close")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadMarkdown()
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func loadMarkdown() {
        if let url = Bundle.module.url(forResource: "Pricing", withExtension: "md"),
           let content = try? String(contentsOf: url),
           let attr = try? AttributedString(markdown: content) {
            attributedContent = attr
        } else {
            attributedContent = AttributedString("Pricing documentation not found.")
        }
    }
}
