//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// 基础修饰键类型（用于双击与单修饰键选择）
public enum ModifierKey: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case command
    case option
    case control
    case shift

    /// 符号显示 (如 "⌘", "⌥", "⌃", "⇧")
    public var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }

    /// 本地化描述 (如 "Command (⌘)", "Option (⌥)")
    public var localizedName: String {
        switch self {
        case .command: return "Command (⌘)"
        case .option: return "Option (⌥)"
        case .control: return "Control (⌃)"
        case .shift: return "Shift (⇧)"
        }
    }

    /// 双击文本显示 (如 "双击 ⌘" / "Double-Tap ⌘")
    public var doubleTapTitle: String {
        return L10n.tr("hotkey.double_tap", symbol)
    }
}
