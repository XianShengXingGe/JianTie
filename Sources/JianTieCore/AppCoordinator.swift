import Foundation
import AppKit

/// 核心应用协调器，管理生命周期、权限状态、系统状态栏与全局快捷键调度
@MainActor
public final class AppCoordinator: NSObject {
    public let preferences: PreferencesProviding
    public let launchAtLoginService: LaunchAtLoginProviding
    public let accessibilityService: AccessibilityPermissionProviding
    public let menuBuilder: StatusBarMenuBuilder
    public let clipboardEngine: ClipboardEngine
    public let shelfEngine: ShelfEngine
    public let hotKeyService: HotKeyServiceProviding
    public let directPasteService: DirectPasteService
    public let appActivator: AppActivating
    public let presentGuidanceHandler: () -> Void
    public let presentClipboardHandler: (@Sendable (AppTarget?) -> Void)?
    public let dismissClipboardHandler: (@Sendable () -> Void)?
    public let isClipboardVisibleHandler: (@Sendable () -> Bool)?
    public let presentPreferencesHandler: (@Sendable () -> Void)?
    private let statusItemProvider: () -> NSStatusItem?

    public private(set) var statusItem: NSStatusItem?
    public private(set) var lastFrontmostApp: AppTarget?
    public var onHotKeyTriggered: (@Sendable (AppTarget?) -> Void)?

    public init(
        preferences: PreferencesProviding = UserDefaultsPreferences.shared,
        launchAtLoginService: LaunchAtLoginProviding = LaunchAtLoginService.shared,
        accessibilityService: AccessibilityPermissionProviding = AccessibilityPermissionService.shared,
        menuBuilder: StatusBarMenuBuilder = StatusBarMenuBuilder(),
        clipboardEngine: ClipboardEngine? = nil,
        shelfEngine: ShelfEngine? = nil,
        hotKeyService: HotKeyServiceProviding? = nil,
        directPasteService: DirectPasteService = DirectPasteService(),
        appActivator: AppActivating = SystemAppActivator.shared,
        presentGuidanceHandler: @escaping () -> Void = {},
        presentClipboardHandler: (@Sendable (AppTarget?) -> Void)? = nil,
        dismissClipboardHandler: (@Sendable () -> Void)? = nil,
        isClipboardVisibleHandler: (@Sendable () -> Bool)? = nil,
        presentPreferencesHandler: (@Sendable () -> Void)? = nil,
        statusItemProvider: @escaping () -> NSStatusItem? = {
            NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
    ) {
        self.preferences = preferences
        self.launchAtLoginService = launchAtLoginService
        self.accessibilityService = accessibilityService
        self.menuBuilder = menuBuilder
        self.clipboardEngine = clipboardEngine ?? ClipboardEngine(autoStart: false)
        self.shelfEngine = shelfEngine ?? ShelfEngine(autoStart: false)
        self.hotKeyService = hotKeyService ?? HotKeyService(initialTrigger: preferences.hotKeyTrigger)
        self.directPasteService = directPasteService
        self.appActivator = appActivator
        self.presentGuidanceHandler = presentGuidanceHandler
        self.presentClipboardHandler = presentClipboardHandler
        self.dismissClipboardHandler = dismissClipboardHandler
        self.isClipboardVisibleHandler = isClipboardVisibleHandler
        self.presentPreferencesHandler = presentPreferencesHandler
        self.statusItemProvider = statusItemProvider
        super.init()
    }

    public func start() {
        setupLaunchAtLoginOnFirstLaunchIfNeeded()
        setupStatusItem()
        checkAccessibilityOnLaunch()
        clipboardEngine.startMonitoring()
        shelfEngine.startMonitoring()
        startHotKeyMonitoring()
    }

    public func setupLaunchAtLoginOnFirstLaunchIfNeeded() {
        guard !preferences.hasConfiguredLaunchAtLogin else { return }
        preferences.hasConfiguredLaunchAtLogin = true
        preferences.launchAtLogin = true
        _ = launchAtLoginService.register()
    }

    public func startHotKeyMonitoring() {
        hotKeyService.startMonitoring { [weak self] in
            Task { @MainActor in
                self?.handleHotKeyTrigger()
            }
        }
    }

    /// 处理全局快捷键触发（实现 Toggle 唤出/收起逻辑）
    public func handleHotKeyTrigger() {
        if let isVisible = isClipboardVisibleHandler?(), isVisible {
            dismissClipboardHandler?()
        } else {
            let frontmost = appActivator.frontmostApp()
            if let front = frontmost, front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                self.lastFrontmostApp = front
            }
            self.onHotKeyTriggered?(lastFrontmostApp)
            self.presentClipboardHandler?(lastFrontmostApp)
        }
    }

    @discardableResult
    public func pasteItem(_ item: ClipboardItem, to target: AppTarget? = nil) async -> Bool {
        let targetApp = target ?? lastFrontmostApp
        return await directPasteService.directPaste(item: item, target: targetApp)
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
                button.image = StatusBarIcon.createTemplateImage()
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
        presentPreferencesHandler?()
    }

    @objc public func openAccessibilitySettings() {
        accessibilityService.openSystemAccessibilitySettings()
    }

    @objc public func quit() {
        NSApp.terminate(nil)
    }
}
