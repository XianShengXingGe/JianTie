import Foundation
import AppKit

/// 核心应用协调器，管理生命周期、权限状态与系统状态栏
@MainActor
public final class AppCoordinator: NSObject {
    public let accessibilityService: AccessibilityPermissionProviding
    public let menuBuilder: StatusBarMenuBuilder
    public let clipboardEngine: ClipboardEngine
    public let presentGuidanceHandler: () -> Void
    private let statusItemProvider: () -> NSStatusItem?

    public private(set) var statusItem: NSStatusItem?

    public init(
        accessibilityService: AccessibilityPermissionProviding = AccessibilityPermissionService.shared,
        menuBuilder: StatusBarMenuBuilder = StatusBarMenuBuilder(),
        clipboardEngine: ClipboardEngine? = nil,
        presentGuidanceHandler: @escaping () -> Void = {},
        statusItemProvider: @escaping () -> NSStatusItem? = {
            NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
    ) {
        self.accessibilityService = accessibilityService
        self.menuBuilder = menuBuilder
        self.clipboardEngine = clipboardEngine ?? ClipboardEngine(autoStart: false)
        self.presentGuidanceHandler = presentGuidanceHandler
        self.statusItemProvider = statusItemProvider
        super.init()
    }

    public func start() {
        setupStatusItem()
        checkAccessibilityOnLaunch()
        clipboardEngine.startMonitoring()
    }

    public func checkAccessibilityOnLaunch() {
        if !accessibilityService.isTrusted {
            presentGuidanceHandler()
        }
    }

    public func setupStatusItem() {
        guard statusItem == nil else { return }

        if let item = statusItemProvider() {
            if let button = item.button {
                if let image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "简贴") {
                    image.isTemplate = true
                    button.image = image
                } else {
                    button.title = "简"
                }
            }
            item.menu = menuBuilder.buildMenu(
                target: self,
                aboutAction: #selector(showAbout),
                preferencesAction: #selector(openPreferences),
                quitAction: #selector(quit)
            )
            self.statusItem = item
        }
    }

    @objc public func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc public func openPreferences() {
        // Issue #8 接入偏好设置面板
    }

    @objc public func openAccessibilitySettings() {
        accessibilityService.openSystemAccessibilitySettings()
    }

    @objc public func quit() {
        NSApp.terminate(nil)
    }
}
