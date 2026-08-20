import Foundation

/// Shelf 暂存项后台静默巡检淘汰器，负责定时排查失效文件引用并移除
public final class ShelfPruner: @unchecked Sendable {
    public let checker: FileReachableChecking
    public let interval: TimeInterval
    private var timer: Timer?
    private let lock = NSLock()

    public init(
        checker: FileReachableChecking = SystemFileReachableChecker.shared,
        interval: TimeInterval = 5.0
    ) {
        self.checker = checker
        self.interval = interval
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

    /// 启动定时后台巡检
    /// - Parameters:
    ///   - getStacks: 当前 stacks 获取闭包
    ///   - onPruned: 发生淘汰变更时的回调闭包
    public func startPeriodicPruning(
        getStacks: @escaping @Sendable () -> [ShelfStack],
        onPruned: @escaping @Sendable ([ShelfStack]) -> Void
    ) {
        stopPeriodicPruning()

        lock.lock()
        defer { lock.unlock() }

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let current = getStacks()
            let (valid, removed) = self.prune(stacks: current)
            if removed > 0 {
                onPruned(valid)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 停止定时后台巡检
    public func stopPeriodicPruning() {
        lock.lock()
        defer { lock.unlock() }

        timer?.invalidate()
        timer = nil
    }
}
