//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import AppKit

/// 目标应用程序信息封装
public struct AppTarget: Equatable, Sendable {
    public let bundleIdentifier: String?
    public let processIdentifier: pid_t
    public let localizedName: String?
    public let runningApplication: NSRunningApplication?

    public init(
        bundleIdentifier: String? = nil,
        processIdentifier: pid_t = 0,
        localizedName: String? = nil,
        runningApplication: NSRunningApplication? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier ?? runningApplication?.bundleIdentifier
        self.processIdentifier = processIdentifier != 0 ? processIdentifier : (runningApplication?.processIdentifier ?? 0)
        self.localizedName = localizedName ?? runningApplication?.localizedName
        self.runningApplication = runningApplication
    }

    public static func == (lhs: AppTarget, rhs: AppTarget) -> Bool {
        lhs.processIdentifier == rhs.processIdentifier &&
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

/// 应用程序前台获取与激活协议
public protocol AppActivating: Sendable {
    /// 获取当前处于前台焦点的活动应用程序
    func frontmostApp() -> AppTarget?

    /// 激活指定的目标应用程序并将焦点交回
    @discardableResult
    func activate(target: AppTarget) -> Bool
}

/// 系统默认的前台应用管理服务
public final class SystemAppActivator: AppActivating, @unchecked Sendable {
    public static let shared = SystemAppActivator()

    public init() {}

    public func frontmostApp() -> AppTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return AppTarget(runningApplication: app)
    }

    @discardableResult
    public func activate(target: AppTarget) -> Bool {
        if let app = target.runningApplication, !app.isTerminated {
            return app.activate(options: .activateIgnoringOtherApps)
        }

        if target.processIdentifier > 0,
           let app = NSRunningApplication(processIdentifier: target.processIdentifier),
           !app.isTerminated {
            return app.activate(options: .activateIgnoringOtherApps)
        }

        return false
    }
}
