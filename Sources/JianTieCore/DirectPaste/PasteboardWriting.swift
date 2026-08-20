//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import AppKit

/// 剪贴板写入协议
public protocol PasteboardWriting: Sendable {
    /// 将剪贴板内容完整写入系统剪贴板
    @discardableResult
    func write(content: ClipboardContent) -> Bool
}

/// 系统默认剪贴板写入服务
public final class SystemPasteboardWriter: PasteboardWriting, @unchecked Sendable {
    public let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    @discardableResult
    public func write(content: ClipboardContent) -> Bool {
        pasteboard.clearContents()

        switch content {
        case .text(let textContent):
            var types: [NSPasteboard.PasteboardType] = [.string]
            if textContent.rtfData != nil {
                types.append(.rtf)
            }
            if textContent.htmlData != nil {
                types.append(.html)
            }

            pasteboard.declareTypes(types, owner: nil)

            var success = pasteboard.setString(textContent.plainText, forType: .string)

            if let rtfData = textContent.rtfData {
                let rtfSuccess = pasteboard.setData(rtfData, forType: .rtf)
                success = success && rtfSuccess
            }

            if let htmlData = textContent.htmlData {
                let htmlSuccess = pasteboard.setData(htmlData, forType: .html)
                success = success && htmlSuccess
            }

            return success

        case .image(let imageContent):
            let type: NSPasteboard.PasteboardType
            switch imageContent.format.lowercased() {
            case "png":
                type = .png
            case "tiff":
                type = .tiff
            case "jpeg", "jpg":
                type = NSPasteboard.PasteboardType("public.jpeg")
            default:
                type = .png
            }

            pasteboard.declareTypes([type, .tiff], owner: nil)
            let success = pasteboard.setData(imageContent.imageData, forType: type)

            // 如果非 tiff 但能解析为 NSImage，补充声明 tiff 以获得最大兼容性
            if type != .tiff, let image = NSImage(data: imageContent.imageData), let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
            }

            return success
        }
    }
}
