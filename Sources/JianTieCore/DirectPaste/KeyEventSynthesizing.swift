//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import CoreGraphics
import Carbon.HIToolbox

/// 按键事件合成协议
public protocol KeyEventSynthesizing: Sendable {
    /// 异步合成并发送 ⌘V 组合键按压与抬起事件（非阻塞）
    @discardableResult
    func synthesizeCommandVAsync() async -> Bool

    /// 同步合成并发送 ⌘V 组合键按压与抬起事件
    @discardableResult
    func synthesizeCommandV() -> Bool
}

public extension KeyEventSynthesizing {
    func synthesizeCommandV() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        Task {
            result = await synthesizeCommandVAsync()
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
}

/// 系统 CGEvent 按键合成器
public final class CGEventKeySynthesizer: KeyEventSynthesizing, @unchecked Sendable {
    public static let shared = CGEventKeySynthesizer()

    public let keyPressDelay: TimeInterval
    public let delayProvider: @Sendable (TimeInterval) async -> Void

    public init(
        keyPressDelay: TimeInterval = 0.015,
        delayProvider: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    ) {
        self.keyPressDelay = keyPressDelay
        self.delayProvider = delayProvider
    }

    @discardableResult
    public func synthesizeCommandVAsync() async -> Bool {
        // macOS ANSI 键盘中 'V' 键的 virtual keycode 为 0x09 (kVK_ANSI_V)
        let vKeyCode: CGKeyCode = 0x09
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return false
        }

        keyDownEvent.flags = .maskCommand
        keyUpEvent.flags = .maskCommand

        keyDownEvent.post(tap: .cghidEventTap)
        // 保持 15ms 的非阻塞物理按压微延迟，确保跨进程事件循环与不同 UI 框架能够稳定捕获
        await delayProvider(keyPressDelay)
        keyUpEvent.post(tap: .cghidEventTap)

        return true
    }

    @discardableResult
    public func synthesizeCommandV() -> Bool {
        let vKeyCode: CGKeyCode = 0x09
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return false
        }

        keyDownEvent.flags = .maskCommand
        keyUpEvent.flags = .maskCommand

        keyDownEvent.post(tap: .cghidEventTap)
        usleep(useconds_t(keyPressDelay * 1_000_000))
        keyUpEvent.post(tap: .cghidEventTap)

        return true
    }
}
