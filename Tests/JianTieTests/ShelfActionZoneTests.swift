import XCTest
@testable import JianTieCore

@MainActor
private final class ActionZoneMockAirDropService: AirDropSharingProviding {
    var performedURLs: [[URL]] = []
    var nextResult: Bool = true
    var shouldCallImmediately: Bool = true
    var pendingCompletion: ((Bool) -> Void)?

    func performAirDrop(urls: [URL], onCompletion: @escaping @MainActor (Bool) -> Void) {
        performedURLs.append(urls)
        if shouldCallImmediately {
            onCompletion(nextResult)
        } else {
            pendingCompletion = onCompletion
        }
    }

    func completePending(success: Bool) {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(success)
    }
}

private final class ActionZoneMockPasteboardWriter: PasteboardWriting, @unchecked Sendable {
    private let lock = NSLock()
    private var _writtenContents: [ClipboardContent] = []

    var writtenContents: [ClipboardContent] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _writtenContents
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _writtenContents = newValue
        }
    }

    func write(content: ClipboardContent) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        _writtenContents.append(content)
        return true
    }
}

@MainActor
final class ShelfActionZoneTests: XCTestCase {
    private var tempDir: URL!
    private var file1: URL!
    private var file2: URL!
    private var mockAirDrop: ActionZoneMockAirDropService!
    private var mockPasteboard: ActionZoneMockPasteboardWriter!
    private var engine: ShelfEngine!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        file1 = tempDir.appendingPathComponent("document1.pdf")
        try "Content 1".write(to: file1, atomically: true, encoding: .utf8)

        file2 = tempDir.appendingPathComponent("image2.png")
        try "Content 2".write(to: file2, atomically: true, encoding: .utf8)

        mockAirDrop = ActionZoneMockAirDropService()
        mockPasteboard = ActionZoneMockPasteboardWriter()

