import XCTest
import AppKit
@testable import JianTieCore

// MARK: - Test Doubles

private final class MockPasteboardWriter: PasteboardWriting, @unchecked Sendable {
    var writeResult: Bool = true
    var writtenContents: [ClipboardContent] = []

    func write(content: ClipboardContent) -> Bool {
        writtenContents.append(content)
        return writeResult
    }
}

private final class MockAppActivator: AppActivating, @unchecked Sendable {
    var currentFrontmost: AppTarget? = AppTarget(bundleIdentifier: "com.apple.Notes", processIdentifier: 1234, localizedName: "Notes")
    var activatedTargets: [AppTarget] = []
    var activateResult: Bool = true

    func frontmostApp() -> AppTarget? {
        currentFrontmost
    }

    func activate(target: AppTarget) -> Bool {
        activatedTargets.append(target)
        return activateResult
    }
}

private final class MockKeySynthesizer: KeyEventSynthesizing, @unchecked Sendable {
    var synthesizeResult: Bool = true
    var synthesizedCount: Int = 0

    func synthesizeCommandV() -> Bool {
        synthesizedCount += 1
        return synthesizeResult
    }
}

// MARK: - DirectPasteServiceTests

final class DirectPasteServiceTests: XCTestCase {

    func test_systemPasteboardWriter_writesPlainText() {
        let uniqueName = NSPasteboard.Name("test.jiantie.pasteboard.plaintext.\(UUID().uuidString)")
        let customPasteboard = NSPasteboard(name: uniqueName)
        let writer = SystemPasteboardWriter(pasteboard: customPasteboard)

        let content = ClipboardContent.text(ClipboardTextContent(plainText: "Hello, JianTie!"))
        let success = writer.write(content: content)

        XCTAssertTrue(success)
        XCTAssertEqual(customPasteboard.string(forType: .string), "Hello, JianTie!")
        XCTAssertNil(customPasteboard.data(forType: .rtf))
        XCTAssertNil(customPasteboard.data(forType: .html))
    }

    func test_systemPasteboardWriter_writesRichTextWithRtfAndHtml() {
        let uniqueName = NSPasteboard.Name("test.jiantie.pasteboard.richtext.\(UUID().uuidString)")
        let customPasteboard = NSPasteboard(name: uniqueName)
        let writer = SystemPasteboardWriter(pasteboard: customPasteboard)

        let rtfData = "{\\rtf1\\ansi Hello RichText}".data(using: .utf8)!
        let htmlData = "<p>Hello HTML</p>".data(using: .utf8)!
        let content = ClipboardContent.text(ClipboardTextContent(
            plainText: "Hello RichText",
            rtfData: rtfData,
            htmlData: htmlData
        ))

        let success = writer.write(content: content)

        XCTAssertTrue(success)
        XCTAssertEqual(customPasteboard.string(forType: .string), "Hello RichText")
        XCTAssertEqual(customPasteboard.data(forType: .rtf), rtfData)
        XCTAssertEqual(customPasteboard.data(forType: .html), htmlData)
    }

    func test_systemPasteboardWriter_writesImagePayload() {
        let uniqueName = NSPasteboard.Name("test.jiantie.pasteboard.image.\(UUID().uuidString)")
        let customPasteboard = NSPasteboard(name: uniqueName)
        let writer = SystemPasteboardWriter(pasteboard: customPasteboard)

        // 生成测试用的简单 1x1 PNG 数据
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create test PNG image")
            return
        }

        let content = ClipboardContent.image(ClipboardImageContent(imageData: pngData, format: "png"))
        let success = writer.write(content: content)

