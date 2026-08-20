import XCTest
import CoreGraphics
@testable import JianTieCore

@MainActor
final class ShelfHoverPopoverTests: XCTestCase {
    private var tempFiles: [URL] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempFiles = []
    }

    override func tearDownWithError() throws {
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        ShelfHoverPopoverCoordinator.shared.hideImmediately()
        try super.tearDownWithError()
    }

    private func createTempFile(name: String, content: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("HoverTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        tempFiles.append(dir)
        return url
    }

    // MARK: - Stack Data Model Tests for Popover

    func test_singleFileStack_providesCorrectDetailsForPopover() throws {
        let fileURL = try createTempFile(name: "design_spec_v2_final_approved.pdf", content: "Specification content details")
        let fileRef = ShelfFileReference(url: fileURL)
        let stack = ShelfStack(files: [fileRef])

        XCTAssertEqual(stack.count, 1)
        XCTAssertEqual(stack.files.first?.fileName, "design_spec_v2_final_approved.pdf")
        XCTAssertGreaterThan(stack.totalSize, 0)
        XCTAssertEqual(stack.resolvedURLs.first?.standardizedFileURL.path, fileURL.standardizedFileURL.path)
    }

    func test_multiFileStack_providesCompleteListForPopover() throws {
        let file1 = try createTempFile(name: "screenshot_01.png", content: "image1")
        let file2 = try createTempFile(name: "screenshot_02.png", content: "image222")
        let file3 = try createTempFile(name: "notes.txt", content: "some text notes")

        let stack = ShelfStack(files: [
            ShelfFileReference(url: file1),
            ShelfFileReference(url: file2),
            ShelfFileReference(url: file3)
        ])

        XCTAssertEqual(stack.count, 3)
        XCTAssertEqual(stack.files.count, 3)
        XCTAssertEqual(stack.files.map(\.fileName), ["screenshot_01.png", "screenshot_02.png", "notes.txt"])
        XCTAssertEqual(stack.resolvedURLs.count, 3)
        XCTAssertEqual(stack.totalSize, stack.files.reduce(0) { $0 + $1.fileSize })
    }

    // MARK: - Popover Coordinator Lifecycle & Debounce Tests

    func test_hoverCoordinator_mouseEnteredAndDebounceTriggersShow() async throws {
        let fileURL = try createTempFile(name: "test_doc.txt", content: "sample")
        let stack = ShelfStack(files: [ShelfFileReference(url: fileURL)])
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let cardFrame = CGRect(x: 8, y: 500, width: 124, height: 52)

        let coordinator = ShelfHoverPopoverCoordinator()
        var showCallbackInvoked = false
        coordinator.onShowPopover = { s, _, _, _ in
            if s.id == stack.id {
                showCallbackInvoked = true
            }
        }

        XCTAssertFalse(coordinator.isPopoverVisible)

        coordinator.notifyMouseEnteredCard(
            stack: stack,
            cardScreenFrame: cardFrame,
            screen: screen,
            edge: .left,
            delay: 0.05 // 用短延时加速测试
        )

        // 初始未到达延时时，浮层尚未展示
        XCTAssertFalse(coordinator.isPopoverVisible)
        XCTAssertFalse(showCallbackInvoked)

        // 等待延时结束
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertTrue(coordinator.isPopoverVisible)
        XCTAssertTrue(showCallbackInvoked)
        XCTAssertEqual(coordinator.activeStack?.id, stack.id)

        coordinator.hideImmediately()
        XCTAssertFalse(coordinator.isPopoverVisible)
    }

    func test_hoverCoordinator_mouseExitedBeforeDebounce_cancelsShow() async throws {
        let fileURL = try createTempFile(name: "cancel_doc.txt", content: "data")
        let stack = ShelfStack(files: [ShelfFileReference(url: fileURL)])
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let cardFrame = CGRect(x: 8, y: 500, width: 124, height: 52)

        let coordinator = ShelfHoverPopoverCoordinator()
        var showCallbackInvoked = false
        coordinator.onShowPopover = { _, _, _, _ in
            showCallbackInvoked = true
        }

        coordinator.notifyMouseEnteredCard(
            stack: stack,
            cardScreenFrame: cardFrame,
            screen: screen,
            edge: .left,
            delay: 0.10
        )

        // 快速移出（在 100ms 防抖内）
        coordinator.notifyMouseExitedCard()

        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertFalse(coordinator.isPopoverVisible)
        XCTAssertFalse(showCallbackInvoked)
        XCTAssertNil(coordinator.activeStack)
    }

    func test_hoverCoordinator_dragStarted_immediatelyDismissesPopover() async throws {
        let fileURL = try createTempFile(name: "drag_doc.txt", content: "dragging data")
        let stack = ShelfStack(files: [ShelfFileReference(url: fileURL)])
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let cardFrame = CGRect(x: 8, y: 500, width: 124, height: 52)

        let coordinator = ShelfHoverPopoverCoordinator()
        coordinator.notifyMouseEnteredCard(stack: stack, cardScreenFrame: cardFrame, screen: screen, edge: .left, delay: 0.01)
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(coordinator.isPopoverVisible)

        // 启动拖拽时立即关闭
        coordinator.notifyDragStarted()
        XCTAssertFalse(coordinator.isPopoverVisible)
        XCTAssertNil(coordinator.activeStack)
    }

    func test_hoverCoordinator_mouseEnteredPopover_preventsDismissal() async throws {
        let fileURL = try createTempFile(name: "hover_test.txt", content: "data")
        let stack = ShelfStack(files: [ShelfFileReference(url: fileURL)])
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let cardFrame = CGRect(x: 8, y: 500, width: 124, height: 52)

        let coordinator = ShelfHoverPopoverCoordinator()
        coordinator.notifyMouseEnteredCard(stack: stack, cardScreenFrame: cardFrame, screen: screen, edge: .left, delay: 0.01)
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(coordinator.isPopoverVisible)

        // 鼠标移出卡片，进入浮层
        coordinator.notifyMouseExitedCard(gracePeriod: 0.05)
        coordinator.notifyMouseEnteredPopover()

        try await Task.sleep(nanoseconds: 80_000_000)

        // 因为鼠标在浮层内，浮层应维持显示
        XCTAssertTrue(coordinator.isPopoverVisible)

        // 鼠标离开浮层
        coordinator.notifyMouseExitedPopover(gracePeriod: 0.05)
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertFalse(coordinator.isPopoverVisible)
    }
}

