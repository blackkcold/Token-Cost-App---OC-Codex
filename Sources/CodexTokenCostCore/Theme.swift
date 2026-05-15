import Foundation

public enum TokenCostThemeChoice: String, Codable, CaseIterable, Sendable {
    case ocean
    case forest
    case sunset
    case violet

    public var displayName: String {
        switch self {
        case .ocean: return "海湾蓝"
        case .forest: return "森林绿"
        case .sunset: return "暮光橙"
        case .violet: return "极光紫"
        }
    }

    public var summary: String {
        switch self {
        case .ocean: return "干净，冷静，最稳妥"
        case .forest: return "清爽，柔和，偏自然"
        case .sunset: return "更温暖，更醒目"
        case .violet: return "更强识别度，更有活力"
        }
    }
}
