import SwiftUI
import CodexTokenCostCore

enum TokenCostFormatters {
    static func tokens(_ value: Double) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(1)))
    }

    static func millionRate(_ value: Double) -> String {
        String(format: "%.2fM/$", value / 1_000_000)
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }

    static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }
}

struct TokenMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color
    let palette: TokenCostPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.subtitle)

                Spacer(minLength: 0)
            }

            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.title)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(palette.subtitle)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(palette.cardStroke, lineWidth: 1)
                )
                .shadow(color: palette.cardShadow, radius: 14, x: 0, y: 8)
        )
    }
}

struct TokenSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let trailing: AnyView?
    let palette: TokenCostPalette
    let content: Content

    init(
        title: String,
        subtitle: String,
        trailing: AnyView?,
        palette: TokenCostPalette,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(palette.title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(palette.subtitle)
                }

                Spacer(minLength: 0)

                trailing
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(palette.cardStroke, lineWidth: 1)
                )
                .shadow(color: palette.cardShadow, radius: 16, x: 0, y: 10)
        )
    }
}

struct DistributionRow: View {
    let title: String
    let value: Double
    let total: Double
    let tint: Color
    let palette: TokenCostPalette
    var suffix: String = ""
    var valueLabel: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.title)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(valueLabel ?? TokenCostFormatters.tokens(value))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.title)
            }

            GeometryReader { proxy in
                let ratio = total > 0 ? min(max(value / total, 0), 1) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(palette.trackBackground)
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 8)

            if !suffix.isEmpty {
                Text(suffix)
                    .font(.caption2)
                    .foregroundStyle(palette.subtitle)
            }
        }
    }
}

struct SourceStatusPill: View {
    let source: TokenCostSource
    let palette: TokenCostPalette

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch source.status {
        case .available: return palette.accent
        case .locked: return .orange
        case .unsupported: return .yellow
        case .missing: return .red
        case .unknown: return palette.subtitle
        }
    }

    private var background: Color {
        foreground.opacity(0.14)
    }

    private var label: String {
        switch source.status {
        case .available: return "可用"
        case .locked: return "锁定"
        case .unsupported: return "不兼容"
        case .missing: return "缺失"
        case .unknown: return "未知"
        }
    }
}
