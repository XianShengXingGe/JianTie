import Foundation
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

    @Published public var showClearConfirmationAlert: Bool = false
    @Published public private(set) var isAccessibilityTrusted: Bool

    public let preferences: PreferencesProviding
    public let launchAtLoginService: LaunchAtLoginProviding
    public let accessibilityService: AccessibilityPermissionProviding
    public weak var shelfEngine: ShelfEngine?
    public weak var clipboardEngine: ClipboardEngine?
    public weak var hotKeyService: HotKeyServiceProviding?
    private let bundle: Bundle

    public init(
        preferences: PreferencesProviding = UserDefaultsPreferences.shared,
        launchAtLoginService: LaunchAtLoginProviding = LaunchAtLoginService.shared,
        accessibilityService: AccessibilityPermissionProviding = AccessibilityPermissionService.shared,
        shelfEngine: ShelfEngine? = nil,
        clipboardEngine: ClipboardEngine? = nil,
        hotKeyService: HotKeyServiceProviding? = nil,
        bundle: Bundle = .main
    ) {
        self.preferences = preferences
        self.launchAtLoginService = launchAtLoginService
        self.accessibilityService = accessibilityService
        self.shelfEngine = shelfEngine
        self.clipboardEngine = clipboardEngine
        self.hotKeyService = hotKeyService
        self.bundle = bundle
        self.launchAtLogin = launchAtLoginService.isEnabled
        self.hotKeyTrigger = preferences.hotKeyTrigger
        self.shelfEdge = preferences.shelfEdge
        self.clipboardCapacityLimit = preferences.clipboardCapacityLimit
        self.clipboardRetentionPeriod = preferences.clipboardRetentionPeriod
        self.isAccessibilityTrusted = accessibilityService.isTrusted
    }

    /// 应用版本描述信息
    public var appVersionText: String {
        let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildVersion = bundle.infoDictionary?["CFBundleVersion"] as? String
        if let build = buildVersion, !build.isEmpty, build != shortVersion {
            return "v\(shortVersion) (\(build))"
        }
        return "v\(shortVersion)"
    }

    /// 剪贴板历史保留容量说明
    public var clipboardRetentionDescription: String {
        return "支持智能文本与图片 (SHA-256) 去重前置。超出容量将按先进先出 (FIFO) 自动淘汰，超期条目自动修剪。"
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

    /// 设置全局快捷键
    public func setHotKeyTrigger(_ trigger: HotKeyTrigger) {
        guard self.hotKeyTrigger != trigger else { return }
        self.hotKeyTrigger = trigger
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
}
