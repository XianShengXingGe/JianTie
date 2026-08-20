import Foundation
#if canImport(XCTest)
import XCTest
#endif
import AppKit
@testable import JianTieCore

final class StatusBarIconTests: XCTestCase {
    func test_createTemplateImage_properties() {
        let image = StatusBarIcon.createTemplateImage()

        XCTAssertEqual(image.size.width, 18)
        XCTAssertEqual(image.size.height, 18)
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "简贴")
    }

    func test_createTemplateImage_rendersPixels() {
        let image = StatusBarIcon.createTemplateImage()

        // 渲染到 18x18 位图上下文
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 18,
            pixelsHigh: 18,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 18 * 4,
            bitsPerPixel: 32
        )
        XCTAssertNotNil(rep)

        guard let bitmap = rep else { return }

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current = context

        image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))

        NSGraphicsContext.restoreGraphicsState()

        // 验证渲染包含了非零 Alpha 像素（不是空白图）
        var nonZeroAlphaCount = 0
        for y in 0..<18 {
            for x in 0..<18 {
                if let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.01 {
                    nonZeroAlphaCount += 1
                }
            }
        }

        XCTAssertGreaterThan(nonZeroAlphaCount, 10, "Status bar template icon should have visible stroke paths")
    }

    func test_createTemplateImage_multipleInvocations() {
        let image1 = StatusBarIcon.createTemplateImage()
        let image2 = StatusBarIcon.createTemplateImage()

        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
        XCTAssertEqual(image1.size, image2.size)
        XCTAssertTrue(image1.isTemplate)
        XCTAssertTrue(image2.isTemplate)
    }
}