        XCTAssertTrue(success)
        XCTAssertEqual(customPasteboard.data(forType: .png), pngData)
    }

    func test_directPasteService_fullWorkflow_success() async {
        let mockWriter = MockPasteboardWriter()
        let mockActivator = MockAppActivator()
        let mockSynthesizer = MockKeySynthesizer()
        var recordedDelay: TimeInterval?

        let service = DirectPasteService(
            pasteboardWriter: mockWriter,
            appActivator: mockActivator,
            keySynthesizer: mockSynthesizer,
            yieldDelay: 0.03,
            delayProvider: { delay in
                recordedDelay = delay
            }
        )

        let target = AppTarget(bundleIdentifier: "com.apple.Safari", processIdentifier: 999, localizedName: "Safari")
        let item = ClipboardItem(content: .text(ClipboardTextContent(plainText: "Direct Paste Test")))

        let result = await service.directPaste(item: item, target: target)

        XCTAssertTrue(result)
        XCTAssertEqual(mockWriter.writtenContents.count, 1)
        XCTAssertEqual(mockWriter.writtenContents.first, item.content)
        XCTAssertEqual(mockActivator.activatedTargets.count, 1)
        XCTAssertEqual(mockActivator.activatedTargets.first?.processIdentifier, 999)
        XCTAssertEqual(recordedDelay, 0.03)
        XCTAssertEqual(mockSynthesizer.synthesizedCount, 1)
    }

    func test_directPasteService_whenTargetIsNil_writesToClipboardAndReturnsTrueWithoutActivating() async {
        let mockWriter = MockPasteboardWriter()
        let mockActivator = MockAppActivator()
        let mockSynthesizer = MockKeySynthesizer()

        let service = DirectPasteService(
            pasteboardWriter: mockWriter,
            appActivator: mockActivator,
            keySynthesizer: mockSynthesizer
        )

        let item = ClipboardItem(content: .text(ClipboardTextContent(plainText: "No Target Test")))
        let result = await service.directPaste(item: item, target: nil)

        XCTAssertTrue(result)
        XCTAssertEqual(mockWriter.writtenContents.count, 1)
        XCTAssertEqual(mockActivator.activatedTargets.count, 0)
        XCTAssertEqual(mockSynthesizer.synthesizedCount, 0)
    }

    func test_directPasteService_whenAppActivationFails_skipsKeystroke() async {
        let mockWriter = MockPasteboardWriter()
        let mockActivator = MockAppActivator()
        mockActivator.activateResult = false
        let mockSynthesizer = MockKeySynthesizer()

        let service = DirectPasteService(
            pasteboardWriter: mockWriter,
            appActivator: mockActivator,
            keySynthesizer: mockSynthesizer
        )

        let target = AppTarget(bundleIdentifier: "com.dead.app", processIdentifier: 888, localizedName: "DeadApp")
        let item = ClipboardItem(content: .text(ClipboardTextContent(plainText: "Activation Fail Test")))

        let result = await service.directPaste(item: item, target: target)

        XCTAssertTrue(result)
        XCTAssertEqual(mockWriter.writtenContents.count, 1)
        XCTAssertEqual(mockActivator.activatedTargets.count, 1)
        XCTAssertEqual(mockSynthesizer.synthesizedCount, 0)
    }

    func test_directPasteService_whenPasteboardWriteFails_returnsFalse() async {
        let mockWriter = MockPasteboardWriter()
        mockWriter.writeResult = false
        let mockActivator = MockAppActivator()
        let mockSynthesizer = MockKeySynthesizer()

        let service = DirectPasteService(
            pasteboardWriter: mockWriter,
            appActivator: mockActivator,
            keySynthesizer: mockSynthesizer
        )

        let target = AppTarget(bundleIdentifier: "com.apple.Safari", processIdentifier: 999, localizedName: "Safari")
        let item = ClipboardItem(content: .text(ClipboardTextContent(plainText: "Write Failure Test")))

        let result = await service.directPaste(item: item, target: target)

        XCTAssertFalse(result)
        XCTAssertEqual(mockActivator.activatedTargets.count, 0)
        XCTAssertEqual(mockSynthesizer.synthesizedCount, 0)
    }
}
