//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import Carbon.HIToolbox

/// 原生 Carbon 热键监听协议
public protocol CarbonHotKeyMonitoring: AnyObject, Sendable {
    /// 当前是否已注册热键
    var isRegistered: Bool { get }

    /// 注册全局组合按键
    /// - Parameters:
    ///   - keyCode: 虚拟键码
    ///   - modifiers: 修饰键掩码
    ///   - onTrigger: 快捷键触发回调
    /// - Returns: 是否注册成功
    func register(keyCode: UInt32, modifiers: KeyModifiers, onTrigger: @escaping @Sendable () -> Void) -> Bool

    /// 注销当前热键
    func unregister()
}

/// 基于 macOS Carbon EventHotKey 的全局快捷键监听器（免辅助功能权限）
public final class CarbonHotKeyMonitor: CarbonHotKeyMonitoring, @unchecked Sendable {
    public private(set) var isRegistered: Bool = false

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var triggerHandler: (@Sendable () -> Void)?
    private let lock = NSLock()
    private let hotKeySignature: OSType = 0x4A54484B // 'JTHK' (JianTie HotKey)
    private let hotKeyIDValue: UInt32 = 1

    public init() {}

    public func register(
        keyCode: UInt32,
        modifiers: KeyModifiers,
        onTrigger: @escaping @Sendable () -> Void
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // 如果已有注册，先注销
        if isRegistered {
            cleanupUnsafe()
        }

        self.triggerHandler = onTrigger

        // 1. 安装 Carbon 事件处理器（如果尚未安装）
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData, let event = event else {
                    return noErr
                }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr {
                    let monitor = Unmanaged<CarbonHotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                    monitor.handleHotKeyTrigger(id: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            return false
        }

        // 2. 注册 Carbon EventHotKey
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyIDValue)
        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers.carbonModifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard registerStatus == noErr, let validRef = ref else {
            if let handlerRef = eventHandlerRef {
                RemoveEventHandler(handlerRef)
                eventHandlerRef = nil
            }
            return false
        }

        self.hotKeyRef = validRef
        self.isRegistered = true
        return true
    }

    public func unregister() {
        lock.lock()
        defer { lock.unlock() }
        cleanupUnsafe()
    }

    private func cleanupUnsafe() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
            eventHandlerRef = nil
        }
        triggerHandler = nil
        isRegistered = false
    }

    fileprivate func handleHotKeyTrigger(id: UInt32) {
        guard id == hotKeyIDValue else { return }
        triggerHandler?()
    }

    deinit {
        unregister()
    }
}
