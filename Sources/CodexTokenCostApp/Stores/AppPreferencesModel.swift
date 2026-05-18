import Foundation
import SwiftUI
import CodexTokenCostCore

@MainActor
final class AppPreferencesModel: ObservableObject {
    @Published var preferences: AppPreferences
    @Published var loadWarningMessage: String?

    private let store: AppPreferencesStore

    init() {
        self.store = AppPreferencesStore(runtimeRoot: CodexAppPaths.runtimeRoot)
        let loaded = store.load()
        self.preferences = loaded.preferences
        self.loadWarningMessage = loaded.errorMessage
        AppLocalization.setLanguage(loaded.preferences.language)
        try? CodexAppPaths.ensureRuntimeDirectories()
    }

    var languageBinding: Binding<AppDisplayLanguage> {
        Binding(
            get: { self.preferences.language },
            set: { newValue in
                self.updatePreferences { preferences in
                    preferences.language = newValue
                }
            }
        )
    }

    var openCodePricingModeBinding: Binding<OverviewPricingMode> {
        Binding(
            get: { self.preferences.openCodePricingMode },
            set: { newValue in
                self.updatePreferences { preferences in
                    preferences.openCodePricingMode = newValue
                }
            }
        )
    }

    func billingSelectionBinding(for provider: BillingProvider) -> Binding<BillingPlanSelection> {
        Binding(
            get: { self.preferences.billingSelection(for: provider) },
            set: { newValue in
                self.updatePreferences { preferences in
                    preferences.setBillingSelection(newValue, for: provider)
                }
            }
        )
    }

    func billingPlanOptionBinding(for provider: BillingProvider) -> Binding<String> {
        Binding(
            get: {
                let selection = self.preferences.billingSelection(for: provider)
                return selection.mode == .customMonthlyUSD ? BillingPlanCatalog.customOptionID : selection.presetID
            },
            set: { optionID in
                self.updatePreferences { preferences in
                    var current = preferences.billingSelection(for: provider)
                    if optionID == BillingPlanCatalog.customOptionID {
                        let fallbackCost = BillingPlanCatalog.resolve(provider: provider, selection: current).monthlyUSD ?? 1
                        current.mode = .customMonthlyUSD
                        current.customMonthlyUSD = current.customMonthlyUSD ?? fallbackCost
                    } else {
                        current.mode = .preset
                        current.presetID = optionID
                        current.customMonthlyUSD = nil
                    }
                    preferences.setBillingSelection(current, for: provider)
                }
            }
        )
    }

    func customBillingCostBinding(for provider: BillingProvider) -> Binding<Double> {
        Binding(
            get: {
                let selection = self.preferences.billingSelection(for: provider)
                return selection.customMonthlyUSD ?? BillingPlanCatalog.resolve(provider: provider, selection: selection).monthlyUSD ?? 1
            },
            set: { newValue in
                guard BillingPlanCatalog.isValidCustomCost(newValue) else { return }
                self.updatePreferences { preferences in
                    var selection = preferences.billingSelection(for: provider)
                    selection.mode = .customMonthlyUSD
                    selection.customMonthlyUSD = newValue
                    preferences.setBillingSelection(selection, for: provider)
                }
            }
        )
    }

    func updatePreferences(_ mutate: (inout AppPreferences) -> Void) {
        var updated = preferences
        mutate(&updated)
        preferences = updated
        AppLocalization.setLanguage(updated.language)
        persistPreferences()
    }

    private func persistPreferences() {
        do {
            try store.save(preferences)
            loadWarningMessage = nil
        } catch {
            loadWarningMessage = error.localizedDescription
        }
    }
}