        engine = ShelfEngine(
            edge: .left,
            airDropService: mockAirDrop,
            pasteboardWriter: mockPasteboard,
            autoStart: false
        )
    }

    override func tearDown() async throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        engine = nil
        mockAirDrop = nil
        mockPasteboard = nil
        try await super.tearDown()
    }

    // MARK: - Visibility Tests

    func test_actionZoneVisibility_duringFinderDrag_isVisible() {
        XCTAssertFalse(engine.isActionZoneVisible)

        engine.handleDragStarted(files: [file1], at: CGPoint(x: 10, y: 300))
        XCTAssertTrue(engine.isActionZoneVisible)

        engine.handleDragEnded()
        XCTAssertFalse(engine.isActionZoneVisible)
    }

    func test_actionZoneVisibility_duringStackDrag_isVisible() {
        let stack = engine.dropFiles([file1])!
        engine.handleDragEnded() // Returns to stored state
        XCTAssertFalse(engine.isStackDragging)
        XCTAssertFalse(engine.isActionZoneVisible)

        engine.notifyStackDragStarted(stack: stack)
        XCTAssertTrue(engine.isStackDragging)
        XCTAssertEqual(engine.activeDraggingStack?.id, stack.id)
        XCTAssertTrue(engine.isActionZoneVisible)

        engine.notifyStackDragEnded()
        XCTAssertFalse(engine.isStackDragging)
        XCTAssertNil(engine.activeDraggingStack)
        XCTAssertFalse(engine.isActionZoneVisible)
    }

    // MARK: - Copy Path Tests

    func test_copyPath_singleFile_writesAbsolutePath_removesStack_andSetsFeedback() {
        let stack = engine.dropFiles([file1])!
        XCTAssertEqual(engine.stacks.count, 1)

        engine.handleCopyPath(urls: [file1], sourceStackId: stack.id)

        // 1. 验证写入剪贴板的路径
        XCTAssertEqual(mockPasteboard.writtenContents.count, 1)
        if case .text(let textContent) = mockPasteboard.writtenContents.first {
            XCTAssertEqual(textContent.plainText, file1.path)
        } else {
            XCTFail("Expected text content written to pasteboard")
        }

        // 2. 验证内联反馈
        XCTAssertEqual(engine.actionFeedback, "✓ Path copied")

        // 3. 验证 Stack 立即被移除，且由于 Shelf 变空触发 dismiss
        XCTAssertTrue(engine.stacks.isEmpty)
        XCTAssertEqual(engine.state, .hidden)
    }

    func test_copyPath_multipleFiles_joinsWithNewlines() {
        let stack = engine.dropFiles([file1, file2])!
        XCTAssertEqual(engine.stacks.count, 1)

        engine.handleCopyPath(urls: [file1, file2], sourceStackId: stack.id)

        XCTAssertEqual(mockPasteboard.writtenContents.count, 1)
        if case .text(let textContent) = mockPasteboard.writtenContents.first {
            let expected = "\(file1.path)\n\(file2.path)"
            XCTAssertEqual(textContent.plainText, expected)
        } else {
            XCTFail("Expected text content written to pasteboard")
        }

        XCTAssertTrue(engine.stacks.isEmpty)
        XCTAssertEqual(engine.state, .hidden)
    }

    func test_copyPath_whenMultipleStacksExist_onlyRemovesTargetStack() {
        let stack1 = engine.dropFiles([file1])!
        let stack2 = engine.dropFiles([file2])!
        XCTAssertEqual(engine.stacks.count, 2)

        engine.handleCopyPath(urls: [file1], sourceStackId: stack1.id)

        XCTAssertEqual(engine.stacks.count, 1)
        XCTAssertEqual(engine.stacks.first?.id, stack2.id)
        XCTAssertTrue(engine.state.isVisible)
    }

    // MARK: - AirDrop Tests

    func test_airDrop_success_removesStack_andDismissesWhenEmpty() {
        let stack = engine.dropFiles([file1])!
        mockAirDrop.nextResult = true

        engine.handleAirDrop(urls: [file1], sourceStackId: stack.id)

        XCTAssertEqual(mockAirDrop.performedURLs.count, 1)
        XCTAssertEqual(mockAirDrop.performedURLs.first, [file1])
        XCTAssertTrue(engine.stacks.isEmpty)
        XCTAssertEqual(engine.state, .hidden)
    }

    func test_airDrop_cancelledOrFailed_preservesStack() {
        let stack = engine.dropFiles([file1])!
        mockAirDrop.nextResult = false

        engine.handleAirDrop(urls: [file1], sourceStackId: stack.id)

        XCTAssertEqual(mockAirDrop.performedURLs.count, 1)
        XCTAssertEqual(engine.stacks.count, 1)
        XCTAssertEqual(engine.stacks.first?.id, stack.id)
        XCTAssertTrue(engine.state.isVisible)
    }

    func test_airDrop_asyncCompletion_removesStackOnSuccess() {
        let stack = engine.dropFiles([file1])!
        mockAirDrop.shouldCallImmediately = false

        engine.handleAirDrop(urls: [file1], sourceStackId: stack.id)

        XCTAssertEqual(engine.stacks.count, 1)

        // 异步完成分享
        mockAirDrop.completePending(success: true)

        XCTAssertTrue(engine.stacks.isEmpty)
        XCTAssertEqual(engine.state, .hidden)
    }

    // MARK: - Discard Tests

    func test_discardStack_removesStack_andAutoDismissesWhenEmpty() {
        let stack1 = engine.dropFiles([file1])!
        let stack2 = engine.dropFiles([file2])!
        XCTAssertEqual(engine.stacks.count, 2)

        engine.removeStack(id: stack1.id)
        XCTAssertEqual(engine.stacks.count, 1)
        XCTAssertEqual(engine.stacks.first?.id, stack2.id)
        XCTAssertTrue(engine.state.isVisible)

        engine.removeStack(id: stack2.id)
        XCTAssertTrue(engine.stacks.isEmpty)
        XCTAssertEqual(engine.state, .hidden)
    }
}
