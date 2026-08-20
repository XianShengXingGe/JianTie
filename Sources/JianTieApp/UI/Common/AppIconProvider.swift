//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import AppKit

/// 应用品牌图标加载器，集中处理 SPM Module 与 App Bundle 资源定位
public enum AppIconProvider {
    /// 加载当前应用的高清品牌图标
    @MainActor
    public static func loadAppIcon() -> NSImage? {
        if let current = NSApp.applicationIconImage, current.isValid {
            return current
        }
        if let iconUrl = Bundle.module.url(forResource: "AppIcon", withExtension: "png") ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            return NSImage(contentsOf: iconUrl)
        }
        return nil
    }
}
