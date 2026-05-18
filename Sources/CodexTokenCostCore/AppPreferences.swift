import Foundation

public struct AppPreferences: Codable, Equatable, Sendable {
    public var language: AppDisplayLanguage
    public var openCodePricingMode: OverviewPricingMode
    public var billingSelectionsByProvider: [String: BillingPlanSelection]

    public init(
        language: AppDisplayLanguage = .zhHans,
        openCodePricingMode: OverviewPricingMode = .api,
        billingSelectionsByProvider: [String: BillingPlanSelection] = [:]
    ) {
        self.language = language
        self.openCodePricingMode = openCodePricingMode
        self.billingSelectionsByProvider = billingSelectionsByProvider
    }

    private enum CodingKeys: String, CodingKey {
        case language
        case openCodePricingMode
        case billingSelectionsByProvider
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.language = try container.decodeIfPresent(AppDisplayLanguage.self, forKey: .language) ?? .zhHans
        self.openCodePricingMode = try container.decodeIfPresent(OverviewPricingMode.self, forKey: .openCodePricingMode) ?? .api

        if let selections = try container.decodeIfPresent([String: BillingPlanSelection].self, forKey: .billingSelectionsByProvider) {
            self.billingSelectionsByProvider = selections
        } else if let legacyCosts = try container.decodeIfPresent([String: Double].self, forKey: .billingSelectionsByProvider) {
            self.billingSelectionsByProvider = legacyCosts.reduce(into: [:]) { partialResult, item in
                guard let provider = BillingProvider(rawValue: item.key), BillingPlanCatalog.isValidCustomCost(item.value) else {
                    return
                }
                partialResult[provider.rawValue] = BillingPlanSelection(
                    mode: .customMonthlyUSD,
                    presetID: BillingPlanCatalog.defaultSelection(for: provider).presetID,
                    customMonthlyUSD: item.value
                )
            }
        } else {
            self.billingSelectionsByProvider = [:]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(language, forKey: .language)
        try container.encode(openCodePricingMode, forKey: .openCodePricingMode)
        try container.encode(billingSelectionsByProvider, forKey: .billingSelectionsByProvider)
    }
}

public struct AppPreferencesLoadResult {
    public var preferences: AppPreferences
    public var didFallbackToDefaults: Bool
    public var errorMessage: String?

    public init(preferences: AppPreferences, didFallbackToDefaults: Bool, errorMessage: String? = nil) {
        self.preferences = preferences
        self.didFallbackToDefaults = didFallbackToDefaults
        self.errorMessage = errorMessage
    }
}

public final class AppPreferencesStore {
    private let fileStore: SafeFileStore
    private let preferencesRelativePath: String
    private let defaultPreferences: () -> AppPreferences

    public init(
        runtimeRoot: URL = TokenCostPaths.runtimeRoot,
        preferencesRelativePath: String = "config/app-preferences.json",
        defaultPreferences: @escaping () -> AppPreferences = { AppPreferences() }
    ) {
        self.fileStore = SafeFileStore(root: runtimeRoot)
        self.preferencesRelativePath = preferencesRelativePath
        self.defaultPreferences = defaultPreferences
    }

    public func load() -> AppPreferencesLoadResult {
        do {
            let preferences = try fileStore.readCodable(AppPreferences.self, from: preferencesRelativePath)
            return AppPreferencesLoadResult(preferences: preferences, didFallbackToDefaults: false)
        } catch {
            return AppPreferencesLoadResult(
                preferences: defaultPreferences(),
                didFallbackToDefaults: true,
                errorMessage: error.localizedDescription
            )
        }
    }

    public func save(_ preferences: AppPreferences) throws {
        try backupExistingPreferencesIfNeeded()
        try fileStore.writeCodable(preferences, to: preferencesRelativePath)
    }

    private func backupExistingPreferencesIfNeeded() throws {
        let currentURL = try fileStore.resolve(preferencesRelativePath)
        guard FileManager.default.fileExists(atPath: currentURL.path) else {
            return
        }

        let backupDirectory = try fileStore.resolve("config/backups/app-preferences")
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let baseName = URL(fileURLWithPath: preferencesRelativePath)
            .deletingPathExtension()
            .lastPathComponent
        let backupURL = backupDirectory.appendingPathComponent("\(baseName)-\(timestamp()).json")
        try? FileManager.default.removeItem(at: backupURL)
        try FileManager.default.copyItem(at: currentURL, to: backupURL)
    }

    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        let raw = formatter.string(from: Date())
        return raw
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }
}
