import SwiftUI

enum TokenCostSeriesPalette {
    private static let colors: [Color] = [
        Color(red: 0.18, green: 0.52, blue: 0.98),
        Color(red: 0.14, green: 0.69, blue: 0.47),
        Color(red: 0.95, green: 0.46, blue: 0.18),
        Color(red: 0.62, green: 0.37, blue: 0.96),
        Color(red: 0.22, green: 0.78, blue: 0.88),
        Color(red: 0.91, green: 0.39, blue: 0.88),
        Color(red: 0.89, green: 0.66, blue: 0.16),
        Color(red: 0.87, green: 0.26, blue: 0.32),
        Color(red: 0.28, green: 0.62, blue: 0.91),
        Color(red: 0.32, green: 0.77, blue: 0.62)
    ]

    static let neutral = Color.secondary.opacity(0.55)

    static func color(for key: String) -> Color {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return neutral
        }
        let index = Int(stableHash(normalized) % UInt64(colors.count))
        return colors[index]
    }

    static func otherColor() -> Color {
        .secondary.opacity(0.35)
    }

    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}
