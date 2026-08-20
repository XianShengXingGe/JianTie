import XCTest
@testable import JianTieCore

private final class MockPasteboardReader: PasteboardProviding, @unchecked Sendable {
    var changeCount: Int = 0
    var stubbedItem: ClipboardContent?

    func readItem() -> ClipboardContent? {
        stubbedItem
    }
}

@MainActor
final class ClipboardEngineTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private var storage: FileClipboardStorage!
    private var mockPasteboard: MockPasteboardReader!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JianTieEngineTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, maxCapacity: 100)
        mockPasteboard = MockPasteboardReader()
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL = tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
        try super.tearDownWithError()
    }

    func test_monitor_whenChangeCountIncrements_capturesItem() {
        final class Box: @unchecked Sendable {
            var items: [ClipboardItem] = []
        }
        let box = Box()
        let monitor = ClipboardMonitor(pasteboard: mockPasteboard, pollInterval: 0.1) { item in
            box.items.append(item)
        }

        mockPasteboard.changeCount = 1
        mockPasteboard.stubbedItem = .text(ClipboardTextContent(plainText: "First Copy"))

        monitor.checkPasteboard()

        XCTAssertEqual(box.items.count, 1)
        XCTAssertEqual(box.items.first?.plainTextSummary, "First Copy")

        // Same changeCount should not emit again
        monitor.checkPasteboard()
        XCTAssertEqual(box.items.count, 1)

        // Increment changeCount
        mockPasteboard.changeCount = 2
        mockPasteboard.stubbedItem = .text(ClipboardTextContent(plainText: "Second Copy"))

        monitor.checkPasteboard()
        XCTAssertEqual(box.items.count, 2)
        XCTAssertEqual(box.items.last?.plainTextSummary, "Second Copy")
    }

    func test_engine_initializesWithPersistedItems() throws {
        let existingItem = ClipboardItem(
            content: .text(ClipboardTextContent(plainText: "Persisted item"))
        )
        try storage.append(item: existingItem)

        let engine = ClipboardEngine(
            pasteboard: mockPasteboard,
            storage: storage,
            autoStart: false
        )

        XCTAssertEqual(engine.items.count, 1)
        XCTAssertEqual(engine.items.first?.id, existingItem.id)
    }

    func test_engine_onCapturedItem_appendsToStorageAndUpdatesItems() {
        let engine = ClipboardEngine(
            pasteboard: mockPasteboard,
            storage: storage,
            autoStart: false
        )

        mockPasteboard.changeCount = 1
        mockPasteboard.stubbedItem = .text(ClipboardTextContent(plainText: "Captured Stream Text"))

        engine.monitor.checkPasteboard()

        XCTAssertEqual(engine.items.count, 1)
        XCTAssertEqual(engine.items.first?.plainTextSummary, "Captured Stream Text")

        let storedItems = (try? storage.load()) ?? []
        XCTAssertEqual(storedItems.count, 1)
        XCTAssertEqual(storedItems.first?.plainTextSummary, "Captured Stream Text")
    }

    func test_engine_deleteItem_updatesStorageAndItems() throws {
        let item1 = ClipboardItem(content: .text(ClipboardTextContent(plainText: "One")))
        let item2 = ClipboardItem(content: .text(ClipboardTextContent(plainText: "Two")))

        try storage.append(item: item1)
        try storage.append(item: item2)

        let engine = ClipboardEngine(
            pasteboard: mockPasteboard,
            storage: storage,
            autoStart: false
        )
        XCTAssertEqual(engine.items.count, 2)

        engine.deleteItem(id: item1.id)

        XCTAssertEqual(engine.items.count, 1)
        XCTAssertEqual(engine.items.first?.id, item2.id)

        let storedItems = try storage.load()
        XCTAssertEqual(storedItems.count, 1)
        XCTAssertEqual(storedItems.first?.id, item2.id)
    }

    func test_engine_clearHistory_clearsStorageAndItems() throws {
        let item = ClipboardItem(content: .text(ClipboardTextContent(plainText: "To Clear")))
        try storage.append(item: item)

        let engine = ClipboardEngine(
            pasteboard: mockPasteboard,
            storage: storage,
            autoStart: false
        )
        XCTAssertEqual(engine.items.count, 1)

        engine.clearHistory()

        XCTAssertTrue(engine.items.isEmpty)
        XCTAssertTrue((try storage.load()).isEmpty)
    }
}
