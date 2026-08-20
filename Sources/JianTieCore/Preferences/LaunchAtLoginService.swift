import Foundation
import ServiceManagement

/// 开机自启服务协议
public protocol LaunchAtLoginProviding: Sendable {
    /// 当前是否已启用开机自启（在系统登录项中已注册或等待授权）
    var isEnabled: Bool { get }

    /// 注册开机自启（随系统启动）
    @discardableResult
    func register() -> Bool

    /// 注销开机自启
    @discardableResult
    func unregister() -> Bool
}

/// 基于 macOS 13+ SMAppService 的开机自启服务实现
public final class LaunchAtLoginService: LaunchAtLoginProviding, @unchecked Sendable {
    public static let shared = LaunchAtLoginService()

    private let statusProvider: () -> SMAppService.Status
    private let registerHandler: () throws -> Void
    private let unregisterHandler: () throws -> Void

    public init(
        statusProvider: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        registerHandler: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregisterHandler: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }
    ) {
        self.statusProvider = statusProvider
        self.registerHandler = registerHandler
        self.unregisterHandler = unregisterHandler
    }

    /// 检查系统当前登录项中是否处于启用或待批准状态
    public var isEnabled: Bool {
        let status = statusProvider()
        return status == .enabled || status == .requiresApproval
    }

    /// 向系统注册开机自启登录项，失败时静默降级并返回 false
    @discardableResult
    public func register() -> Bool {
        do {
            try registerHandler()
            return true
        } catch {
            return false
        }
    }

    /// 从系统注销开机自启登录项，失败时静默降级并返回 false
    @discardableResult
    public func unregister() -> Bool {
        do {
            try unregisterHandler()
            return true
        } catch {
            return false
        }
    }
}
