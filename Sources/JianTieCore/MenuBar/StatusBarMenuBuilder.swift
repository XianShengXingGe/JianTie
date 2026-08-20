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
        quitAction: Selector? = nil,
        localizationManager: LocalizationManager? = nil
    ) -> NSMenu {
        let manager = localizationManager ?? LocalizationManager.shared
        let menu = NSMenu()

        let aboutTitle = manager.string(forKey: "menu.about")
        let preferencesTitle = manager.string(forKey: "menu.preferences")
        let quitTitle = manager.string(forKey: "menu.quit")

        let aboutItem = NSMenuItem(title: aboutTitle, action: aboutAction, keyEquivalent: "")
        aboutItem.target = target
        menu.addItem(aboutItem)

        let preferencesItem = NSMenuItem(title: preferencesTitle, action: preferencesAction, keyEquivalent: ",")
        preferencesItem.target = target
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: quitTitle, action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
