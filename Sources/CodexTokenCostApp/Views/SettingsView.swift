import SwiftUI
import CodexTokenCostCore

struct SettingsView: View {
    @ObservedObject var openCodeModel: TokenCostModel
    @ObservedObject var codexModel: CodexSessionModel
    @ObservedObject var appPreferencesModel: AppPreferencesModel
    @Environment(\.dismiss) private var dismiss

    @State private var scanRootsPageIndex = 0
    @State private var manualDatabasePageIndex = 0
    @State private var codexDiscoveryPageIndex = 0
    @State private var codexRootsPageIndex = 0
    @State private var codexManualPageIndex = 0

    private let listPageSize = 10

    private var palette: TokenCostPalette {
        TokenCostPalette(theme: openCodeModel.settings.theme)
    }

    var body: some View {
        ZStack {
            palette.pageBackground
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    settingsHeader
                    if !warningMessages.isEmpty {
                        settingsWarningSection
                    }
                    appPreferencesSection
                    billingPlanSection
                    themeSection
                    sourceSection
                    scanRootsSection
                    manualDatabaseSection
                    codexHeader
                    codexDiscoverySection
                    codexSection
                    codexRootsSection
                    codexManualSection
                    safetySection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var warningMessages: [(title: String, message: String)] {
        var messages: [(String, String)] = []
        if let message = openCodeModel.settingsLoadWarningMessage {
            messages.append((AppLocalization.text("source.family.opencode"), message))
        }
        if let message = codexModel.settingsLoadWarningMessage {
            messages.append((AppLocalization.text("source.family.codex"), message))
        }
        if let message = appPreferencesModel.loadWarningMessage {
            messages.append((AppLocalization.text("settings.appPreferences.title"), message))
        }
        return messages
    }

    private var settingsWarningSection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.warning.title"),
            subtitle: AppLocalization.text("settings.warning.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(warningMessages.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .frame(width: 64, alignment: .leading)

                        Text(item.message)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.text("settings.title"))
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(palette.title)

            Text(AppLocalization.text("settings.subtitle"))
                .font(.callout)
                .foregroundStyle(palette.subtitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appPreferencesSection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.appPreferences.title"),
            subtitle: AppLocalization.text("settings.appPreferences.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Picker(AppLocalization.text("settings.language"), selection: appPreferencesModel.languageBinding) {
                    ForEach(AppDisplayLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)

                Picker(AppLocalization.text("settings.openCodePricingMode"), selection: appPreferencesModel.openCodePricingModeBinding) {
                    ForEach(OverviewPricingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)


            }
        }
    }

    
    @State private var isPricingDocPresented = false

    private var billingPlanSection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.billing.title"),
            subtitle: AppLocalization.text("settings.billing.subtitle"),
            trailing: AnyView(
                Button {
                    isPricingDocPresented = true
                } label: {
                    Image(systemName: "doc.text")
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.accent)
            ),
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    ForEach(BillingProvider.allCases) { provider in
                        BillingProviderPlanCard(
                            provider: provider,
                            appPreferencesModel: appPreferencesModel,
                            palette: palette
                        )
                    }
                }

                Text(AppLocalization.text("settings.billing.customCostHint"))
                    .font(.caption)
                    .foregroundStyle(palette.subtitle)
            }
        }
        .sheet(isPresented: $isPricingDocPresented) {
            PricingDocView(palette: palette)
        }
    }

    private var themeSection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.theme.title"),
            subtitle: AppLocalization.text("settings.theme.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                ForEach(TokenCostThemeChoice.allCases, id: \.self) { choice in
                    ThemeChoiceCard(
                        choice: choice,
                        isSelected: openCodeModel.settings.theme == choice
                    ) {
                        openCodeModel.updateSettings { settings in
                            settings.theme = choice
                        }
                    }
                }
            }
        }
    }

    private var codexHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.text("settings.codex.title"))
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.title)

            Text(AppLocalization.text("settings.codex.subtitle"))
                .font(.callout)
                .foregroundStyle(palette.subtitle)
            Text(AppLocalization.text("settings.codex.body"))
                .font(.caption)
                .foregroundStyle(palette.subtitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private var codexDiscoverySection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.codex.discovery.title"),
            subtitle: codexModel.shouldPromptForSourceConfirmation ? AppLocalization.text("settings.codex.discovery.prompt") : AppLocalization.text("settings.codex.discovery.ready"),
            trailing: nil,
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text(AppLocalization.text("settings.codex.discovery.body"))
                    .font(.callout)
                    .foregroundStyle(palette.subtitle)
                    .fixedSize(horizontal: false, vertical: true)

                if codexModel.discoverySources.isEmpty {
                    emptySettingsState(AppLocalization.text("settings.codex.discovery.empty"))
                } else {
                    let bounds = paginationBounds(
                        itemCount: codexModel.discoverySources.count,
                        pageIndex: codexDiscoveryPageIndex,
                        pageSize: listPageSize
                    )
                    let visibleSources = Array(codexModel.discoverySources[bounds.startIndex..<bounds.endIndex])

                    VStack(spacing: 8) {
                        ForEach(visibleSources) { source in
                            CodexDiscoveryRow(source: source, palette: palette)
                        }
                    }

                    if codexModel.discoverySources.count > listPageSize {
                        PaginationControls(
                            pageIndex: $codexDiscoveryPageIndex,
                            itemCount: codexModel.discoverySources.count,
                            pageSize: listPageSize,
                            palette: palette,
                            title: AppLocalization.text("settings.pagination.discoverySources")
                        )
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
                    Button {
                        codexModel.refresh()
                    } label: {
                        Label(AppLocalization.text("settings.action.rescan"), systemImage: "arrow.clockwise")
                    }

                    Button {
                        codexModel.addSourceRoot()
                    } label: {
                        Label(AppLocalization.text("settings.action.selectDirectory"), systemImage: "folder.badge.plus")
                    }

                    Button {
                        codexModel.addSourceFile()
                    } label: {
                        Label(AppLocalization.text("settings.action.selectFile"), systemImage: "doc.badge.plus")
                    }

                    Button {
                        dismiss()
                    } label: {
                        Label(AppLocalization.text("settings.action.close"), systemImage: "xmark")
                    }
                }
            }
        }
    }

    private var sourceSection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.source.title"),
            subtitle: AppLocalization.text("settings.source.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(AppLocalization.text("settings.source.autoRescan"), isOn: binding(\.autoRescan))
                Toggle(AppLocalization.text("settings.source.showZeroUsageProvider"), isOn: binding(\.showZeroUsageXiaomiProvider))

                Stepper(value: binding(\.maxScanDepth), in: 1...8) {
                    Text(AppLocalization.format("settings.source.scanDepth", openCodeModel.settings.maxScanDepth))
                }

                Stepper(value: binding(\.snapshotRetentionCount), in: 1...20) {
                    Text(AppLocalization.format("settings.source.snapshotRetention", openCodeModel.settings.snapshotRetentionCount))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
                    Button {
                        openCodeModel.addScanRoot()
                    } label: {
                        Label(AppLocalization.text("settings.action.addInstallDirectory"), systemImage: "folder.badge.plus")
                    }

                    Button {
                        openCodeModel.addDatabaseFile()
                    } label: {
                        Label(AppLocalization.text("settings.action.addDatabaseFile"), systemImage: "externaldrive.badge.plus")
                    }

                    Button {
                        openCodeModel.rescanSources()
                    } label: {
                        Label(AppLocalization.text("settings.action.rescan"), systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var scanRootsSection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.scanRoots.title"),
            subtitle: AppLocalization.text("settings.scanRoots.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            if openCodeModel.settings.scanRoots.isEmpty {
                emptySettingsState(AppLocalization.text("settings.empty.scanRoots"))
            } else {
                let bounds = paginationBounds(
                    itemCount: openCodeModel.settings.scanRoots.count,
                    pageIndex: scanRootsPageIndex,
                    pageSize: listPageSize
                )
                let visibleRoots = Array(openCodeModel.settings.scanRoots[bounds.startIndex..<bounds.endIndex])

                VStack(spacing: 8) {
                    ForEach(Array(visibleRoots.enumerated()), id: \.offset) { offset, path in
                        let index = bounds.startIndex + offset
                        SettingsPathRow(
                            path: path,
                            palette: palette
                        ) {
                            openCodeModel.removeScanRoot(at: IndexSet(integer: index))
                        }
                    }
                }

                if openCodeModel.settings.scanRoots.count > listPageSize {
                    PaginationControls(
                        pageIndex: $scanRootsPageIndex,
                        itemCount: openCodeModel.settings.scanRoots.count,
                        pageSize: listPageSize,
                        palette: palette,
                        title: AppLocalization.text("settings.pagination.installRoots")
                    )
                }
            }
        }
    }

    private var manualDatabaseSection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.manualDatabase.title"),
            subtitle: AppLocalization.text("settings.manualDatabase.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            if openCodeModel.settings.manualDatabasePaths.isEmpty {
                emptySettingsState(AppLocalization.text("settings.empty.manualDatabase"))
            } else {
                let bounds = paginationBounds(
                    itemCount: openCodeModel.settings.manualDatabasePaths.count,
                    pageIndex: manualDatabasePageIndex,
                    pageSize: listPageSize
                )
                let visiblePaths = Array(openCodeModel.settings.manualDatabasePaths[bounds.startIndex..<bounds.endIndex])

                VStack(spacing: 8) {
                    ForEach(Array(visiblePaths.enumerated()), id: \.offset) { offset, path in
                        let index = bounds.startIndex + offset
                        SettingsPathRow(
                            path: path,
                            palette: palette
                        ) {
                            openCodeModel.removeDatabasePath(at: IndexSet(integer: index))
                        }
                    }
                }

                if openCodeModel.settings.manualDatabasePaths.count > listPageSize {
                    PaginationControls(
                        pageIndex: $manualDatabasePageIndex,
                        itemCount: openCodeModel.settings.manualDatabasePaths.count,
                        pageSize: listPageSize,
                        palette: palette,
                        title: AppLocalization.text("settings.pagination.manualDatabase")
                    )
                }
            }
        }
    }

    private var codexSection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.codex.sources.title"),
            subtitle: AppLocalization.text("settings.codex.sources.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(AppLocalization.text("settings.codex.autoRescan"), isOn: codexBinding(\.autoRescan))

                Stepper(value: codexBinding(\.snapshotRetentionCount), in: 1...20) {
                    Text(AppLocalization.format("settings.codex.snapshotRetention", codexModel.settings.snapshotRetentionCount))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: 12)], spacing: 12) {
                    Button {
                        codexModel.addSourceRoot()
                    } label: {
                        Label(AppLocalization.text("settings.action.addSessionDirectory"), systemImage: "folder.badge.plus")
                    }

                    Button {
                        codexModel.addSourceFile()
                    } label: {
                        Label(AppLocalization.text("settings.action.addSessionFile"), systemImage: "doc.badge.plus")
                    }

                    Button {
                        codexModel.refresh()
                    } label: {
                        Label(AppLocalization.text("settings.action.refreshCodex"), systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        codexModel.resetSettingsToDefaults()
                    } label: {
                        Label(AppLocalization.text("settings.action.restoreCodexDefaults"), systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
    }

    private var codexRootsSection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.codex.roots.title"),
            subtitle: codexModel.sourceRootsDescription,
            trailing: nil,
            palette: palette
        ) {
            if codexModel.settings.sourceRoots.isEmpty {
                emptySettingsState(AppLocalization.text("settings.empty.codexRoots"))
            } else {
                let bounds = paginationBounds(
                    itemCount: codexModel.settings.sourceRoots.count,
                    pageIndex: codexRootsPageIndex,
                    pageSize: listPageSize
                )
                let visibleRoots = Array(codexModel.settings.sourceRoots[bounds.startIndex..<bounds.endIndex])

                VStack(spacing: 8) {
                    ForEach(Array(visibleRoots.enumerated()), id: \.offset) { offset, path in
                        let index = bounds.startIndex + offset
                        SettingsPathRow(
                            path: path,
                            palette: palette
                        ) {
                            codexModel.removeSourceRoot(at: IndexSet(integer: index))
                        }
                    }
                }

                if codexModel.settings.sourceRoots.count > listPageSize {
                    PaginationControls(
                        pageIndex: $codexRootsPageIndex,
                        itemCount: codexModel.settings.sourceRoots.count,
                        pageSize: listPageSize,
                        palette: palette,
                        title: AppLocalization.text("settings.pagination.codexRoots")
                    )
                }
            }
        }
    }

    private var codexManualSection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.codex.manual.title"),
            subtitle: codexModel.manualSourcePathsDescription,
            trailing: nil,
            palette: palette
        ) {
            if codexModel.settings.manualSourcePaths.isEmpty {
                emptySettingsState(AppLocalization.text("settings.empty.codexManual"))
            } else {
                let bounds = paginationBounds(
                    itemCount: codexModel.settings.manualSourcePaths.count,
                    pageIndex: codexManualPageIndex,
                    pageSize: listPageSize
                )
                let visiblePaths = Array(codexModel.settings.manualSourcePaths[bounds.startIndex..<bounds.endIndex])

                VStack(spacing: 8) {
                    ForEach(Array(visiblePaths.enumerated()), id: \.offset) { offset, path in
                        let index = bounds.startIndex + offset
                        SettingsPathRow(
                            path: path,
                            palette: palette
                        ) {
                            codexModel.removeSourcePath(at: IndexSet(integer: index))
                        }
                    }
                }

                if codexModel.settings.manualSourcePaths.count > listPageSize {
                    PaginationControls(
                        pageIndex: $codexManualPageIndex,
                        itemCount: codexModel.settings.manualSourcePaths.count,
                        pageSize: listPageSize,
                        palette: palette,
                        title: AppLocalization.text("settings.pagination.codexManual")
                    )
                }
            }
        }
    }

    private var safetySection: some View {
        TokenSectionCard(
            title: AppLocalization.text("settings.security.title"),
            subtitle: AppLocalization.text("settings.security.subtitle"),
            trailing: nil,
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(AppLocalization.text("settings.security.body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    openCodeModel.resetSettingsToDefaults()
                } label: {
                    Label(AppLocalization.text("settings.action.restoreDefaults"), systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    private func paginationBounds(itemCount: Int, pageIndex: Int, pageSize: Int) -> (startIndex: Int, endIndex: Int) {
        guard itemCount > 0 else {
            return (0, 0)
        }
        let pageCount = max((itemCount + pageSize - 1) / pageSize, 1)
        let clampedPage = min(max(pageIndex, 0), pageCount - 1)
        let startIndex = clampedPage * pageSize
        let endIndex = min(startIndex + pageSize, itemCount)
        return (startIndex, endIndex)
    }

    private func emptySettingsState(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<TokenCostSettings, Value>) -> Binding<Value> {
        Binding(
            get: { openCodeModel.settings[keyPath: keyPath] },
            set: { newValue in
                openCodeModel.updateSettings { settings in
                    settings[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func codexBinding<Value>(_ keyPath: WritableKeyPath<TokenCostSettings, Value>) -> Binding<Value> {
        Binding(
            get: { codexModel.settings[keyPath: keyPath] },
            set: { newValue in
                codexModel.updateSettings { settings in
                    settings[keyPath: keyPath] = newValue
                }
            }
        )
    }
}

private struct BillingProviderPlanCard: View {
    let provider: BillingProvider
    @ObservedObject var appPreferencesModel: AppPreferencesModel
    let palette: TokenCostPalette

    private var resolvedPlan: ResolvedBillingPlan {
        appPreferencesModel.preferences.resolvedBillingPlan(for: provider)
    }

    private var isCustomSelected: Bool {
        appPreferencesModel.preferences.billingSelection(for: provider).mode == .customMonthlyUSD
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(provider.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.subtitle)

            Picker(provider.displayName, selection: appPreferencesModel.billingPlanOptionBinding(for: provider)) {
                ForEach(BillingPlanCatalog.presets(for: provider)) { preset in
                    Text("\(preset.name) · \(preset.displayPrice)").tag(preset.id)
                }
                Text(AppLocalization.text("settings.billing.customPlan")).tag(BillingPlanCatalog.customOptionID)
            }
            .pickerStyle(.menu)

            if isCustomSelected {
                HStack(spacing: 8) {
                    Text("USD")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.subtitle)

                    TextField(
                        AppLocalization.text("settings.billing.customCost"),
                        value: appPreferencesModel.customBillingCostBinding(for: provider),
                        format: .number.precision(.fractionLength(2))
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                }
            }

            Text(resolvedPlan.priceDescription)
                .font(.caption)
                .foregroundStyle(palette.title)

            if let preset = resolvedPlan.preset {
                Text(preset.usageNote)
                    .font(.caption2)
                    .foregroundStyle(palette.subtitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(palette.cardStroke, lineWidth: 1)
                )
        )
    }
}

private struct SettingsPathRow: View {
    let path: String
    let palette: TokenCostPalette
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .foregroundStyle(palette.accent)

            Text(path)
                .font(.caption)
                .foregroundStyle(palette.title)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.cardStroke.opacity(0.65), lineWidth: 1)
        )
    }
}

private struct CodexDiscoveryRow: View {
    let source: TokenCostSource
    let palette: TokenCostPalette

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(source.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.title)
                        .lineLimit(1)

                    Text(source.locationKind.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.subtitle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(palette.trackBackground, in: Capsule())
                }

                Text(source.displayPath)
                    .font(.caption)
                    .foregroundStyle(palette.subtitle)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let origin = source.originURL?.path, origin != source.displayPath {
                    Text(AppLocalization.format("settings.codex.discovery.origin", origin))
                        .font(.caption2)
                        .foregroundStyle(palette.subtitle)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Text(source.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(palette.subtitle)
            }

            Spacer(minLength: 0)

            SourceStatusPill(source: source, palette: palette)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(palette.cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.cardStroke.opacity(0.65), lineWidth: 1)
        )
    }
}

private struct ThemeChoiceCard: View {
    let choice: TokenCostThemeChoice
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        let palette = TokenCostPalette(theme: choice)
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.backgroundWashTop,
                                palette.backgroundWashBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 58)
                    .overlay(
                        HStack(spacing: 8) {
                            Circle().fill(palette.accent).frame(width: 10, height: 10)
                            Circle().fill(palette.accentSecondary).frame(width: 10, height: 10)
                            Spacer()
                        }
                        .padding(12)
                    )
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(palette.accent)
                                .padding(10)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(choice.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(choice.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(isSelected ? palette.accent : palette.cardStroke, lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: palette.cardShadow, radius: 10, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
    }
}
