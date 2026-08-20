import XCTest
import CoreGraphics
@testable import JianTieCore

// MARK: - Test Doubles

private final class MockDragMonitor: DragMonitoring, @unchecked Sendable {
    var isMonitoring: Bool = false
    var isDraggingActive: Bool = false
    var onDragStartHandler: (@Sendable ([URL], CGPoint) -> Void)?
    var onDragEndHandler: (@Sendable () -> Void)?

    func startMonitoring(
        onDragStart: @escaping @Sendable ([URL], CGPoint) -> Void,
        onDragEnd: @escaping @Sendable () -> Void
    ) {
        self.isMonitoring = true
        self.onDragStartHandler = onDragStart
        self.onDragEndHandler = onDragEnd
    }

    func stopMonitoring() {
        self.isMonitoring = false
        self.onDragStartHandler = nil
        self.onDragEndHandler = nil
    }

    func simulateDragStart(files: [URL], at point: CGPoint) {
        onDragStartHandler?(files, point)
    }

    func simulateDragEnd() {
        onDragEndHandler?()
    }
}

@MainActor
final class ShelfEngineTests: XCTestCase {
    private var dragMonitor: MockDragMonitor!
    private var engine: ShelfEngine!
    private let testScreen = ScreenInfo(
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
    )

    override func setUp() async throws {
        try await super.setUp()
        dragMonitor = MockDragMonitor()
        engine = ShelfEngine(
            edge: .left,
            dragMonitor: dragMonitor,
            edgeMonitor: nil,
            autoStart: false
        )
    }

    func test_initialState_isHidden() {
        XCTAssertEqual(engine.state, .hidden)
        XCTAssertFalse(engine.state.isVisible)
        XCTAssertFalse(engine.state.isDragging)
    }

    func test_handleDragStarted_transitionsToRevealedDragging_andRequestsReveal() {
        var revealedVisibleFrame: CGRect?
        var revealedIsDragging: Bool?

        engine.onRequestReveal = { visibleFrame, _, isDragging in
            revealedVisibleFrame = visibleFrame
            revealedIsDragging = isDragging
        }

        let testFile = URL(fileURLWithPath: "/tmp/test.pdf")
        let dragPoint = CGPoint(x: 100, y: 500)

        engine.handleDragStarted(files: [testFile], at: dragPoint)

        XCTAssertTrue(engine.state.isVisible)
        XCTAssertTrue(engine.state.isDragging)
        if case .revealedDragging(let frame, let edge) = engine.state {
            XCTAssertEqual(edge, .left)
            XCTAssertFalse(frame.isEmpty)
        } else {
            XCTFail("Expected .revealedDragging state")
        }

        XCTAssertNotNil(revealedVisibleFrame)
        XCTAssertEqual(revealedIsDragging, true)
    }

    func test_handleDragEnded_afterDragging_transitionsToHidden_andRequestsHide() {
        var hideRequested = false
        engine.onRequestHide = { _ in
            hideRequested = true
        }

        let testFile = URL(fileURLWithPath: "/tmp/test.pdf")
        engine.handleDragStarted(files: [testFile], at: CGPoint(x: 100, y: 500))

        engine.handleDragEnded()

        XCTAssertEqual(engine.state, .hidden)
        XCTAssertFalse(engine.state.isVisible)
        XCTAssertTrue(hideRequested)
    }

    func test_handleEdgeDwell_transitionsToRevealedEmpty() {
        var revealedIsDragging: Bool?
        engine.onRequestReveal = { _, _, isDragging in
            revealedIsDragging = isDragging
        }

        engine.handleEdgeDwell(on: testScreen)

        XCTAssertTrue(engine.state.isVisible)
        XCTAssertFalse(engine.state.isDragging)
        if case .revealedEmpty(let frame, let edge) = engine.state {
            XCTAssertEqual(frame, testScreen.frame)
            XCTAssertEqual(edge, .left)
        } else {
            XCTFail("Expected .revealedEmpty state")
        }
        XCTAssertEqual(revealedIsDragging, false)
    }

    func test_handleAutoRetract_afterEdgeDwell_transitionsToHidden() {
        var hideRequested = false
        engine.onRequestHide = { _ in
            hideRequested = true
        }

        engine.handleEdgeDwell(on: testScreen)
        engine.handleAutoRetract()

        XCTAssertEqual(engine.state, .hidden)
        XCTAssertTrue(hideRequested)
    }

    func test_dismiss_whenRevealed_hidesShelf() {
        var hideRequested = false
        engine.onRequestHide = { _ in
            hideRequested = true
        }

        engine.handleEdgeDwell(on: testScreen)
        engine.dismiss()

        XCTAssertEqual(engine.state, .hidden)
        XCTAssertTrue(hideRequested)
    }
}
