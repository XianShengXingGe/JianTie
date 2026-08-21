//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

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

    /// 判断与另一项的内容是否实质相同（纯文本相同或图片内容哈希相同）
    public func isContentEqual(to other: ClipboardItem) -> Bool {
        return content.isContentEqual(to: other.content)
    }
}
