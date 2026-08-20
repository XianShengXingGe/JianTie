import Foundation
import AppKit

/// 系统剪贴板读取器
public final class SystemPasteboardReader: PasteboardProviding, @unchecked Sendable {
    public let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int {
        pasteboard.changeCount
    }

    public func readItem() -> ClipboardContent? {
        guard let types = pasteboard.types, !types.isEmpty else {
            return nil
        }

        // 1. 自动识别并忽略 Finder 复制的文件对象
        if containsFileReferences(types: types) {
            return nil
        }

        // 2. 识别图片格式 (PNG / TIFF / JPEG)
        if let imageContent = extractImageContent(types: types) {
            return .image(imageContent)
        }

        // 3. 识别纯文本与富文本格式 (String, RTF, HTML)
        if let textContent = extractTextContent(types: types) {
            return .text(textContent)
        }

        return nil
    }

    private static let fileTypeIdentifiers: Set<String> = [
        NSPasteboard.PasteboardType.fileURL.rawValue,
        "public.file-url",
        "NSFilenamesPboardType",
        "com.apple.cocoa.pasteboard.find-panel",
        "com.apple.finder.node"
    ]

    private func containsFileReferences(types: [NSPasteboard.PasteboardType]) -> Bool {
        for type in types {
            if Self.fileTypeIdentifiers.contains(type.rawValue) {
                return true
            }
        }

        // 进一步探测是否能仅作为本地文件 URL 解析
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty {
            return true
        }

        return false
    }

    private func extractImageContent(types: [NSPasteboard.PasteboardType]) -> ClipboardImageContent? {
        if types.contains(.png), let data = pasteboard.data(forType: .png), !data.isEmpty {
            return ClipboardImageContent(imageData: data, format: "png")
        }

        if types.contains(.tiff), let data = pasteboard.data(forType: .tiff), !data.isEmpty {
            return ClipboardImageContent(imageData: data, format: "tiff")
        }

        let jpegType = NSPasteboard.PasteboardType("public.jpeg")
        if types.contains(jpegType), let data = pasteboard.data(forType: jpegType), !data.isEmpty {
            return ClipboardImageContent(imageData: data, format: "jpeg")
        }

        return nil
    }

    private func extractTextContent(types: [NSPasteboard.PasteboardType]) -> ClipboardTextContent? {
        guard types.contains(.string),
              let string = pasteboard.string(forType: .string),
              !string.isEmpty else {
            return nil
        }

        var rtfData: Data?
        if types.contains(.rtf), let data = pasteboard.data(forType: .rtf) {
            rtfData = data
        } else if types.contains(.rtfd), let data = pasteboard.data(forType: .rtfd) {
            rtfData = data
        }

        var htmlData: Data?
        if types.contains(.html), let data = pasteboard.data(forType: .html) {
            htmlData = data
        }

        return ClipboardTextContent(plainText: string, rtfData: rtfData, htmlData: htmlData)
    }
}
