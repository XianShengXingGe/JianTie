import Foundation

/// 剪贴板历史记录项
public struct ClipboardItem: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let content: ClipboardContent

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        content: ClipboardContent
    ) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
    }

    /// 纯文本摘要，供搜索与预览展示
    public var plainTextSummary: String? {
        switch content {
        case .text(let text):
            return text.plainText
        case .image:
            return nil
        }
    }
}
