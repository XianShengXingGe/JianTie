import Foundation

/// 应用偏好设置提供者协议
public protocol PreferencesProviding: AnyObject, Sendable {
    /// Shelf 暂存架停靠的屏幕边缘 (左侧 / 右侧)
    var shelfEdge: ShelfEdge { get set }

    /// 剪贴板历史容量上限
    var clipboardCapacityLimit: ClipboardCapacityLimit { get set }

    /// 剪贴板历史保存周期
    var clipboardRetentionPeriod: ClipboardRetentionPeriod { get set }
}
