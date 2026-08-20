//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import AppKit
import Carbon.HIToolbox

/// 全局双击修饰键监听服务
public final class DoubleTapMonitor: DoubleTapMonitoring, @unchecked Sendable {
    public let detector: DoubleTapDetector
    public let targetModifier: ModifierKey
    public private(set) var isMonitoring: Bool = false

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var triggerHandler: (@Sendable () -> Void)?
    private let lock = NSLock()

    public init(
        targetModifier: ModifierKey = .command,
        detector: DoubleTapDetector? = nil
    ) {
        self.targetModifier = targetModifier
        self.detector = detector ?? DoubleTapDetector(targetModifier: targetModifier, maxInterval: 0.3)
    }

    public func startMonitoring(onTrigger: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        guard !isMonitoring else { return }
        self.triggerHandler = onTrigger
        self.isMonitoring = true
        self.detector.reset()

        // 1. 全局事件监听（当应用处于后台，其他 App 为前台时）
        self.globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            self?.processEvent(event)
        }

        // 2. 本地事件监听（当应用自身窗口拥有焦点时）
        self.localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            self?.processEvent(event)
            return event
        }
    }

    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        guard isMonitoring else { return }

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        triggerHandler = nil
        isMonitoring = false
        detector.reset()
    }

    /// 处理 NSEvent 事件
    public func processEvent(_ event: NSEvent) {
        let timestamp = event.timestamp

        switch event.type {
        case .flagsChanged:
            let flags = event.modifierFlags
            let isTarget: Bool
            let otherModifiers: Bool

            switch targetModifier {
            case .command:
                isTarget = flags.contains(.command)
                otherModifiers = flags.contains(.shift) || flags.contains(.control) || flags.contains(.option)
            case .option:
                isTarget = flags.contains(.option)
                otherModifiers = flags.contains(.shift) || flags.contains(.control) || flags.contains(.command)
            case .control:
                isTarget = flags.contains(.control)
                otherModifiers = flags.contains(.shift) || flags.contains(.option) || flags.contains(.command)
            case .shift:
                isTarget = flags.contains(.shift)
                otherModifiers = flags.contains(.control) || flags.contains(.option) || flags.contains(.command)
            }

            let triggered = detector.handleFlagsChanged(
                isTargetPressed: isTarget,
                otherModifiersPressed: otherModifiers,
                timestamp: timestamp
            )

            if triggered {
                triggerHandler?()
            }

        case .keyDown, .keyUp:
            detector.handleKeyEvent(timestamp: timestamp)

        default:
            break
        }
    }

    deinit {
        stopMonitoring()
    }
}
