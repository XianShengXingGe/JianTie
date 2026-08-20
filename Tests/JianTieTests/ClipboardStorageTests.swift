import XCTest
@testable import JianTieCore

final class ClipboardStorageTests: XCTestCase {
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JianTieStorageTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL = tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
        try super.tearDownWithError()
    }

    func test_emptyStorage_loadsEmptyArray() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, maxCapacity: 1000)
        let items = try storage.load()
        XCTAssertTrue(items.isEmpty)
    }

    func test_append_singleTextItem_persistsAndReloads() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, maxCapacity: 1000)
        let item = ClipboardItem(
            content: .text(ClipboardTextContent(plainText: "Hello, JianTie!"))
        )

        let itemsAfterAppend = try storage.append(item: item)
        XCTAssertEqual(itemsAfterAppend.count, 1)
        XCTAssertEqual(itemsAfterAppend.first?.id, item.id)
        XCTAssertEqual(itemsAfterAppend.first?.plainTextSummary, "Hello, JianTie!")

        // Verify reloading from new instance
        let reloadedStorage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, maxCapacity: 1000)
        let loadedItems = try reloadedStorage.load()
        XCTAssertEqual(loadedItems.count, 1)
        XCTAssertEqual(loadedItems.first?.id, item.id)
        XCTAssertEqual(loadedItems.first?.plainTextSummary, "Hello, JianTie!")
    }

    func test_append_duplicateContent_doesNotDeduplicate_andInsertsChronologically() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, maxCapacity: 1000)
        let firstItem = ClipboardItem(
            timestamp: Date(timeIntervalSince1970: 1000),
            content: .text(ClipboardTextContent(plainText: "Same Text"))
        )
        let secondItem = ClipboardItem(
            timestamp: Date(timeIntervalSince1970: 2000),
            content: .text(ClipboardTextContent(plainText: "Same Text"))
        )

        try storage.append(item: firstItem)
        let items = try storage.append(item: secondItem)

        XCTAssertEqual(items.count, 2)
        // Most recent at index 0
        XCTAssertEqual(items[0].id, secondItem.id)
        XCTAssertEqual(items[1].id, firstItem.id)
    }

    func test_append_richTextItem_persistsRtfAndHtml() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, maxCapacity: 1000)
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
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, maxCapacity: 1000)
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
        let maxCapacity = 5
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, maxCapacity: maxCapacity)

        var createdItems: [ClipboardItem] = []
        for i in 0..<8 {
            let fakeImageData = Data(repeating: UInt8(i), count: 64)
            let item = ClipboardItem(
                timestamp: Date(timeIntervalSince1970: TimeInterval(i * 10)),
                content: .image(ClipboardImageContent(imageData: fakeImageData, format: "png"))
            )
            createdItems.append(item)
            try storage.append(item: item)
        }

        let loaded = try storage.load()
        XCTAssertEqual(loaded.count, maxCapacity)

        // The most recent 5 items should be preserved: indices 7, 6, 5, 4, 3
        let expectedPreservedIDs = [
            createdItems[7].id,
            createdItems[6].id,
            createdItems[5].id,
            createdItems[4].id,
            createdItems[3].id
        ]
        let loadedIDs = loaded.map(\.id)
        XCTAssertEqual(loadedIDs, expectedPreservedIDs)

        // Check that evicted image files (0, 1, 2) are removed from disk
        let imagesDir = tempDirectoryURL.appendingPathComponent("images")
        let evictedIDs = [createdItems[0].id, createdItems[1].id, createdItems[2].id]
        for evictedID in evictedIDs {
            let imagePath = imagesDir.appendingPathComponent("\(evictedID.uuidString).png").path
            XCTAssertFalse(FileManager.default.fileExists(atPath: imagePath), "Evicted image file should be unlinked")
        }

        // Preserved image files should exist
        for preservedID in expectedPreservedIDs {
            let imagePath = imagesDir.appendingPathComponent("\(preservedID.uuidString).png").path
            XCTAssertTrue(FileManager.default.fileExists(atPath: imagePath), "Preserved image file should exist on disk")
        }
    }

    func test_delete_removesItemAndImageAsset() throws {
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, maxCapacity: 100)
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
        let storage = FileClipboardStorage(baseDirectoryURL: tempDirectoryURL, maxCapacity: 100)
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
