import AppKit
import SwiftUI
import JianTieCore

public extension DonationChannel {
    var brandColor: Color {
        switch self {
        case .wechat:
            return Color(red: 0.04, green: 0.74, blue: 0.36) // WeChat Green
        case .alipay:
            return Color(red: 0.09, green: 0.48, blue: 0.98) // Alipay Blue
        }
    }
}

/// 打赏收款码图片加载器
public enum DonationQRCodeProvider {
    private static let supportedExtensions = ["jpg", "jpeg", "png", "webp"]

    /// 加载指定打赏渠道的收款码图片
    @MainActor
    public static func loadQRCodeImage(for channel: DonationChannel, bundle: Bundle? = nil) -> NSImage? {
        let resourceName = channel.resourceBaseName
        let bundlesToSearch = [bundle, Bundle.module, Bundle.main].compactMap { $0 }

        for currentBundle in bundlesToSearch {
            for ext in supportedExtensions {
                if let url = currentBundle.url(forResource: resourceName, withExtension: ext) {
                    if let image = NSImage(contentsOf: url), image.isValid {
                        return image
                    }
                }
                if let resourceURL = currentBundle.resourceURL?.appendingPathComponent("\(resourceName).\(ext)"),
                   FileManager.default.fileExists(atPath: resourceURL.path),
                   let image = NSImage(contentsOf: resourceURL), image.isValid {
                    return image
                }
            }
        }
        return nil
    }
}
