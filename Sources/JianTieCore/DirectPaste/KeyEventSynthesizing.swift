import Foundation
import CoreGraphics
import Carbon.HIToolbox

/// 按键事件合成协议
public protocol KeyEventSynthesizing: Sendable {
    /// 合成并发送 ⌘V 组合键按压与抬起事件
    @discardableResult
    func synthesizeCommandV() -> Bool
}

/// 系统 CGEvent 按键合成器
public final class CGEventKeySynthesizer: KeyEventSynthesizing, @unchecked Sendable {
    public static let shared = CGEventKeySynthesizer()

    public init() {}

    @discardableResult
    public func synthesizeCommandV() -> Bool {
        // macOS ANSI 键盘中 'V' 键的 virtual keycode 为 0x09 (kVK_ANSI_V)
        let vKeyCode: CGKeyCode = 0x09
        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return false
        }

        keyDownEvent.flags = .maskCommand
        keyUpEvent.flags = .maskCommand

        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)

        return true
    }
}
