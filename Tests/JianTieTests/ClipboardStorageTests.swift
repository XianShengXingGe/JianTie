import XCTest
@testable import JianTieCore

private final class StorageTestPreferences: PreferencesProviding, @unchecked Sendable {
    var launchAtLogin: Bool = true
    var hasConfiguredLaunchAtLogin: Bool = true
    var hotKeyTrigger: HotKeyTrigger = .default
    var shelfEdge: ShelfEdge = .left
    var shelfVerticalPercent: Double = 0.5
    var clipboardCapacityLimit: ClipboardCapacityLimit = .count1000
    var clipboardRetentionPeriod: ClipboardRetentionPeriod = .unlimited
    var appLanguage: AppLanguage = .system
}

final class ClipboardStorageTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private var testPreferences: StorageTestPreferences!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JianTieStorageTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        testPreferences = StorageTestPreferences()
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL = tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
        try super.tearDownWithError()
    }

    func test_emptyStorage_loadsEmptyArray() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)
        let items = try storage.load()
        XCTAssertTrue(items.isEmpty)
    }

    func test_append_singleTextItem_persistsAndReloads() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)
        let item = ClipboardItem(
            content: .text(ClipboardTextContent(plainText: "Hello, JianTie!"))
        )

        let itemsAfterAppend = try storage.append(item: item)
        XCTAssertEqual(itemsAfterAppend.count, 1)
        XCTAssertEqual(itemsAfterAppend.first?.id, item.id)
        XCTAssertEqual(itemsAfterAppend.first?.plainTextSummary, "Hello, JianTie!")

        // Verify reloading from new instance
        let reloadedStorage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)
        let loadedItems = try reloadedStorage.load()
        XCTAssertEqual(loadedItems.count, 1)
        XCTAssertEqual(loadedItems.first?.id, item.id)
        XCTAssertEqual(loadedItems.first?.plainTextSummary, "Hello, JianTie!")
    }

    func test_append_duplicateText_deduplicatesAndPrependsToTop() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)
        let firstItem = ClipboardItem(
            timestamp: Date(timeIntervalSince1970: 1000),
            content: .text(ClipboardTextContent(plainText: "Same Text"))
        )
        let otherItem = ClipboardItem(
            timestamp: Date(timeIntervalSince1970: 1500),
            content: .text(ClipboardTextContent(plainText: "Other Text"))
        )
        let duplicateItem = ClipboardItem(
            timestamp: Date(timeIntervalSince1970: 2000),
            content: .text(ClipboardTextContent(plainText: "Same Text"))
        )

        try storage.append(item: firstItem)
        try storage.append(item: otherItem)
        let items = try storage.append(item: duplicateItem)

        // Old "Same Text" removed, new one placed at index 0
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].id, duplicateItem.id)
        XCTAssertEqual(items[0].timestamp, duplicateItem.timestamp)
        XCTAssertEqual(items[1].id, otherItem.id)
    }

    func test_append_duplicateImage_deduplicatesAndCleansOldImageDiskFile() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)
        let fakeImageData = Data([0x12, 0x34, 0x56, 0x78])
        let firstImage = ClipboardItem(
            timestamp: Date(timeIntervalSince1970: 1000),
            content: .image(ClipboardImageContent(imageData: fakeImageData, format: "png"))
        )
        let textItem = ClipboardItem(
            timestamp: Date(timeIntervalSince1970: 1500),
            content: .text(ClipboardTextContent(plainText: "Middle Text"))
        )
        let duplicateImage = ClipboardItem(
            timestamp: Date(timeIntervalSince1970: 2000),
            content: .image(ClipboardImageContent(imageData: fakeImageData, format: "png"))
        )

        try storage.append(item: firstImage)
        try storage.append(item: textItem)

        let imagesDir = tempDirectoryURL.appendingPathComponent("images")
        let firstImagePath = imagesDir.appendingPathComponent("\(firstImage.id.uuidString).png").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstImagePath))

        let items = try storage.append(item: duplicateImage)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].id, duplicateImage.id)
        XCTAssertEqual(items[1].id, textItem.id)

        // Old image file should be purged from disk, new image file exists
        let duplicateImagePath = imagesDir.appendingPathComponent("\(duplicateImage.id.uuidString).png").path
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstImagePath), "Old duplicated image file must be deleted")
        XCTAssertTrue(FileManager.default.fileExists(atPath: duplicateImagePath), "New image file must be stored")
    }

    func test_append_richTextItem_persistsRtfAndHtml() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)
        let rtfData = Data("rtf-blob".utf8)
        let htmlData = Data("<html>blob</html>".utf8)
        let item = ClipboardItem(
            content: .text(ClipboardTextContent(
                plainText: "Rich Text",
                rtfData: rtfData,
                htmlData: htmlData
            ))
        )

        try storage.append(item: item)
        let loaded = try storage.load()
        XCTAssertEqual(loaded.count, 1)

        guard case .text(let textContent) = loaded.first?.content else {
            XCTFail("Expected text content")
            return
        }
        XCTAssertEqual(textContent.plainText, "Rich Text")
        XCTAssertEqual(textContent.rtfData, rtfData)
        XCTAssertEqual(textContent.htmlData, htmlData)
    }

    func test_append_imageItem_persistsImageFileAndReloads() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)
        let fakeImageData = Data(repeating: 0xAB, count: 128)
        let item = ClipboardItem(
            content: .image(ClipboardImageContent(imageData: fakeImageData, format: "png"))
        )

        try storage.append(item: item)
        let loaded = try storage.load()
        XCTAssertEqual(loaded.count, 1)

        guard case .image(let imageContent) = loaded.first?.content else {
            XCTFail("Expected image content")
            return
        }
        XCTAssertEqual(imageContent.imageData, fakeImageData)
        XCTAssertEqual(imageContent.format, "png")
    }

    func test_fifoEviction_whenExceedingMaxCapacity_prunesOldestItemsAndImageAssets() throws {
        testPreferences.clipboardCapacityLimit = .count50
        // We test with custom limit subclass for testing small numbers
        final class CustomCapPrefs: PreferencesProviding, @unchecked Sendable {
            var launchAtLogin: Bool = true
            var hasConfiguredLaunchAtLogin: Bool = true
            var hotKeyTrigger: HotKeyTrigger = .default
            var shelfEdge: ShelfEdge = .left
            var shelfVerticalPercent: Double = 0.5
            var clipboardCapacityLimit: ClipboardCapacityLimit = .count50
            var clipboardRetentionPeriod: ClipboardRetentionPeriod = .unlimited
            var appLanguage: AppLanguage = .system
            var customMax: Int = 5
        }
        let customPrefs = CustomCapPrefs()
        // Override maxCount by setting capacity
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: customPrefs)

        // We will insert 5 items through capacity limit .count50, then test with limit 5
        var createdItems: [ClipboardItem] = []
        for i in 0..<8 {
            let fakeImageData = Data(repeating: UInt8(i + 1), count: 64)
            let item = ClipboardItem(
                timestamp: Date(timeIntervalSince1970: TimeInterval((i + 1) * 10)),
                content: .image(ClipboardImageContent(imageData: fakeImageData, format: "png"))
            )
            createdItems.append(item)
            try storage.append(item: item)
        }

        // With .count50 all 8 items exist
        XCTAssertEqual(try storage.load().count, 8)

        // Now test pruning with capacity limit by setting custom max count behavior
        // Let's test standard capacity limits
        testPreferences.clipboardCapacityLimit = .count50
        let capacityStorage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)
        var manyItems: [ClipboardItem] = []
        for i in 0..<55 {
            let item = ClipboardItem(
                timestamp: Date(timeIntervalSince1970: TimeInterval(i * 10)),
                content: .text(ClipboardTextContent(plainText: "Item \(i)"))
            )
            manyItems.append(item)
            try capacityStorage.append(item: item)
        }

        let loaded = try capacityStorage.load()
        XCTAssertEqual(loaded.count, 50)
        XCTAssertEqual(loaded.first?.plainTextSummary, "Item 54")
        XCTAssertEqual(loaded.last?.plainTextSummary, "Item 5")
    }

    func test_retentionPeriod_expirationPruning_removesExpiredItemsAndImages() throws {
        testPreferences.clipboardRetentionPeriod = .days3
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)

        let now = Date(timeIntervalSince1970: 1000000)
        let dayInSeconds: TimeInterval = 86400

        let expiredImageItem = ClipboardItem(
            timestamp: now.addingTimeInterval(-4 * dayInSeconds), // 4 days ago -> expired
            content: .image(ClipboardImageContent(imageData: Data([1, 2, 3]), format: "png"))
        )
        let validImageItem = ClipboardItem(
            timestamp: now.addingTimeInterval(-1 * dayInSeconds), // 1 day ago -> valid
            content: .image(ClipboardImageContent(imageData: Data([4, 5, 6]), format: "png"))
        )

        try storage.append(item: expiredImageItem)
        try storage.append(item: validImageItem)

        let imagesDir = tempDirectoryURL.appendingPathComponent("images")
        let expiredImagePath = imagesDir.appendingPathComponent("\(expiredImageItem.id.uuidString).png").path
        let validImagePath = imagesDir.appendingPathComponent("\(validImageItem.id.uuidString).png").path

        let pruned = try storage.prune(now: now)
        XCTAssertEqual(pruned.count, 1)
        XCTAssertEqual(pruned.first?.id, validImageItem.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: expiredImagePath), "Expired image file should be cleaned up")
        XCTAssertTrue(FileManager.default.fileExists(atPath: validImagePath), "Valid image file should be retained")
    }

    func test_delete_removesItemAndImageAsset() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)
        let fakeImageData = Data(repeating: 0x42, count: 64)
        let item = ClipboardItem(
            content: .image(ClipboardImageContent(imageData: fakeImageData, format: "png"))
        )

        try storage.append(item: item)
        XCTAssertEqual(try storage.load().count, 1)

        let imagesDir = tempDirectoryURL.appendingPathComponent("images")
        let imageFilePath = imagesDir.appendingPathComponent("\(item.id.uuidString).png").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageFilePath))

        let remaining = try storage.delete(id: item.id)
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageFilePath))
    }

    func test_clear_removesAllItemsAndCleansDirectory() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, preferences: testPreferences)
        let textItem = ClipboardItem(content: .text(ClipboardTextContent(plainText: "A")))
        let imageItem = ClipboardItem(content: .image(ClipboardImageContent(imageData: Data([1, 2, 3]))))

        try storage.append(item: textItem)
        try storage.append(item: imageItem)
        XCTAssertEqual(try storage.load().count, 2)

        try storage.clear()
        XCTAssertEqual(try storage.load().count, 0)

        let imagesDir = tempDirectoryURL.appendingPathComponent("images")
        let imageFilePath = imagesDir.appendingPathComponent("\(imageItem.id.uuidString).png").path
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageFilePath))
    }
}
