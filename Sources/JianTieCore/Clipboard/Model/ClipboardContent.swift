import Foundation

/// 剪贴板文本内容（纯文本及富文本附加格式）
public struct ClipboardTextContent: Equatable, Sendable, Codable {
    public let plainText: String
    public let rtfData: Data?
    public let htmlData: Data?

    public init(
        plainText: String,
        rtfData: Data? = nil,
        htmlData: Data? = nil
    ) {
        self.plainText = plainText
        self.rtfData = rtfData
        self.htmlData = htmlData
    }
}

/// 剪贴板图片内容
public struct ClipboardImageContent: Equatable, Sendable, Codable {
    public let imageData: Data
    public let format: String

    public init(
        imageData: Data,
        format: String = "png"
    ) {
        self.imageData = imageData
        self.format = format
    }
}

/// 剪贴板内容类型枚举
public enum ClipboardContent: Equatable, Sendable, Codable {
    case text(ClipboardTextContent)
    case image(ClipboardImageContent)

    private enum CodingKeys: String, CodingKey {
        case type
        case textPayload
        case imagePayload
    }

    private enum ContentType: String, Codable {
        case text
        case image
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        switch type {
        case .text:
            let payload = try container.decode(ClipboardTextContent.self, forKey: .textPayload)
            self = .text(payload)
        case .image:
            let payload = try container.decode(ClipboardImageContent.self, forKey: .imagePayload)
            self = .image(payload)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(text, forKey: .textPayload)
        case .image(let image):
            try container.encode(ContentType.image, forKey: .type)
            try container.encode(image, forKey: .imagePayload)
        }
    }
}
