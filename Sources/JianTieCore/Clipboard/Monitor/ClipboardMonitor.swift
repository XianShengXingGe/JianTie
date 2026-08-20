//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// 剪贴板后台监听器，基于 changeCount 轮询实现低 CPU 开销捕获
public final class ClipboardMonitor: @unchecked Sendable {
    public let pasteboard: PasteboardProviding
    public let pollInterval: TimeInterval
    public let onItemCaptured: @Sendable (ClipboardItem) -> Void

    private let queue = DispatchQueue(label: "com.jiantie.clipboard.monitor", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var isRunning = false
    private let lock = NSLock()
    private var lastChangeCount: Int

    public init(
        pasteboard: PasteboardProviding,
        pollInterval: TimeInterval = 0.3,
        onItemCaptured: @escaping @Sendable (ClipboardItem) -> Void
    ) {
        self.pasteboard = pasteboard
        self.pollInterval = pollInterval
        self.onItemCaptured = onItemCaptured
        self.lastChangeCount = pasteboard.changeCount
    }

    deinit {
        stop()
    }

    /// 启动定时监听
    public func start() {
        lock.lock()
        defer { lock.unlock() }

        guard !isRunning else { return }
        isRunning = true

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            self?.checkPasteboard()
        }
        timer.resume()
        self.timer = timer
    }

    /// 停止监听
    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        guard isRunning else { return }
        isRunning = false
        timer?.cancel()
        timer = nil
    }

    /// 检查剪贴板变化，若发生变化且存在有效内容则触发捕获
    public func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount

        lock.lock()
        let previousChangeCount = lastChangeCount
        if currentChangeCount != previousChangeCount {
            lastChangeCount = currentChangeCount
        }
        lock.unlock()

        guard currentChangeCount != previousChangeCount else {
            return
        }

        if let content = pasteboard.readItem() {
            let item = ClipboardItem(content: content)
            onItemCaptured(item)
        }
    }
}
