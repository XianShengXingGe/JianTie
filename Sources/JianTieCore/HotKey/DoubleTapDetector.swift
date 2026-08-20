import Foundation

/// 纯状态机：检测 300ms 窗口内的双击修饰键（⌘ / ⌥ / ⌃ / ⇧）事件
public final class DoubleTapDetector: @unchecked Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case firstDown(timestamp: TimeInterval)
        case firstUp(timestamp: TimeInterval)
        case secondDown(timestamp: TimeInterval)
    }

    public private(set) var state: State = .idle
    public let targetModifier: ModifierKey
    public let maxInterval: TimeInterval

    /// 初始化双击检测器
    /// - Parameters:
    ///   - targetModifier: 监听的目标修饰键（默认为 Command）
    ///   - maxInterval: 连续两次击键的最大时间间隔（默认 0.3 秒 / 300ms）
    public init(targetModifier: ModifierKey = .command, maxInterval: TimeInterval = 0.3) {
        self.targetModifier = targetModifier
        self.maxInterval = maxInterval
    }

    /// 处理修饰键状态变化事件
    /// - Parameters:
    ///   - isTargetPressed: 当前目标修饰键是否按下
    ///   - otherModifiersPressed: 是否有其他修饰键同时处于按下状态
    ///   - timestamp: 事件发生的时间戳（秒）
    /// - Returns: 是否成功检测到一次合法的双击动作
    @discardableResult
    public func handleFlagsChanged(
        isTargetPressed: Bool,
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
            if isTargetPressed {
                state = .firstDown(timestamp: timestamp)
            }
            return false

        case .firstDown(let firstDownTime):
            if isTargetPressed {
                // 重复收到按下状态，保持
                return false
            } else {
                // 目标键抬起
                let elapsed = timestamp - firstDownTime
                if elapsed <= maxInterval && elapsed >= 0 {
                    state = .firstUp(timestamp: timestamp)
                } else {
                    state = .idle
                }
                return false
            }

        case .firstUp(let firstUpTime):
            if isTargetPressed {
                let interval = timestamp - firstUpTime
                if interval <= maxInterval && interval >= 0 {
                    state = .secondDown(timestamp: timestamp)
                } else {
                    // 超过了 300ms 窗口，但当前按下了目标键，可以视为新的第一次按下
                    state = .firstDown(timestamp: timestamp)
                }
            }
            return false

        case .secondDown(let secondDownTime):
            if isTargetPressed {
                // 持续按住中
                return false
            } else {
                // 第二次目标键抬起
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
    /// 当用户正在敲击快捷键或普通输入时，立即重置双击状态
    public func handleKeyEvent(timestamp: TimeInterval) {
        state = .idle
    }

    /// 重置状态机
    public func reset() {
        state = .idle
    }
}
