import XCTest
import CoreGraphics
@testable import JianTieCore

private final class MockPreferences: PreferencesProviding, @unchecked Sendable {
    var launchAtLogin: Bool = true
    var hasConfiguredLaunchAtLogin: Bool = true
    var shelfEdge: ShelfEdge = .left
    var clipboardCapacityLimit: ClipboardCapacityLimit = .count1000
    var clipboardRetentionPeriod: ClipboardRetentionPeriod = .unlimited
}

private final class MockDragMonitor: DragMonitoring, @unchecked Sendable {
    var isMonitoring: Bool = false
    func startMonitoring(onDragStart: @escaping @Sendable ([URL], CGPoint) -> Void, onDragEnd: @escaping @Sendable () -> Void) {
        self.isMonitoring = true
    }
    func stopMonitoring() {
        self.isMonitoring = false
    }
}

@MainActor
final class ShelfEngineEdgeSwitchingTests: XCTestCase {
    private var mockPrefs: MockPreferences!
    private var mockDrag: MockDragMonitor!
    private var testScreen: ScreenInfo!

    override func setUp() {
        super.setUp()
        mockPrefs = MockPreferences()
        mockDrag = MockDragMonitor()
        testScreen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
    }

    override func tearDown() {
        mockPrefs = nil
        mockDrag = nil
        testScreen = nil
        super.tearDown()
    }

    func test_init_loadsEdgeFromPreferences() {
        mockPrefs.shelfEdge = .right
        let engine = ShelfEngine(
            preferences: mockPrefs,
            dragMonitor: mockDrag,
            autoStart: false
        )

        XCTAssertEqual(engine.edge, .right)
    }

    func test_setEdge_persistsToPreferences() {
        mockPrefs.shelfEdge = .left
        let engine = ShelfEngine(
            preferences: mockPrefs,
            dragMonitor: mockDrag,
            autoStart: false
        )

        engine.edge = .right

        XCTAssertEqual(engine.edge, .right)
        XCTAssertEqual(mockPrefs.shelfEdge, .right)
    }

    func test_setEdge_whenHidden_doesNotTriggerReveal() {
        let engine = ShelfEngine(
            preferences: mockPrefs,
            dragMonitor: mockDrag,
            autoStart: false
        )

        var revealTriggered = false
        engine.onRequestReveal = { _, _, _ in
            revealTriggered = true
        }

        XCTAssertEqual(engine.state, .hidden)
        engine.edge = .right

        XCTAssertFalse(revealTriggered)
        XCTAssertEqual(engine.state, .hidden)
    }

    func test_setEdge_whenStored_repositionsWindowAndUpdatesState() {
        let engine = ShelfEngine(
            preferences: mockPrefs,
            dragMonitor: mockDrag,
            autoStart: false
        )

        var revealedFrames: (visible: CGRect, hidden: CGRect)?
        engine.onRequestReveal = { visible, hidden, _ in
            revealedFrames = (visible, hidden)
        }

        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? "test".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // 存入 Stack
        engine.dropFiles([tempFile])
        XCTAssertTrue(engine.state.isVisible)
        if case let .stored(_, edge) = engine.state {
            XCTAssertEqual(edge, .left)
        } else {
            XCTFail("Expected stored state")
        }

        let leftVisibleFrame = revealedFrames?.visible

        // 切换边缘至右侧
        engine.edge = .right

        if case let .stored(_, edge) = engine.state {
            XCTAssertEqual(edge, .right)
        } else {
            XCTFail("Expected stored state with right edge")
        }

        let rightVisibleFrame = revealedFrames?.visible
        XCTAssertNotNil(rightVisibleFrame)
        XCTAssertNotEqual(leftVisibleFrame?.minX, rightVisibleFrame?.minX)
        // 右侧停靠时，X 坐标应明显大于左侧停靠
        XCTAssertGreaterThan(rightVisibleFrame!.minX, leftVisibleFrame!.minX)
    }

