import Cocoa
import JianTieCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appCoordinator: AppCoordinator?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 配置为 Menu Bar Agent (不在 Dock 和 ⌘Tab 切换器中出现)
        NSApp.setActivationPolicy(.accessory)

        appCoordinator = AppCoordinator(
            accessibilityService: AccessibilityPermissionService.shared,
            menuBuilder: StatusBarMenuBuilder(),
            presentGuidanceHandler: {
                AccessibilityGuidanceWindowController.shared.showWindow()
            }
        )

        appCoordinator?.start()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭引导窗口等不退出常驻应用
        return false
    }
}
