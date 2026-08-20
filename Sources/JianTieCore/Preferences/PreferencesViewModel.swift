import Foundation
import AppKit
import Combine

/// 偏好设置视图模型，管理 Shelf 边缘配置、剪贴板容量生命周期、全局快捷键、权限状态与版本展示
@MainActor
public final class PreferencesViewModel: ObservableObject {
    @Published public var launchAtLogin: Bool
    @Published public var hotKeyTrigger: HotKeyTrigger {
        didSet {
            preferences.hotKeyTrigger = hotKeyTrigger
            hotKeyService?.updateTrigger(hotKeyTrigger)
        }
    }

    @Published public var shelfEdge: ShelfEdge {
        didSet {
            preferences.shelfEdge = shelfEdge
            shelfEngine?.edge = shelfEdge
        }
    }

    @Published public var clipboardCapacityLimit: ClipboardCapacityLimit {
        didSet {
            preferences.clipboardCapacityLimit = clipboardCapacityLimit
            clipboardEngine?.pruneHistory()
        }
    }

    @Published public var clipboardRetentionPeriod: ClipboardRetentionPeriod {
        didSet {
            preferences.clipboardRetentionPeriod = clipboardRetentionPeriod
            clipboardEngine?.pruneHistory()
        }
    }

    @Published public var appLanguage: AppLanguage {
        didSet {
            preferences.appLanguage = appLanguage
            localizationManager.setLanguage(appLanguage)
        }
    }

    @Published public var showClearConfirmationAlert: Bool = false
    @Published public private(set) var isAccessibilityTrusted: Bool

    public let preferences: PreferencesProviding
    public let launchAtLoginService: LaunchAtLoginProviding
    public let accessibilityService: AccessibilityPermissionProviding
    public let localizationManager: LocalizationManager
    public weak var shelfEngine: ShelfEngine?
    public weak var clipboardEngine: ClipboardEngine?
    public weak var hotKeyService: HotKeyServiceProviding?
    private let bundle: Bundle
    private var cancellables = Set<AnyCancellable>()

    public init(
        preferences: PreferencesProviding = UserDefaultsPreferences.shared,
        launchAtLoginService: LaunchAtLoginProviding = LaunchAtLoginService.shared,
        accessibilityService: AccessibilityPermissionProviding = AccessibilityPermissionService.shared,
        localizationManager: LocalizationManager? = nil,
        shelfEngine: ShelfEngine? = nil,
        clipboardEngine: ClipboardEngine? = nil,
        hotKeyService: HotKeyServiceProviding? = nil,
        bundle: Bundle = .main
    ) {
        self.preferences = preferences
        self.launchAtLoginService = launchAtLoginService
        self.accessibilityService = accessibilityService
        self.localizationManager = localizationManager ?? .shared
        self.shelfEngine = shelfEngine
        self.clipboardEngine = clipboardEngine
        self.hotKeyService = hotKeyService
        self.bundle = bundle
        self.launchAtLogin = launchAtLoginService.isEnabled
        self.hotKeyTrigger = preferences.hotKeyTrigger
        self.shelfEdge = preferences.shelfEdge
        self.clipboardCapacityLimit = preferences.clipboardCapacityLimit
        self.clipboardRetentionPeriod = preferences.clipboardRetentionPeriod
        self.appLanguage = preferences.appLanguage
        self.isAccessibilityTrusted = accessibilityService.isTrusted

        NotificationCenter.default.publisher(for: .appLanguageDidChange)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refreshStatus()
            }
            .store(in: &cancellables)

        // 周期性动态轮询权限与系统状态，确保在系统设置授权后界面秒级自动变绿
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshAccessibilityStatus()
            }
            .store(in: &cancellables)
    }

    /// 应用版本描述信息 (纯版本号，如 v1.1.0)
    public var appVersionText: String {
        let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
        return "v\(shortVersion)"
    }

    /// 剪贴板历史保留容量说明
    public var clipboardRetentionDescription: String {
        return localizationManager.string(forKey: "preferences.clipboard_retention_desc")
    }

    /// 设置应用界面语言
    public func setAppLanguage(_ language: AppLanguage) {
        guard self.appLanguage != language else { return }
        self.appLanguage = language
    }

    /// 设置开机自启（随系统启动）
    public func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            _ = launchAtLoginService.register()
        } else {
            _ = launchAtLoginService.unregister()
        }
        self.launchAtLogin = launchAtLoginService.isEnabled
        self.preferences.launchAtLogin = self.launchAtLogin
    }

    /// 是否为默认全局快捷键 (双击 ⌘)
    public var isDefaultHotKey: Bool {
        return hotKeyTrigger == .default
    }

    /// 设置全局快捷键
    public func setHotKeyTrigger(_ trigger: HotKeyTrigger) {
        guard self.hotKeyTrigger != trigger else { return }
        self.hotKeyTrigger = trigger
    }

    /// 一键重置为默认全局快捷键 (双击 ⌘)
    public func resetHotKeyToDefault() {
        setHotKeyTrigger(.default)
    }

    /// 设置为双击修饰键模式
    public func setDoubleTapModifier(_ modifier: ModifierKey) {
        setHotKeyTrigger(.doubleTap(modifier: modifier))
    }

    /// 切换 Shelf 屏幕停靠边缘
    public func setShelfEdge(_ edge: ShelfEdge) {
        guard self.shelfEdge != edge else { return }
        self.shelfEdge = edge
    }

    /// 设置剪贴板历史容量上限
    public func setClipboardCapacityLimit(_ limit: ClipboardCapacityLimit) {
        guard self.clipboardCapacityLimit != limit else { return }
        self.clipboardCapacityLimit = limit
    }

    /// 设置剪贴板历史保存周期
    public func setClipboardRetentionPeriod(_ period: ClipboardRetentionPeriod) {
        guard self.clipboardRetentionPeriod != period else { return }
        self.clipboardRetentionPeriod = period
    }

    /// 执行清空剪贴板历史操作
    public func confirmClearClipboardHistory() {
        clipboardEngine?.clearHistory()
    }

    /// 刷新开机自启系统级状态
    public func refreshLaunchAtLoginStatus() {
        let systemEnabled = launchAtLoginService.isEnabled
        if self.launchAtLogin != systemEnabled {
            self.launchAtLogin = systemEnabled
            self.preferences.launchAtLogin = systemEnabled
        }
    }

    /// 刷新辅助功能授权状态
    public func refreshAccessibilityStatus() {
        self.isAccessibilityTrusted = accessibilityService.isTrusted
    }

    /// 统一刷新所有系统级与权限状态
    public func refreshStatus() {
        refreshAccessibilityStatus()
        refreshLaunchAtLoginStatus()
    }

    /// 唤起系统辅助功能权限设置页并触发授权提示
    public func openAccessibilitySettings() {
        accessibilityService.promptForPermission()
        accessibilityService.openSystemAccessibilitySettings()
    }

    /// 在默认浏览器中打开 GitHub 最新 Release 页面
    public func openLatestRelease() {
        if let url = URL(string: "https://github.com/XianShengXingGe/JianTie/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }
}
