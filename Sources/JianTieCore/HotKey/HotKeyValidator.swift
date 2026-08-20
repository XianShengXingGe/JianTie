import Foundation

/// 快捷键防呆校验错误类型
public enum HotKeyValidationError: Error, Equatable, Sendable {
    case modifierRequired
    case invalidKeyCode

    public var localizedDescription: String {
        switch self {
        case .modifierRequired:
            return L10n.tr("hotkey.modifier_required")
        case .invalidKeyCode:
            return L10n.tr("hotkey.invalid_key_combo")
        }
    }
}

/// 快捷键校验结果
public struct HotKeyValidationResult: Equatable, Sendable {
    public let isValid: Bool
    public let error: HotKeyValidationError?

    public static let success = HotKeyValidationResult(isValid: true, error: nil)
    public static func failure(_ error: HotKeyValidationError) -> HotKeyValidationResult {
        HotKeyValidationResult(isValid: false, error: error)
    }
}

/// 快捷键输入与组合校验器
public enum HotKeyValidator {

    /// 校验指定的按键与修饰键组合是否合法
    /// - Parameters:
    ///   - keyCode: macOS 虚拟键码
    ///   - modifiers: 修饰键掩码
    /// - Returns: 校验结果
    public static func validate(keyCode: UInt32, modifiers: KeyModifiers) -> HotKeyValidationResult {
        // 1. 如果包含修饰键 (⌘/⌥/⌃/⇧)，组合键合法
        if !modifiers.isEmpty {
            return .success
        }

        // 2. 如果不包含修饰键，仅允许 F1~F20 功能键单独作为全局快捷键
        if KeyCodeHelper.isFunctionKey(keyCode) {
            return .success
        }

        // 3. 其他所有未带修饰键的单字符/控制键一律拒绝，防止劫持全局输入
        return .failure(.modifierRequired)
    }

    /// 校验统一热键触发模式模型是否合法
    public static func validate(trigger: HotKeyTrigger) -> HotKeyValidationResult {
        switch trigger {
        case .doubleTap:
            return .success
        case .keyCombination(let keyCode, let modifiers):
            return validate(keyCode: keyCode, modifiers: modifiers)
        }
    }
}
