//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// 应用支持的界面语言类型
public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"

    public var id: String { rawValue }

    /// 语言选项显示名称
    public var displayName: String {
        switch self {
        case .system:
            return "跟随系统 (System Default)"
        case .zhHans:
            return "简体中文 (Simplified Chinese)"
        case .en:
            return "English"
        }
    }

    /// 解析当前生效的实际语言 (将 .system 解析为具体的 .zhHans 或 .en)
    public func resolveEffectiveLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        switch self {
        case .zhHans:
            return .zhHans
        case .en:
            return .en
        case .system:
            guard let primary = preferredLanguages.first?.lowercased() else {
                return .en
            }
            if primary.hasPrefix("zh") {
                return .zhHans
            }
            return .en
        }
    }
}
