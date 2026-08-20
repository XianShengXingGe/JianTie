import Foundation

/// 全局按键双击监听协议
public protocol DoubleTapMonitoring: AnyObject, Sendable {
    /// 当前是否处于监听状态
    var isMonitoring: Bool { get }

    /// 启动监听
    /// - Parameter onTrigger: 当检测到全局双击 Command 时的回调
    func startMonitoring(onTrigger: @escaping @Sendable () -> Void)

    /// 停止监听
    func stopMonitoring()
}
