import XCTest
import Foundation
@testable import JianTieCore

final class ShelfStackTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }

    func test_singleFileReference_propertiesAndBookmark() throws {
        let fileURL = tempDirectory.appendingPathComponent("document.pdf")
        let testData = "Hello JianTie".data(using: .utf8)!
        try testData.write(to: fileURL)

        let ref = ShelfFileReference(url: fileURL)

        XCTAssertEqual(ref.fileName, "document.pdf")
        XCTAssertEqual(ref.fileSize, Int64(testData.count))
        XCTAssertFalse(ref.isDirectory)
        XCTAssertTrue(ref.isReachable)
        XCTAssertEqual(
            ref.resolveURL()?.resolvingSymlinksInPath().path,
            fileURL.resolvingSymlinksInPath().path
        )
    }

    func test_singleFileStack_titleAndSize() throws {
        let fileURL = tempDirectory.appendingPathComponent("report.docx")
        try "Content".data(using: .utf8)!.write(to: fileURL)

        let ref = ShelfFileReference(url: fileURL)
        let stack = ShelfStack(files: [ref])

        XCTAssertEqual(stack.count, 1)
        XCTAssertEqual(stack.title, "report.docx")
        XCTAssertEqual(stack.totalSize, Int64(7))
        XCTAssertTrue(stack.isReachable)
        XCTAssertEqual(stack.urls, [fileURL])
    }

    func test_multiFileStack_titleFormattingAndTotalSize() throws {
        let file1 = tempDirectory.appendingPathComponent("image1.png")
        let file2 = tempDirectory.appendingPathComponent("image2.png")
        let file3 = tempDirectory.appendingPathComponent("image3.png")

        try "123".data(using: .utf8)!.write(to: file1)
        try "4567".data(using: .utf8)!.write(to: file2)
        try "89".data(using: .utf8)!.write(to: file3)

        let refs = [
            ShelfFileReference(url: file1),
            ShelfFileReference(url: file2),
            ShelfFileReference(url: file3)
        ]
        let stack = ShelfStack(files: refs)

        XCTAssertEqual(stack.count, 3)
        XCTAssertEqual(stack.title, "image1.png +2")
        XCTAssertEqual(stack.totalSize, 3 + 4 + 2)
        XCTAssertTrue(stack.isReachable)
        XCTAssertEqual(stack.urls.count, 3)
    }

    func test_fileReference_whenFileDeleted_isNotReachable() throws {
        let fileURL = tempDirectory.appendingPathComponent("temp.txt")
        try "temp".data(using: .utf8)!.write(to: fileURL)

        let ref = ShelfFileReference(url: fileURL)
        XCTAssertTrue(ref.isReachable)

        try FileManager.default.removeItem(at: fileURL)
        XCTAssertFalse(ref.isReachable)
        XCTAssertNil(ref.resolveURL())
    }
}
