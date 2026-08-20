import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import JianTieCore

private final class MockPasteboardReader: PasteboardProviding, @unchecked Sendable {
    var changeCount: Int = 0
    var stubbedItem: ClipboardContent?

    func readItem() -> ClipboardContent? {
        stubbedItem
    }
}

private final class EngineTestPreferences: PreferencesProviding, @unchecked Sendable {
    var launchAtLogin: Bool = true
    var hasConfiguredLaunchAtLogin: Bool = true
    var hotKeyTrigger: HotKeyTrigger = .default
    var shelfEdge: ShelfEdge = .left
    var shelfVerticalPercent: Double = 0.5
    var clipboardCapacityLimit: ClipboardCapacityLimit = .count1000
    var clipboardRetentionPeriod: ClipboardRetentionPeriod = .unlimited
    var appLanguage: AppLanguage = .system
}

@MainActor
final class ClipboardEngineTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private var testPreferences: EngineTestPreferences!
    private var storage: FileClipboardStorage!
    private var mockPasteboard: MockPasteboardReader!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JianTieEngineTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        testPreferences = EngineTestPreferences()
        storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)
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

    func test_engine_capturedDuplicateItem_recordsAsSeparateChronologicalEntry() {
        let engine = ClipboardEngine(
            pasteboard: mockPasteboard,
            storage: storage,
            autoStart: false
        )

        mockPasteboard.changeCount = 1
        mockPasteboard.stubbedItem = .text(ClipboardTextContent(plainText: "Text A"))
        engine.monitor.checkPasteboard()

        mockPasteboard.changeCount = 2
        mockPasteboard.stubbedItem = .text(ClipboardTextContent(plainText: "Text B"))
        engine.monitor.checkPasteboard()

        XCTAssertEqual(engine.items.count, 2)
        XCTAssertEqual(engine.items[0].plainTextSummary, "Text B")
        XCTAssertEqual(engine.items[1].plainTextSummary, "Text A")

        // Capture Text A again
        mockPasteboard.changeCount = 3
        mockPasteboard.stubbedItem = .text(ClipboardTextContent(plainText: "Text A"))
        engine.monitor.checkPasteboard()

        // All 3 items should be recorded in reverse chronological order
        XCTAssertEqual(engine.items.count, 3)
        XCTAssertEqual(engine.items[0].plainTextSummary, "Text A")
        XCTAssertEqual(engine.items[1].plainTextSummary, "Text B")
        XCTAssertEqual(engine.items[2].plainTextSummary, "Text A")
    }

    func test_engine_pruneHistory_removesExpiredItems() throws {
        testPreferences.clipboardRetentionPeriod = .days3
        let now = Date()
        let dayInSeconds: TimeInterval = 86400

        let expiredItem = ClipboardItem(
            timestamp: now.addingTimeInterval(-4 * dayInSeconds),
            content: .text(ClipboardTextContent(plainText: "Old Item"))
        )
        let validItem = ClipboardItem(
            timestamp: now.addingTimeInterval(-1 * dayInSeconds),
            content: .text(ClipboardTextContent(plainText: "New Item"))
        )

        try storage.save(items: [validItem, expiredItem])

        let engine = ClipboardEngine(
            pasteboard: mockPasteboard,
            storage: storage,
            autoStart: false
        )

        // Engine pruned on startup and pruneHistory keeps only validItem
        XCTAssertEqual(engine.items.count, 1)
        XCTAssertEqual(engine.items.first?.id, validItem.id)

        engine.pruneHistory(now: now)

        XCTAssertEqual(engine.items.count, 1)
        XCTAssertEqual(engine.items.first?.id, validItem.id)
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
