//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import AppKit

/// 状态栏自适应模板图标构建器
public enum StatusBarIcon {
    /// 默认状态栏图标逻辑尺寸 (18x18 pt)
    public static let standardSize = NSSize(width: 18, height: 18)

    /// 创建自适应深浅色菜单栏与壁纸的 Monochrome Template 状态栏图标
    public static func createTemplateImage() -> NSImage {
        let image = NSImage(size: standardSize, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            // 使用黑色作为 Template 的 Alpha 蒙版基础色（系统会自动根据深浅色模式与选中状态着色）
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            // 1. 绘制暂存架托盘底座 (Shelf Tray Cradle)
            let trayPath = CGMutablePath()
            trayPath.move(to: CGPoint(x: 2.5, y: 7.0))
            trayPath.addLine(to: CGPoint(x: 2.5, y: 4.0))
            trayPath.addQuadCurve(to: CGPoint(x: 4.5, y: 2.0), control: CGPoint(x: 2.5, y: 2.0))
            trayPath.addLine(to: CGPoint(x: 13.5, y: 2.0))
            trayPath.addQuadCurve(to: CGPoint(x: 15.5, y: 4.0), control: CGPoint(x: 15.5, y: 2.0))
            trayPath.addLine(to: CGPoint(x: 15.5, y: 7.0))

            context.setLineWidth(1.5)
            context.addPath(trayPath)
            context.strokePath()

            // 2. 绘制剪贴板晶片项外框 (Clipboard Crystal Item)
            let cardRect = CGRect(x: 4.5, y: 5.5, width: 9.0, height: 10.0)
            let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 2.0, cornerHeight: 2.0, transform: nil)
            context.setLineWidth(1.3)
            context.addPath(cardPath)
            context.strokePath()

            // 3. 绘制晶片项内容指示线 (Item Content Indicator)
            context.setLineWidth(1.2)
            context.move(to: CGPoint(x: 6.5, y: 12.0))
            context.addLine(to: CGPoint(x: 11.5, y: 12.0))
            context.strokePath()

            context.move(to: CGPoint(x: 6.5, y: 9.0))
            context.addLine(to: CGPoint(x: 10.0, y: 9.0))
            context.strokePath()

            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = L10n.tr("preferences.app_name")
        return image
    }
}