    func test_setEdge_whenRevealedEmpty_repositionsWindowAndUpdatesState() {
        let engine = ShelfEngine(
            preferences: mockPrefs,
            dragMonitor: mockDrag,
            autoStart: false
        )

        var revealedFrames: (visible: CGRect, hidden: CGRect)?
        engine.onRequestReveal = { visible, hidden, _ in
            revealedFrames = (visible, hidden)
        }

        // 边缘悬停展开空状态
        engine.handleEdgeDwell(on: testScreen)
        XCTAssertEqual(engine.state, .revealedEmpty(screenFrame: testScreen.frame, edge: .left))

        let leftVisibleFrame = revealedFrames?.visible

        // 切换边缘至右侧
        engine.edge = .right

        XCTAssertEqual(engine.state, .revealedEmpty(screenFrame: testScreen.frame, edge: .right))
        let rightVisibleFrame = revealedFrames?.visible
        XCTAssertNotNil(rightVisibleFrame)
        XCTAssertGreaterThan(rightVisibleFrame!.minX, leftVisibleFrame!.minX)
    }

    func test_handleDragStarted_whenShelfHasStacks_doesNotSwitchScreen() {
        let screen1 = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let screen2 = ScreenInfo(
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 1920, y: 25, width: 2560, height: 1415)
        )

        let engine = ShelfEngine(
            preferences: mockPrefs,
            dragMonitor: mockDrag,
            screensProvider: { [screen1, screen2] },
            autoStart: false
        )

        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? "test".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // 1. 在 Screen 1 悬停并存入文件
        engine.handleEdgeDwell(on: screen1)
        _ = engine.dropFiles([tempFile])
        XCTAssertEqual(engine.state, .stored(screenFrame: screen1.frame, edge: .left))

        // 2. 模拟用户在 Screen 2 上拖拽新文件
        var revealedVisibleFrame: CGRect?
        engine.onRequestReveal = { visible, _, _ in
            revealedVisibleFrame = visible
        }

        engine.handleDragStarted(files: [tempFile], at: CGPoint(x: 2100, y: 500))

        // 验证：Shelf 依然维持在 Screen 1 上，不会跳跃切换到 Screen 2
        if case let .revealedDragging(screenFrame, _) = engine.state {
            XCTAssertEqual(screenFrame, screen1.frame)
        } else {
            XCTFail("Expected revealedDragging state with screen1 frame")
        }
        XCTAssertEqual(revealedVisibleFrame?.minX, 8.0) // Screen 1 left margin
    }

    func test_dropFiles_onSecondaryScreen_anchorsShelfToSecondaryScreenUntilEmpty() {
        let screen1 = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let screen2 = ScreenInfo(
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 1920, y: 25, width: 2560, height: 1415)
        )

        let engine = ShelfEngine(
            preferences: mockPrefs,
            dragMonitor: mockDrag,
            screensProvider: { [screen1, screen2] },
            autoStart: false
        )

        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? "test".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // 1. 在副屏 (Screen 2) 拖拽开始并存入文件
        engine.handleDragStarted(files: [tempFile], at: CGPoint(x: 2100, y: 500))
        let stack = engine.dropFiles([tempFile], on: screen2)
        XCTAssertNotNil(stack)

        // 验证：Shelf 状态为 stored 且固定在 Screen 2
        XCTAssertEqual(engine.state, .stored(screenFrame: screen2.frame, edge: .left))

        // 2. 模拟拖拽结束（由于 Shelf 内有文件，不应被 dismiss，而应继续留在 Screen 2）
        engine.handleDragEnded()
        XCTAssertEqual(engine.state, .stored(screenFrame: screen2.frame, edge: .left))

        // 3. 移除 Stack 后，Shelf 应该自动收回并重置
        if let stackId = stack?.id {
            engine.removeStack(id: stackId)
            XCTAssertEqual(engine.state, .hidden)
        }
    }
}
