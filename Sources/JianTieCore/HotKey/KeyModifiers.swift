//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import AppKit
import Carbon.HIToolbox

/// 组合键修饰键掩码集合
public struct KeyModifiers: OptionSet, Codable, Equatable, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let option = KeyModifiers(rawValue: 1 << 1)
    public static let control = KeyModifiers(rawValue: 1 << 2)
    public static let shift = KeyModifiers(rawValue: 1 << 3)

    /// 转换为 Carbon 框架修饰键掩码
    public var carbonModifierFlags: UInt32 {
        var carbonFlags: UInt32 = 0
        if contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if contains(.option) { carbonFlags |= UInt32(optionKey) }
        if contains(.control) { carbonFlags |= UInt32(controlKey) }
        if contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        return carbonFlags
    }

    /// 按照 macOS 标准顺序 (⌃ ⌥ ⇧ ⌘) 返回符号组合字符串
    public var displaySymbols: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }

    /// 从 NSEvent.ModifierFlags 转换为 KeyModifiers
    public static func from(eventModifierFlags flags: NSEvent.ModifierFlags) -> KeyModifiers {
        var modifiers: KeyModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }

    /// 转换为 NSEvent.ModifierFlags
    public var eventModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command) { flags.insert(.command) }
        if contains(.option) { flags.insert(.option) }
        if contains(.control) { flags.insert(.control) }
        if contains(.shift) { flags.insert(.shift) }
        return flags
    }
}
