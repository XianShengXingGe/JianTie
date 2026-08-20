import XCTest
import CoreGraphics
@testable import JianTieCore

private final class MockPreferences: PreferencesProviding, @unchecked Sendable {
    var shelfEdge: ShelfEdge = .left
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
}
