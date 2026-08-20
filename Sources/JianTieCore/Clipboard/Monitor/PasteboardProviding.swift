import Foundation

/// 剪贴板读取与变化感知协议
public protocol PasteboardProviding: Sendable {
    /// 当前剪贴板变化计数
    var changeCount: Int { get }

    /// 读取当前剪贴板有效内容（若为忽略格式或空内容则返回 nil）
    func readItem() -> ClipboardContent?
}
