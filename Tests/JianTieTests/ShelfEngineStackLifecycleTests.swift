import Foundation
#if canImport(XCTest)
import XCTest
#endif
import CoreGraphics
@testable import JianTieCore

private final class MockFileChecker: FileReachableChecking, @unchecked Sendable {
    var reachablePaths: Set<String> = []

    func isReachable(file: ShelfFileReference) -> Bool {
        return reachablePaths.contains(file.url.path)
    }
}

@MainActor
final class ShelfEngineStackLifecycleTests: XCTestCase {
    private var engine: ShelfEngine!
    private var fileChecker: MockFileChecker!
    private let testScreen = ScreenInfo(
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
    )

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileChecker = MockFileChecker()
        let pruner = ShelfPruner(checker: fileChecker, interval: 10.0)
        engine = ShelfEngine(
            edge: .left,
            dragMonitor: nil,
            edgeMonitor: nil,
            pruner: pruner,
            autoStart: false
        )
    }

    func test_dropFiles_transitionsToStored_andCreatesStack() {
        var revealRequested = false
        engine.onRequestReveal = { _, _, _ in
            revealRequested = true
        }

        let fileURL = URL(fileURLWithPath: "/tmp/sample.png")
        fileChecker.reachablePaths = [fileURL.path]

        let stack = engine.dropFiles([fileURL])

        XCTAssertNotNil(stack)
        XCTAssertEqual(engine.stacks.count, 1)
        XCTAssertEqual(engine.stacks.first?.title, "sample.png")
        XCTAssertTrue(revealRequested)

        if case .stored(let frame, let edge) = engine.state {
            XCTAssertEqual(edge, .left)
        } else {
            XCTFail("Expected .stored state, got \(engine.state)")
        }
    }

    func test_dropFiles_multipleConsecutive_accumulatesMultipleStacks() {
        let file1 = URL(fileURLWithPath: "/tmp/file1.pdf")
        let file2 = URL(fileURLWithPath: "/tmp/file2.png")
        let file3 = URL(fileURLWithPath: "/tmp/file3.zip")
        fileChecker.reachablePaths = [file1.path, file2.path, file3.path]

        engine.dropFiles([file1])
        engine.dropFiles([file2, file3])

        XCTAssertEqual(engine.stacks.count, 2)
        XCTAssertEqual(engine.stacks[0].count, 2) // Newest on top
        XCTAssertEqual(engine.stacks[0].title, "file2.png +1")
        XCTAssertEqual(engine.stacks[1].count, 1)
        XCTAssertEqual(engine.stacks[1].title, "file1.pdf")
    }

    func test_dragOut_success_removesStack_andDismissesWhenEmpty() {
        var hideRequested = false
        engine.onRequestHide = { _ in
            hideRequested = true
        }

        let fileURL = URL(fileURLWithPath: "/tmp/item.txt")
        fileChecker.reachablePaths = [fileURL.path]
        guard let stack = engine.dropFiles([fileURL]) else {
            XCTFail("Failed to drop files")
            return
        }

        engine.handleStackDragOutCompleted(stackId: stack.id, success: true)

        XCTAssertEqual(engine.stacks.count, 0)
        XCTAssertEqual(engine.state, .hidden)
        XCTAssertTrue(hideRequested)
    }

    func test_dragOut_success_withMultipleStacks_removesTargetStack_andStaysStored() {
        var hideRequested = false
        engine.onRequestHide = { _ in
            hideRequested = true
        }

        let file1 = URL(fileURLWithPath: "/tmp/a.txt")
        let file2 = URL(fileURLWithPath: "/tmp/b.txt")
        fileChecker.reachablePaths = [file1.path, file2.path]

        guard let stack1 = engine.dropFiles([file1]),
              let stack2 = engine.dropFiles([file2]) else {
            XCTFail("Failed to drop files")
            return
        }

        engine.handleStackDragOutCompleted(stackId: stack1.id, success: true)

        XCTAssertEqual(engine.stacks.count, 1)
        XCTAssertEqual(engine.stacks.first?.id, stack2.id)
        XCTAssertFalse(hideRequested)
        if case .stored = engine.state {
            // Expected
        } else {
            XCTFail("Expected .stored state, got \(engine.state)")
        }
    }

    func test_dragOut_cancelled_retainsStack_andStaysStored() {
        var hideRequested = false
        engine.onRequestHide = { _ in
            hideRequested = true
        }

        let fileURL = URL(fileURLWithPath: "/tmp/item.txt")
        fileChecker.reachablePaths = [fileURL.path]
        guard let stack = engine.dropFiles([fileURL]) else {
            XCTFail("Failed to drop files")
            return
        }

        engine.handleStackDragOutCompleted(stackId: stack.id, success: false)

        XCTAssertEqual(engine.stacks.count, 1)
        XCTAssertEqual(engine.stacks.first?.id, stack.id)
        XCTAssertFalse(hideRequested)
        if case .stored = engine.state {
            // Expected
        } else {
            XCTFail("Expected .stored state, got \(engine.state)")
        }
    }

    func test_manualDiscard_removesStack_andDismissesWhenEmpty() {
        var hideRequested = false
        engine.onRequestHide = { _ in
            hideRequested = true
        }

        let fileURL = URL(fileURLWithPath: "/tmp/to_discard.txt")
        fileChecker.reachablePaths = [fileURL.path]
        guard let stack = engine.dropFiles([fileURL]) else {
            XCTFail("Failed to drop files")
            return
        }

        engine.removeStack(id: stack.id)

        XCTAssertEqual(engine.stacks.count, 0)
        XCTAssertEqual(engine.state, .hidden)
        XCTAssertTrue(hideRequested)
    }

    func test_finderDragEnd_whenStacksPresent_returnsToStored_notHidden() {
        var hideRequested = false
        engine.onRequestHide = { _ in
            hideRequested = true
        }

        let fileURL = URL(fileURLWithPath: "/tmp/persisted.txt")
        fileChecker.reachablePaths = [fileURL.path]
        engine.dropFiles([fileURL])

        // Finder drag starts
        engine.handleDragStarted(files: [fileURL], at: CGPoint(x: 10, y: 100))
        XCTAssertTrue(engine.state.isDragging)

        // Finder drag ends without drop into shelf
        engine.handleDragEnded()

        XCTAssertFalse(hideRequested)
        XCTAssertEqual(engine.stacks.count, 1)
        if case .stored = engine.state {
            // Expected
        } else {
            XCTFail("Expected .stored state, got \(engine.state)")
        }
    }

    func test_pruneInvalidStacks_inEngine_removesUnreachableStacks_andDismissesWhenEmpty() {
        var hideRequested = false
        engine.onRequestHide = { _ in
            hideRequested = true
        }

        let file1 = URL(fileURLWithPath: "/tmp/live.txt")
        let file2 = URL(fileURLWithPath: "/tmp/stale.txt")
        fileChecker.reachablePaths = [file1.path, file2.path]

        let stack1 = engine.dropFiles([file1])!
        let stack2 = engine.dropFiles([file2])!
        XCTAssertEqual(engine.stacks.count, 2)

        // file2 is deleted/unreachable
        fileChecker.reachablePaths = [file1.path]
        engine.pruneInvalidStacks()

        XCTAssertEqual(engine.stacks.count, 1)
        XCTAssertEqual(engine.stacks.first?.id, stack1.id)
        XCTAssertFalse(hideRequested)

        // file1 also becomes unreachable
        fileChecker.reachablePaths = []
        engine.pruneInvalidStacks()

        XCTAssertEqual(engine.stacks.count, 0)
        XCTAssertEqual(engine.state, .hidden)
        XCTAssertTrue(hideRequested)
    }
}
