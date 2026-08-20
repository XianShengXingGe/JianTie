import Foundation
import AppKit
import Carbon.HIToolbox

/// 全局双击 ⌘ 监听服务
public final class DoubleTapMonitor: DoubleTapMonitoring, @unchecked Sendable {
    public let detector: DoubleTapDetector
    public private(set) var isMonitoring: Bool = false

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var triggerHandler: (@Sendable () -> Void)?
    private let lock = NSLock()

    public init(detector: DoubleTapDetector = DoubleTapDetector(maxInterval: 0.3)) {
        self.detector = detector
    }

    public func startMonitoring(onTrigger: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        guard !isMonitoring else { return }
        self.triggerHandler = onTrigger
        self.isMonitoring = true
        self.detector.reset()

        // 1. 全局事件监听（当简贴处于后台，其他 App 为前台时）
        self.globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            self?.processEvent(event)
        }

        // 2. 本地事件监听（当简贴自身窗口拥有焦点时）
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
            let isCommand = flags.contains(.command)
            let otherModifiers = flags.contains(.shift) ||
                                 flags.contains(.control) ||
                                 flags.contains(.option)

            let triggered = detector.handleFlagsChanged(
                isCommandPressed: isCommand,
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
