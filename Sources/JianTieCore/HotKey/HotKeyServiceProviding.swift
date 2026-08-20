import Foundation

/// 统一热键调度与监听服务协议
public protocol HotKeyServiceProviding: AnyObject, Sendable {
    /// 当前生效的热键配置
    var currentTrigger: HotKeyTrigger { get }

    /// 当前是否处于监听状态
    var isMonitoring: Bool { get }

    /// 启动全局热键监听
    /// - Parameter onTrigger: 当热键被触发时的回调闭包
    func startMonitoring(onTrigger: @escaping @Sendable () -> Void)

    /// 停止全局热键监听
    func stopMonitoring()

    /// 动态更新/切换全局热键（热重载，无需重启应用）
    /// - Parameter trigger: 新的热键配置
    func updateTrigger(_ trigger: HotKeyTrigger)
}
