//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// 统一热键调度引擎服务：协同 DoubleTapMonitor 与 CarbonHotKeyMonitor
public final class HotKeyService: HotKeyServiceProviding, @unchecked Sendable {
    public private(set) var currentTrigger: HotKeyTrigger
    public private(set) var isMonitoring: Bool = false

    private let doubleTapMonitorFactory: @Sendable (ModifierKey) -> DoubleTapMonitoring
    private let carbonHotKeyMonitor: CarbonHotKeyMonitoring
    private var activeDoubleTapMonitor: DoubleTapMonitoring?
    private var triggerHandler: (@Sendable () -> Void)?
    private let lock = NSLock()

    public init(
        initialTrigger: HotKeyTrigger = .default,
        doubleTapMonitorFactory: @escaping @Sendable (ModifierKey) -> DoubleTapMonitoring = { DoubleTapMonitor(targetModifier: $0) },
        carbonHotKeyMonitor: CarbonHotKeyMonitoring = CarbonHotKeyMonitor()
    ) {
        self.currentTrigger = initialTrigger
        self.doubleTapMonitorFactory = doubleTapMonitorFactory
        self.carbonHotKeyMonitor = carbonHotKeyMonitor
    }

    public func startMonitoring(onTrigger: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        guard !isMonitoring else { return }
        self.triggerHandler = onTrigger
        self.isMonitoring = true
        applyTriggerUnsafe(currentTrigger)
    }

    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        guard isMonitoring else { return }
        tearDownActiveMonitorsUnsafe()
        triggerHandler = nil
        isMonitoring = false
    }

    public func updateTrigger(_ trigger: HotKeyTrigger) {
        lock.lock()
        defer { lock.unlock() }

        guard currentTrigger != trigger else { return }
        self.currentTrigger = trigger

        if isMonitoring {
            tearDownActiveMonitorsUnsafe()
            applyTriggerUnsafe(trigger)
        }
    }

    private func applyTriggerUnsafe(_ trigger: HotKeyTrigger) {
        guard let handler = triggerHandler else { return }

        switch trigger {
        case .doubleTap(let modifier):
            let monitor = doubleTapMonitorFactory(modifier)
            monitor.startMonitoring(onTrigger: handler)
            self.activeDoubleTapMonitor = monitor

        case .keyCombination(let keyCode, let modifiers):
            _ = carbonHotKeyMonitor.register(keyCode: keyCode, modifiers: modifiers, onTrigger: handler)
        }
    }

    private func tearDownActiveMonitorsUnsafe() {
        if let monitor = activeDoubleTapMonitor {
            monitor.stopMonitoring()
            activeDoubleTapMonitor = nil
        }
        if carbonHotKeyMonitor.isRegistered {
            carbonHotKeyMonitor.unregister()
        }
    }

    deinit {
        stopMonitoring()
    }
}
