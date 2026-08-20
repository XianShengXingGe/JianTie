import Foundation
import AppKit

/// 状态栏菜单构建器
public final class StatusBarMenuBuilder: Sendable {
    public init() {}

    @MainActor
    public func buildMenu(
        target: AnyObject?,
        aboutAction: Selector? = nil,
        preferencesAction: Selector? = nil,
        quitAction: Selector? = nil
    ) -> NSMenu {
        let menu = NSMenu()

        let aboutItem = NSMenuItem(title: "关于 简贴", action: aboutAction, keyEquivalent: "")
        aboutItem.target = target
        menu.addItem(aboutItem)

        let preferencesItem = NSMenuItem(title: "偏好设置...", action: preferencesAction, keyEquivalent: ",")
        preferencesItem.target = target
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 简贴", action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
