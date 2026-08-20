#if canImport(XCTest)
import XCTest
#endif
import Foundation
@testable import JianTieCore

@MainActor
final class ShelfQuickLookTests: XCTestCase {
    private var tempFiles: [URL] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempFiles = []
    }

    override func tearDownWithError() throws {
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }

    private func createTempFile(name: String, content: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("QLTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        tempFiles.append(dir)
        return url
    }

    // MARK: - Space Toggle & ESC Tests

    func test_spaceKey_whenClosed_opensPreviewWithHoveredURLs() throws {
        let file1 = try createTempFile(name: "photo1.jpg", content: "img1")
        let file2 = try createTempFile(name: "photo2.jpg", content: "img2")
        let stack = ShelfStack(files: [ShelfFileReference(url: file1), ShelfFileReference(url: file2)])

        let coordinator = ShelfQuickLookCoordinator()
        var presentedURLs: [URL]?
        var initialIndex: Int?
        coordinator.onShowPreview = { urls, index in
            presentedURLs = urls
            initialIndex = index
        }

        coordinator.startHoverKeyMonitoring {
            stack.resolvedURLs
        }

        XCTAssertFalse(coordinator.isPreviewOpen)

        let handled = coordinator.handleSpaceKeyPress()
        XCTAssertTrue(handled)
        XCTAssertTrue(coordinator.isPreviewOpen)
        XCTAssertEqual(presentedURLs?.count, 2)
        XCTAssertEqual(initialIndex, 0)
    }

    func test_spaceKey_whenOpen_togglesAndClosesPreview() throws {
        let file1 = try createTempFile(name: "document.pdf", content: "pdf content")
        let stack = ShelfStack(files: [ShelfFileReference(url: file1)])

        let coordinator = ShelfQuickLookCoordinator()
        var closeCalled = false
        coordinator.onClosePreview = {
            closeCalled = true
        }

        coordinator.startHoverKeyMonitoring {
            stack.resolvedURLs
        }

        coordinator.preview(urls: stack.resolvedURLs)
        XCTAssertTrue(coordinator.isPreviewOpen)

        let handled = coordinator.handleSpaceKeyPress()
        XCTAssertTrue(handled)
        XCTAssertFalse(coordinator.isPreviewOpen)
        XCTAssertTrue(closeCalled)
    }

    func test_escapeKey_whenOpen_closesPreview() throws {
        let file1 = try createTempFile(name: "doc.txt", content: "text")
        let coordinator = ShelfQuickLookCoordinator()
        var closeCalled = false
        coordinator.onClosePreview = {
            closeCalled = true
        }

        coordinator.preview(urls: [file1])
        XCTAssertTrue(coordinator.isPreviewOpen)

        let handled = coordinator.handleEscapeKeyPress()
        XCTAssertTrue(handled)
        XCTAssertFalse(coordinator.isPreviewOpen)
        XCTAssertTrue(closeCalled)
    }

    func test_escapeKey_whenClosed_returnsFalse() {
        let coordinator = ShelfQuickLookCoordinator()
        let handled = coordinator.handleEscapeKeyPress()
        XCTAssertFalse(handled)
        XCTAssertFalse(coordinator.isPreviewOpen)
    }

    // MARK: - Layered Targets (Stack vs Hover Popover Sub-file)

    func test_hoverPopoverSubFile_switchesPreviewToSingleFile() throws {
        let file1 = try createTempFile(name: "item1.png", content: "data1")
        let file2 = try createTempFile(name: "item2.png", content: "data2")
        let stack = ShelfStack(files: [ShelfFileReference(url: file1), ShelfFileReference(url: file2)])

        let coordinator = ShelfQuickLookCoordinator()
        var previewedURLs: [URL] = []
        coordinator.onShowPreview = { urls, _ in
            previewedURLs = urls
        }

        // 1. 悬停在主 Stack
        coordinator.startHoverKeyMonitoring {
            stack.resolvedURLs
        }

        // 2. 悬停进入浮层子项 file2
        coordinator.startHoverKeyMonitoring {
            [file2]
        }

        _ = coordinator.handleSpaceKeyPress()
        XCTAssertEqual(previewedURLs.count, 1)
        XCTAssertEqual(previewedURLs.first?.standardizedFileURL.path, file2.standardizedFileURL.path)

        // 3. 移出子项，恢复到全 Stack
        coordinator.closePreview()
        coordinator.startHoverKeyMonitoring {
            stack.resolvedURLs
        }

        _ = coordinator.handleSpaceKeyPress()
        XCTAssertEqual(previewedURLs.count, 2)
    }

    // MARK: - Lifecycle Dismissal Tests

    func test_dragStarted_automaticallyDismissesPreview() throws {
        let file1 = try createTempFile(name: "file.txt", content: "data")
        let coordinator = ShelfQuickLookCoordinator()
        var closeCalled = false
        coordinator.onClosePreview = {
            closeCalled = true
        }

        coordinator.startHoverKeyMonitoring { [file1] }
        coordinator.preview(urls: [file1])
        XCTAssertTrue(coordinator.isPreviewOpen)
        XCTAssertTrue(coordinator.isHoveringShelf)

        coordinator.notifyDragStarted()
        XCTAssertFalse(coordinator.isPreviewOpen)
        XCTAssertFalse(coordinator.isHoveringShelf)
        XCTAssertTrue(closeCalled)
    }

    func test_shelfHidden_automaticallyDismissesPreview() throws {
        let file1 = try createTempFile(name: "file.txt", content: "data")
        let coordinator = ShelfQuickLookCoordinator()
        var closeCalled = false
        coordinator.onClosePreview = {
            closeCalled = true
        }

        coordinator.startHoverKeyMonitoring { [file1] }
        coordinator.preview(urls: [file1])
        XCTAssertTrue(coordinator.isPreviewOpen)

        coordinator.notifyShelfHidden()
        XCTAssertFalse(coordinator.isPreviewOpen)
        XCTAssertFalse(coordinator.isHoveringShelf)
        XCTAssertTrue(closeCalled)
    }

    // MARK: - Non-existent file filtering

    func test_nonExistentFiles_areFilteredOutBeforePreview() {
        let nonExistentURL = URL(fileURLWithPath: "/tmp/non_existent_\(UUID().uuidString).dat")
        let coordinator = ShelfQuickLookCoordinator()
        var showCalled = false
        coordinator.onShowPreview = { _, _ in
            showCalled = true
        }

        coordinator.startHoverKeyMonitoring { [nonExistentURL] }
        let handled = coordinator.handleSpaceKeyPress()

        XCTAssertFalse(handled)
        XCTAssertFalse(showCalled)
        XCTAssertFalse(coordinator.isPreviewOpen)
    }
}
