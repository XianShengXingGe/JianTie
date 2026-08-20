import Foundation
import CoreGraphics
#if canImport(AppKit)
import AppKit
#endif

/// 边缘停留与自动缩回监听器
public final class ShelfEdgeMonitor: @unchecked Sendable {
    public let detector: EdgeDwellDetector
    public private(set) var isMonitoring: Bool = false

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var heartbeatTimer: Timer?

    private var onDwellTrigger: (@Sendable (ScreenInfo) -> Void)?
    private var onRetractTrigger: (@Sendable () -> Void)?

    private let screensProvider: @Sendable () -> [ScreenInfo]
    private let edgeProvider: @Sendable () -> ShelfEdge
    private let isRevealedProvider: @Sendable () -> Bool
    private let shelfFrameProvider: @Sendable () -> CGRect?

    private let lock = NSLock()

    public init(
        detector: EdgeDwellDetector = EdgeDwellDetector(),
        screensProvider: @escaping @Sendable () -> [ScreenInfo] = {
            #if canImport(AppKit)
            return ScreenInfo.currentScreens()
            #else
            return []
            #endif
        },
        edgeProvider: @escaping @Sendable () -> ShelfEdge = { .left },
        isRevealedProvider: @escaping @Sendable () -> Bool = { false },
        shelfFrameProvider: @escaping @Sendable () -> CGRect? = { nil }
    ) {
        self.detector = detector
        self.screensProvider = screensProvider
        self.edgeProvider = edgeProvider
        self.isRevealedProvider = isRevealedProvider
        self.shelfFrameProvider = shelfFrameProvider
    }

    public func startMonitoring(
        onDwell: @escaping @Sendable (ScreenInfo) -> Void,
        onRetract: @escaping @Sendable () -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }

        guard !isMonitoring else { return }
        self.onDwellTrigger = onDwell
        self.onRetractTrigger = onRetract
        self.isMonitoring = true
        self.detector.reset()

        #if canImport(AppKit)
        // 1. 监听全局鼠标移动
        self.globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved]
        ) { [weak self] event in
            self?.processMouseMove(location: NSEvent.mouseLocation, timestamp: event.timestamp)
        }

        // 2. 监听本地鼠标移动
        self.localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved]
        ) { [weak self] event in
            self?.processMouseMove(location: NSEvent.mouseLocation, timestamp: event.timestamp)
            return event
        }

        // 3. 启动 50ms 心跳定时器驱动时间阈值检查（即使用户鼠标静止不动也能准确触发 150ms 唤出与 600ms 缩回）
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isMonitoring else { return }
            self.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                self?.processHeartbeat()
            }
        }
        #endif
    }

    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        guard isMonitoring else { return }

        #if canImport(AppKit)
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer?.invalidate()
            self?.heartbeatTimer = nil
        }
        #endif

        onDwellTrigger = nil
        onRetractTrigger = nil
        isMonitoring = false
        detector.reset()
    }

    /// 处理鼠标移动事件
    public func processMouseMove(location: CGPoint, timestamp: TimeInterval) {
        let screens = screensProvider()
        let edge = edgeProvider()
        let isRevealed = isRevealedProvider()
        let shelfFrame = shelfFrameProvider()

        let action = detector.handleMouseMove(
            point: location,
            timestamp: timestamp,
            screens: screens,
            edge: edge,
            isShelfRevealed: isRevealed,
            shelfFrame: shelfFrame
        )

        dispatchAction(action)
    }

    /// 处理定时心跳
    public func processHeartbeat(timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        let isRevealed = isRevealedProvider()
        let action = detector.checkTimer(timestamp: timestamp, isShelfRevealed: isRevealed)
        dispatchAction(action)
    }

    /// 鼠标移入 Shelf 区域通知
    public func notifyMouseEnteredShelf() {
        detector.handleMouseEnteredShelf()
    }

    /// 鼠标移出 Shelf 区域通知
    public func notifyMouseExitedShelf(timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        detector.handleMouseExitedShelf(timestamp: timestamp)
    }

    private func dispatchAction(_ action: EdgeDwellDetector.Action) {
        switch action {
        case .reveal(let screen):
            let callback = onDwellTrigger
            DispatchQueue.main.async {
                callback?(screen)
            }
        case .retract:
            let callback = onRetractTrigger
            DispatchQueue.main.async {
                callback?()
            }
        case .none:
            break
        }
    }

    deinit {
        stopMonitoring()
    }
}
