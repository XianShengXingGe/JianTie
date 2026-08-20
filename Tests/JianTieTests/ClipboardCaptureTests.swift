import XCTest
import AppKit
@testable import JianTieCore

final class ClipboardCaptureTests: XCTestCase {
    private var testPasteboard: NSPasteboard!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // 使用唯一命名的测试专属 Pasteboard，避免污染系统剪贴板与并发冲突
        testPasteboard = NSPasteboard(name: NSPasteboard.Name("JianTieCaptureTests-\(UUID().uuidString)"))
    }

    override func tearDownWithError() throws {
        testPasteboard.clearContents()
        testPasteboard.releaseGlobally()
        try super.tearDownWithError()
    }

    func test_readItem_whenPlainText_returnsTextContent() {
        let reader = SystemPasteboardReader(pasteboard: testPasteboard)

        testPasteboard.clearContents()
        testPasteboard.setString("Hello, Swift!", forType: .string)

        let result = reader.readItem()
        XCTAssertNotNil(result)

        guard case .text(let textContent) = result else {
            XCTFail("Expected text content")
            return
        }

        XCTAssertEqual(textContent.plainText, "Hello, Swift!")
        XCTAssertNil(textContent.rtfData)
        XCTAssertNil(textContent.htmlData)
    }

    func test_readItem_whenRichTextWithRTF_returnsTextAndRTF() {
        let reader = SystemPasteboardReader(pasteboard: testPasteboard)
        let rtfData = "{\\rtf1\\ansi Hello Rich}".data(using: .utf8)!

        testPasteboard.clearContents()
        testPasteboard.setString("Hello Rich", forType: .string)
        testPasteboard.setData(rtfData, forType: .rtf)

        let result = reader.readItem()
        XCTAssertNotNil(result)

        guard case .text(let textContent) = result else {
            XCTFail("Expected text content")
            return
        }

        XCTAssertEqual(textContent.plainText, "Hello Rich")
        XCTAssertEqual(textContent.rtfData, rtfData)
    }

    func test_readItem_whenRichTextWithHTML_returnsTextAndHTML() {
        let reader = SystemPasteboardReader(pasteboard: testPasteboard)
        let htmlData = "<p><b>Hello HTML</b></p>".data(using: .utf8)!

        testPasteboard.clearContents()
        testPasteboard.setString("Hello HTML", forType: .string)
        testPasteboard.setData(htmlData, forType: .html)

        let result = reader.readItem()
        XCTAssertNotNil(result)

        guard case .text(let textContent) = result else {
            XCTFail("Expected text content")
            return
        }

        XCTAssertEqual(textContent.plainText, "Hello HTML")
        XCTAssertEqual(textContent.htmlData, htmlData)
    }

    func test_readItem_whenPNGImage_returnsPNGImageContent() {
        let reader = SystemPasteboardReader(pasteboard: testPasteboard)
        let samplePNGData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG magic header

        testPasteboard.clearContents()
        testPasteboard.setData(samplePNGData, forType: .png)

        let result = reader.readItem()
        XCTAssertNotNil(result)

        guard case .image(let imageContent) = result else {
            XCTFail("Expected image content")
            return
        }

        XCTAssertEqual(imageContent.imageData, samplePNGData)
        XCTAssertEqual(imageContent.format, "png")
    }

    func test_readItem_whenTIFFImage_returnsTIFFImageContent() {
        let reader = SystemPasteboardReader(pasteboard: testPasteboard)
        let sampleTIFFData = Data([0x49, 0x49, 0x2A, 0x00]) // TIFF header

        testPasteboard.clearContents()
        testPasteboard.setData(sampleTIFFData, forType: .tiff)

        let result = reader.readItem()
        XCTAssertNotNil(result)

        guard case .image(let imageContent) = result else {
            XCTFail("Expected image content")
            return
        }

        XCTAssertEqual(imageContent.imageData, sampleTIFFData)
        XCTAssertEqual(imageContent.format, "tiff")
    }

    func test_readItem_whenFinderFileCopied_ignoresAndReturnsNil() {
        let reader = SystemPasteboardReader(pasteboard: testPasteboard)
        let fileURL = URL(fileURLWithPath: "/tmp/sample.txt")

        testPasteboard.clearContents()
        testPasteboard.writeObjects([fileURL as NSURL])

        let result = reader.readItem()
        XCTAssertNil(result, "Finder file copies must be ignored")
    }

    func test_readItem_whenEmptyPasteboard_returnsNil() {
        let reader = SystemPasteboardReader(pasteboard: testPasteboard)
        testPasteboard.clearContents()

        let result = reader.readItem()
        XCTAssertNil(result)
    }
}
