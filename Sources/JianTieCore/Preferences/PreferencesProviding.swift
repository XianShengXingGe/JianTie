import Foundation

/// 应用偏好设置提供者协议
public protocol PreferencesProviding: AnyObject, Sendable {
    /// 是否随系统启动 (开机自启)
    var launchAtLogin: Bool { get set }

    /// 是否已完成初次启动的开机自启配置
    var hasConfiguredLaunchAtLogin: Bool { get set }

    /// 全局呼出快捷键配置
    var hotKeyTrigger: HotKeyTrigger { get set }

    /// Shelf 暂存架停靠的屏幕边缘 (左侧 / 右侧)
    var shelfEdge: ShelfEdge { get set }

    /// Shelf 暂存架在屏幕垂直方向的相对停靠比例 (0.0 ~ 1.0，默认 0.5 即垂直居中)
    var shelfVerticalPercent: Double { get set }

    /// 剪贴板历史容量上限
    var clipboardCapacityLimit: ClipboardCapacityLimit { get set }

    /// 剪贴板历史保存周期
    var clipboardRetentionPeriod: ClipboardRetentionPeriod { get set }

    /// 界面语言配置 (.system / .zhHans / .en)
    var appLanguage: AppLanguage { get set }
}
