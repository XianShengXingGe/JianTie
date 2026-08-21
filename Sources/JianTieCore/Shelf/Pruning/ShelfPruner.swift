//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// Shelf 暂存项后台静默巡检淘汰器，负责定时排查失效文件引用并移除（非阻塞后台探针）
public final class ShelfPruner: @unchecked Sendable {
    public let checker: FileReachableChecking
    public let interval: TimeInterval
    private let queue = DispatchQueue(label: "com.jiantie.shelf.pruner", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var isRunning = false
    private let lock = NSLock()

    public init(
        checker: FileReachableChecking = SystemFileReachableChecker.shared,
        interval: TimeInterval = 5.0
    ) {
        self.checker = checker
        self.interval = interval
    }

    /// 对 Stacks 集合执行异步后台巡检过滤（非阻塞）
    /// - Parameter stacks: 待检测的 Stack 列表
    /// - Returns: 仅包含依然可达的有效 Stack 列表，以及被淘汰移除的计数
    public func pruneAsync(stacks: [ShelfStack]) async -> (valid: [ShelfStack], removedCount: Int) {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: (stacks, 0))
                    return
                }
                let result = self.prune(stacks: stacks)
                continuation.resume(returning: result)
            }
        }
    }

    /// 对 Stacks 集合执行单次巡检过滤
    /// - Parameter stacks: 待检测的 Stack 列表
    /// - Returns: 仅包含依然可达的有效 Stack 列表，以及被淘汰移除的计数
    public func prune(stacks: [ShelfStack]) -> (valid: [ShelfStack], removedCount: Int) {
        let valid = stacks.filter { stack in
            !stack.files.isEmpty && stack.files.allSatisfy { checker.isReachable(file: $0) }
        }
        let removed = stacks.count - valid.count
        return (valid, removed)
    }

    /// 启动定时后台巡检（在后台 utility 队列执行文件 I/O 探针检测，避免阻滞主 RunLoop）
    /// - Parameters:
    ///   - getStacks: 当前 stacks 获取闭包
    ///   - onPruned: 发生淘汰变更时的回调闭包（保证在主线程回调）
    public func startPeriodicPruning(
        getStacks: @escaping @Sendable () -> [ShelfStack],
        onPruned: @escaping @Sendable ([ShelfStack]) -> Void
    ) {
        stopPeriodicPruning()

        lock.lock()
        defer { lock.unlock() }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let current = getStacks()
            let (valid, removed) = self.prune(stacks: current)
            if removed > 0 {
                DispatchQueue.main.async {
                    onPruned(valid)
                }
            }
        }
        timer.resume()
        self.timer = timer
        self.isRunning = true
    }

    /// 停止定时后台巡检
    public func stopPeriodicPruning() {
        lock.lock()
        defer { lock.unlock() }

        guard isRunning else { return }
        timer?.cancel()
        timer = nil
        isRunning = false
    }

    deinit {
        stopPeriodicPruning()
    }
}
