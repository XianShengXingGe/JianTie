import Foundation

/// 纯状态机：检测 300ms 窗口内的双击 ⌘（Command）修饰键事件
public final class DoubleTapDetector: @unchecked Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case firstDown(timestamp: TimeInterval)
        case firstUp(timestamp: TimeInterval)
        case secondDown(timestamp: TimeInterval)
    }

    public private(set) var state: State = .idle
    public let maxInterval: TimeInterval

    /// 初始化双击检测器
    /// - Parameter maxInterval: 连续两次击键的最大时间间隔（默认 0.3 秒 / 300ms）
    public init(maxInterval: TimeInterval = 0.3) {
        self.maxInterval = maxInterval
    }

    /// 处理修饰键状态变化事件
    /// - Parameters:
    ///   - isCommandPressed: 当前 Command 键是否按下
    ///   - otherModifiersPressed: 是否有其他修饰键（Shift / Option / Control 等）同时处于按下状态
    ///   - timestamp: 事件发生的时间戳（秒）
    /// - Returns: 是否成功检测到一次合法的双击 ⌘ 动作
    @discardableResult
    public func handleFlagsChanged(
        isCommandPressed: Bool,
        otherModifiersPressed: Bool,
        timestamp: TimeInterval
    ) -> Bool {
        // 如果有其他修饰键同时按下，直接破坏双击状态机并重置
        guard !otherModifiersPressed else {
            state = .idle
            return false
        }

        switch state {
        case .idle:
            if isCommandPressed {
                state = .firstDown(timestamp: timestamp)
            }
            return false

        case .firstDown(let firstDownTime):
            if isCommandPressed {
                // 重复收到按下状态，保持
                return false
            } else {
                // Command 键抬起
                let elapsed = timestamp - firstDownTime
                if elapsed <= maxInterval && elapsed >= 0 {
                    state = .firstUp(timestamp: timestamp)
                } else {
                    state = .idle
                }
                return false
            }

        case .firstUp(let firstUpTime):
            if isCommandPressed {
                let interval = timestamp - firstUpTime
                if interval <= maxInterval && interval >= 0 {
                    state = .secondDown(timestamp: timestamp)
                } else {
                    // 超过了 300ms 窗口，但当前按下了 Command，可以视为新的第一次按下
                    state = .firstDown(timestamp: timestamp)
                }
            }
            return false

        case .secondDown(let secondDownTime):
            if isCommandPressed {
                // 持续按住中
                return false
            } else {
                // 第二次 Command 抬起
                let elapsed = timestamp - secondDownTime
                state = .idle
                if elapsed <= maxInterval && elapsed >= 0 {
                    return true
                }
                return false
            }
        }
    }

    /// 处理普通按键按下或抬起事件（如字母、数字、方向键等）
    /// 当用户正在敲击快捷键（如 ⌘C、⌘V）或普通输入时，立即重置双击状态
    public func handleKeyEvent(timestamp: TimeInterval) {
        state = .idle
    }

    /// 重置状态机
    public func reset() {
        state = .idle
    }
}
