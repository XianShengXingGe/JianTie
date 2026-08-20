//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// 统一热键触发模式数据模型
public enum HotKeyTrigger: Codable, Equatable, Hashable, Sendable {
    case doubleTap(modifier: ModifierKey)
    case keyCombination(keyCode: UInt32, modifiers: KeyModifiers)

    /// 默认全局呼出快捷键：双击 Command
    public static let `default`: HotKeyTrigger = .doubleTap(modifier: .command)

    /// 人类可读格式化标题（如 "双击 ⌘", "⌥V", "⇧⌘V", "F1", "⌥F5"）
    public var displayTitle: String {
        switch self {
        case .doubleTap(let modifier):
            return modifier.doubleTapTitle
        case .keyCombination(let keyCode, let modifiers):
            let keyString = KeyCodeHelper.title(for: keyCode)
            return "\(modifiers.displaySymbols)\(keyString)"
        }
    }
}
