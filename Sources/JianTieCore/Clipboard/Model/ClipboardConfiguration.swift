import Foundation

/// 剪贴板历史容量上限配置
public enum ClipboardCapacityLimit: Int, CaseIterable, Identifiable, Codable, Sendable {
    case count50 = 50
    case count100 = 100
    case count300 = 300
    case count500 = 500
    case count1000 = 1000
    case unlimited = 0

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .count50: return "50 条"
        case .count100: return "100 条"
        case .count300: return "300 条"
        case .count500: return "500 条"
        case .count1000: return "1000 条"
        case .unlimited: return "无限制"
        }
    }

    public var maxCount: Int? {
        self == .unlimited ? nil : rawValue
    }
}

/// 剪贴板历史保存周期配置
public enum ClipboardRetentionPeriod: Int, CaseIterable, Identifiable, Codable, Sendable {
    case days3 = 3
    case days7 = 7
    case days30 = 30
    case days90 = 90
    case days180 = 180
    case unlimited = 0

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .days3: return "3 天"
        case .days7: return "7 天"
        case .days30: return "30 天"
        case .days90: return "90 天"
        case .days180: return "180 天"
        case .unlimited: return "永久保留"
        }
    }

    public var days: Int? {
        self == .unlimited ? nil : rawValue
    }
}
