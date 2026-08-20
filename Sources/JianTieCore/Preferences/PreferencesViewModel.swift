import Foundation
import Combine

/// 偏好设置视图模型，管理 Shelf 边缘配置、权限状态、剪贴板说明与版本展示
@MainActor
public final class PreferencesViewModel: ObservableObject {
    @Published public var shelfEdge: ShelfEdge {
        didSet {
            preferences.shelfEdge = shelfEdge
            shelfEngine?.edge = shelfEdge
        }
    }

    @Published public private(set) var isAccessibilityTrusted: Bool

    public let preferences: PreferencesProviding
    public let accessibilityService: AccessibilityPermissionProviding
    public weak var shelfEngine: ShelfEngine?
    private let bundle: Bundle

    public init(
        preferences: PreferencesProviding = UserDefaultsPreferences.shared,
        accessibilityService: AccessibilityPermissionProviding = AccessibilityPermissionService.shared,
        shelfEngine: ShelfEngine? = nil,
        bundle: Bundle = .main
    ) {
        self.preferences = preferences
        self.accessibilityService = accessibilityService
        self.shelfEngine = shelfEngine
        self.bundle = bundle
        self.shelfEdge = preferences.shelfEdge
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
        return "完整记录最近 1000 条文本、富文本与图片历史，采用先进先出 (FIFO) 策略自动淘汰，无时间过期限制。"
    }

    /// 切换 Shelf 屏幕停靠边缘
    public func setShelfEdge(_ edge: ShelfEdge) {
        guard self.shelfEdge != edge else { return }
        self.shelfEdge = edge
    }

    /// 刷新辅助功能授权状态
    public func refreshAccessibilityStatus() {
        self.isAccessibilityTrusted = accessibilityService.isTrusted
    }

    /// 唤起系统辅助功能权限设置页并触发授权提示
    public func openAccessibilitySettings() {
        accessibilityService.promptForPermission()
        accessibilityService.openSystemAccessibilitySettings()
    }
}
