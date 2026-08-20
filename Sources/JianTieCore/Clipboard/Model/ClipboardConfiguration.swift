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
        case .count50: return L10n.tr("capacity.count50")
        case .count100: return L10n.tr("capacity.count100")
        case .count300: return L10n.tr("capacity.count300")
        case .count500: return L10n.tr("capacity.count500")
        case .count1000: return L10n.tr("capacity.count1000")
        case .unlimited: return L10n.tr("capacity.unlimited")
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
        case .days3: return L10n.tr("retention.days3")
        case .days7: return L10n.tr("retention.days7")
        case .days30: return L10n.tr("retention.days30")
        case .days90: return L10n.tr("retention.days90")
        case .days180: return L10n.tr("retention.days180")
        case .unlimited: return L10n.tr("retention.unlimited")
        }
    }

    public var days: Int? {
        self == .unlimited ? nil : rawValue
    }
}
