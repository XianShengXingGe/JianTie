import Cocoa
import JianTieCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appCoordinator: AppCoordinator?
    private var clipboardWindowController: ClipboardPanelWindowController?
    private var shelfWindowController: ShelfPanelWindowController?
    private var preferencesWindowController: PreferencesWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 配置为 Menu Bar Agent (不在 Dock 和 ⌘Tab 切换器中出现)
        NSApp.setActivationPolicy(.accessory)

        // 配置应用品牌图标 (支持 SPM 模块资源与 App Bundle 资源加载)
        if let icon = AppIconProvider.loadAppIcon() {
            NSApp.applicationIconImage = icon
        }

        let coordinator = AppCoordinator(
            accessibilityService: AccessibilityPermissionService.shared,
            menuBuilder: StatusBarMenuBuilder(),
            presentGuidanceHandler: {
                Task { @MainActor in
                    AccessibilityGuidanceWindowController.shared.showWindow()
                }
            },
            presentClipboardHandler: { [weak self] target in
                Task { @MainActor in
                    self?.clipboardWindowController?.show(targetApp: target)
                }
            },
            dismissClipboardHandler: { [weak self] in
                Task { @MainActor in
                    self?.clipboardWindowController?.dismissAndRestoreFocus()
                }
            },
            isClipboardVisibleHandler: { [weak self] in
                self?.clipboardWindowController?.window?.isVisible == true
            },
            presentPreferencesHandler: { [weak self] in
                Task { @MainActor in
                    self?.preferencesWindowController?.showWindow()
                }
            }
        )

        let clipboardViewModel = ClipboardViewModel(engine: coordinator.clipboardEngine)
        let windowController = ClipboardPanelWindowController(
            viewModel: clipboardViewModel,
            appCoordinator: coordinator
        )

        let shelfController = ShelfPanelWindowController(engine: coordinator.shelfEngine)

        let preferencesViewModel = PreferencesViewModel(
            preferences: UserDefaultsPreferences.shared,
            accessibilityService: AccessibilityPermissionService.shared,
            shelfEngine: coordinator.shelfEngine,
            clipboardEngine: coordinator.clipboardEngine,
            hotKeyService: coordinator.hotKeyService
        )
        let preferencesController = PreferencesWindowController(viewModel: preferencesViewModel)

        self.clipboardWindowController = windowController
        self.shelfWindowController = shelfController
        self.preferencesWindowController = preferencesController
        self.appCoordinator = coordinator

        coordinator.start()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭引导窗口等不退出常驻应用
        return false
    }
}
