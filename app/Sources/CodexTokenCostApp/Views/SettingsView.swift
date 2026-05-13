import SwiftUI
import CodexTokenCostCore

struct SettingsView: View {
    @ObservedObject var openCodeModel: TokenCostModel
    @ObservedObject var codexModel: CodexSessionModel
    @Environment(\.dismiss) private var dismiss

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

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("设置")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(palette.title)

            Text("调整主题、来源扫描和本地快照。OpenCode 和 Codex 分别使用独立的配置文件与支持目录。")
                .font(.callout)
                .foregroundStyle(palette.subtitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var themeSection: some View {
        TokenSectionCard(title: "主题", subtitle: "视觉风格只影响界面，不影响数据边界", trailing: nil, palette: palette) {
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
            Text("Codex")
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.title)

            Text("配置 Codex app 读取的 session 目录和 session 文件。")
                .font(.callout)
                .foregroundStyle(palette.subtitle)
            Text("默认会自动扫描两个系统位置，你只需要在需要时补充额外目录或单个文件。")
                .font(.caption)
                .foregroundStyle(palette.subtitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private var codexDiscoverySection: some View {
        TokenSectionCard(
            title: "Codex 来源确认",
            subtitle: codexModel.shouldPromptForSourceConfirmation ? "启动时会自动确认默认目录" : "当前已找到可读来源",
            trailing: nil,
            palette: palette
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text("应用会自动检查 `~/.codex/sessions` 和 `~/.codex/archived_sessions`，并纳入你额外添加的目录或文件。下面列出当前确认过的位置；如果暂时不想配置，可以直接关闭这个窗口。")
                    .font(.callout)
                    .foregroundStyle(palette.subtitle)
                    .fixedSize(horizontal: false, vertical: true)

                if codexModel.discoverySources.isEmpty {
                    emptySettingsState("正在等待 Codex 来源扫描结果")
                } else {
                    VStack(spacing: 8) {
                        ForEach(codexModel.discoverySources) { source in
                            CodexDiscoveryRow(source: source, palette: palette)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
                    Button {
                        codexModel.refresh()
                    } label: {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }

                    Button {
                        codexModel.addSourceRoot()
                    } label: {
                        Label("选择目录", systemImage: "folder.badge.plus")
                    }

                    Button {
                        codexModel.addSourceFile()
                    } label: {
                        Label("选择文件", systemImage: "doc.badge.plus")
                    }

                    Button {
                        dismiss()
                    } label: {
                        Label("关闭", systemImage: "xmark")
                    }
                }
            }
        }
    }

    private var sourceSection: some View {
        TokenSectionCard(title: "来源", subtitle: "扫描与刷新策略", trailing: nil, palette: palette) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("启动时自动扫描", isOn: binding(\.autoRescan))

                Stepper(value: binding(\.maxScanDepth), in: 1...8) {
                    Text("扫描深度：\(openCodeModel.settings.maxScanDepth)")
                }

                Stepper(value: binding(\.snapshotRetentionCount), in: 1...20) {
                    Text("快照保留：\(openCodeModel.settings.snapshotRetentionCount)")
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 12)], spacing: 12) {
                    Button {
                        openCodeModel.addScanRoot()
                    } label: {
                        Label("添加安装目录", systemImage: "folder.badge.plus")
                    }

                    Button {
                        openCodeModel.addDatabaseFile()
                    } label: {
                        Label("添加数据库文件", systemImage: "externaldrive.badge.plus")
                    }

                    Button {
                        openCodeModel.rescanSources()
                    } label: {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var scanRootsSection: some View {
        TokenSectionCard(title: "已配置安装目录", subtitle: "自动扫描范围", trailing: nil, palette: palette) {
            if openCodeModel.settings.scanRoots.isEmpty {
                emptySettingsState("未添加扫描目录")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(openCodeModel.settings.scanRoots.enumerated()), id: \.offset) { index, path in
                        SettingsPathRow(
                            path: path,
                            palette: palette
                        ) {
                            openCodeModel.removeScanRoot(at: IndexSet(integer: index))
                        }
                    }
                }
            }
        }
    }

    private var manualDatabaseSection: some View {
        TokenSectionCard(title: "手动数据库", subtitle: "直接添加数据库文件", trailing: nil, palette: palette) {
            if openCodeModel.settings.manualDatabasePaths.isEmpty {
                emptySettingsState("未添加数据库文件")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(openCodeModel.settings.manualDatabasePaths.enumerated()), id: \.offset) { index, path in
                        SettingsPathRow(
                            path: path,
                            palette: palette
                        ) {
                            openCodeModel.removeDatabasePath(at: IndexSet(integer: index))
                        }
                    }
                }
            }
        }
    }

    private var codexSection: some View {
        TokenSectionCard(title: "Codex 来源", subtitle: "session 目录与文件", trailing: nil, palette: palette) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("启动时自动刷新", isOn: codexBinding(\.autoRescan))

                Stepper(value: codexBinding(\.snapshotRetentionCount), in: 1...20) {
                    Text("快照保留：\(codexModel.settings.snapshotRetentionCount)")
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: 12)], spacing: 12) {
                    Button {
                        codexModel.addSourceRoot()
                    } label: {
                        Label("添加 session 目录", systemImage: "folder.badge.plus")
                    }

                    Button {
                        codexModel.addSourceFile()
                    } label: {
                        Label("添加 session 文件", systemImage: "doc.badge.plus")
                    }

                    Button {
                        codexModel.refresh()
                    } label: {
                        Label("刷新 Codex", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        codexModel.resetSettingsToDefaults()
                    } label: {
                        Label("恢复 Codex 默认设置", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
    }

    private var codexRootsSection: some View {
        TokenSectionCard(title: "已配置 session 目录", subtitle: codexModel.sourceRootsDescription, trailing: nil, palette: palette) {
            if codexModel.settings.sourceRoots.isEmpty {
                emptySettingsState("未添加 session 目录")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(codexModel.settings.sourceRoots.enumerated()), id: \.offset) { index, path in
                        SettingsPathRow(
                            path: path,
                            palette: palette
                        ) {
                            codexModel.removeSourceRoot(at: IndexSet(integer: index))
                        }
                    }
                }
            }
        }
    }

    private var codexManualSection: some View {
        TokenSectionCard(title: "手动 session 文件", subtitle: codexModel.manualSourcePathsDescription, trailing: nil, palette: palette) {
            if codexModel.settings.manualSourcePaths.isEmpty {
                emptySettingsState("未添加 session 文件")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(codexModel.settings.manualSourcePaths.enumerated()), id: \.offset) { index, path in
                        SettingsPathRow(
                            path: path,
                            palette: palette
                        ) {
                            codexModel.removeSourcePath(at: IndexSet(integer: index))
                        }
                    }
                }
            }
        }
    }

    private var safetySection: some View {
        TokenSectionCard(title: "安全边界", subtitle: "只读来源文件，只写本地 App 状态", trailing: nil, palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                Text("App 只会读取你显式授权的来源路径，只会把配置和快照写到各自 App 的 state 目录，不会改写 OpenCode 数据库、Codex session 文件或原网页工具文件。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    openCodeModel.resetSettingsToDefaults()
                } label: {
                    Label("恢复默认设置", systemImage: "arrow.counterclockwise")
                }
            }
        }
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
                    Text("来源：\(origin)")
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
