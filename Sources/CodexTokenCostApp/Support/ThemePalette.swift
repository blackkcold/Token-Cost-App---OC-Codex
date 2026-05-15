import AppKit
import SwiftUI
import CodexTokenCostCore

struct TokenCostPalette {
    let theme: TokenCostThemeChoice
    let accent: Color
    let accentSecondary: Color
    let accentSoft: Color
    let backgroundBase: Color
    let backgroundWashTop: Color
    let backgroundWashBottom: Color
    let cardFill: Material
    let cardStroke: Color
    let cardShadow: Color
    let trackBackground: Color
    let title: Color
    let subtitle: Color
    let chipText: Color
    let chipBackground: Color

    init(theme: TokenCostThemeChoice) {
        self.theme = theme

        switch theme {
        case .ocean:
            accent = Color(red: 0.18, green: 0.52, blue: 0.98)
            accentSecondary = Color(red: 0.16, green: 0.78, blue: 0.88)
            accentSoft = Color(red: 0.18, green: 0.52, blue: 0.98).opacity(0.10)
            backgroundWashTop = Color(red: 0.18, green: 0.52, blue: 0.98).opacity(0.16)
            backgroundWashBottom = Color(red: 0.16, green: 0.78, blue: 0.88).opacity(0.12)
            cardStroke = Color(red: 0.18, green: 0.52, blue: 0.98).opacity(0.18)
            chipBackground = Color(red: 0.18, green: 0.52, blue: 0.98).opacity(0.14)
        case .forest:
            accent = Color(red: 0.14, green: 0.69, blue: 0.47)
            accentSecondary = Color(red: 0.39, green: 0.81, blue: 0.56)
            accentSoft = Color(red: 0.14, green: 0.69, blue: 0.47).opacity(0.10)
            backgroundWashTop = Color(red: 0.14, green: 0.69, blue: 0.47).opacity(0.14)
            backgroundWashBottom = Color(red: 0.39, green: 0.81, blue: 0.56).opacity(0.10)
            cardStroke = Color(red: 0.14, green: 0.69, blue: 0.47).opacity(0.18)
            chipBackground = Color(red: 0.14, green: 0.69, blue: 0.47).opacity(0.14)
        case .sunset:
            accent = Color(red: 0.95, green: 0.46, blue: 0.18)
            accentSecondary = Color(red: 0.97, green: 0.68, blue: 0.18)
            accentSoft = Color(red: 0.95, green: 0.46, blue: 0.18).opacity(0.10)
            backgroundWashTop = Color(red: 0.95, green: 0.46, blue: 0.18).opacity(0.15)
            backgroundWashBottom = Color(red: 0.97, green: 0.68, blue: 0.18).opacity(0.10)
            cardStroke = Color(red: 0.95, green: 0.46, blue: 0.18).opacity(0.18)
            chipBackground = Color(red: 0.95, green: 0.46, blue: 0.18).opacity(0.14)
        case .violet:
            accent = Color(red: 0.62, green: 0.37, blue: 0.96)
            accentSecondary = Color(red: 0.91, green: 0.39, blue: 0.88)
            accentSoft = Color(red: 0.62, green: 0.37, blue: 0.96).opacity(0.10)
            backgroundWashTop = Color(red: 0.62, green: 0.37, blue: 0.96).opacity(0.15)
            backgroundWashBottom = Color(red: 0.91, green: 0.39, blue: 0.88).opacity(0.10)
            cardStroke = Color(red: 0.62, green: 0.37, blue: 0.96).opacity(0.18)
            chipBackground = Color(red: 0.62, green: 0.37, blue: 0.96).opacity(0.14)
        }

        backgroundBase = Color(nsColor: .windowBackgroundColor)
        cardFill = .regularMaterial
        cardShadow = Color.black.opacity(0.10)
        trackBackground = Color.primary.opacity(0.08)
        title = Color.primary
        subtitle = Color.secondary
        chipText = accent
    }

    var pageBackground: some View {
        ZStack {
            backgroundBase
            LinearGradient(
                colors: [
                    backgroundWashTop,
                    .clear,
                    backgroundWashBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)
            .opacity(0.9)

            RadialGradient(
                colors: [
                    accentSoft,
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 720
            )
            .blendMode(.screen)
        }
    }
}
