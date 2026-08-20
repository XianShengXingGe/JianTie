import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import JianTieCore

final class FinderDragMonitorTests: XCTestCase {
    func test_processDragEvent_whenChangeCountUnchanged_doesNotTriggerDragStart() {
        var dragStartedCalls = 0
        let testURLs = [URL(fileURLWithPath: "/tmp/test.txt")]
        var changeCount = 10

        let monitor = FinderDragMonitor(
            dragPasteboardReader: { testURLs },
            changeCountReader: { changeCount }
        )

        monitor.startMonitoring(
            onDragStart: { _, _ in dragStartedCalls += 1 },
            onDragEnd: {}
        )

        // 模拟鼠标点击或轻微拖拽，但 changeCount 未变（无新 Finder 拖拽 Session）
        monitor.processDragEvent(location: CGPoint(x: 100, y: 100))

        XCTAssertFalse(monitor.isDraggingActive)
        XCTAssertEqual(dragStartedCalls, 0)
    }

    func test_processDragEvent_whenChangeCountChanges_triggersDragStart() {
        let expectation = expectation(description: "dragStart called")
        let testURLs = [URL(fileURLWithPath: "/tmp/test.txt")]
        var changeCount = 10

        let monitor = FinderDragMonitor(
            dragPasteboardReader: { testURLs },
            changeCountReader: { changeCount }
        )

        monitor.startMonitoring(
            onDragStart: { urls, loc in
                XCTAssertEqual(urls, testURLs)
                XCTAssertEqual(loc, CGPoint(x: 200, y: 300))
                expectation.fulfill()
            },
            onDragEnd: {}
        )

        // 模拟系统开启了新的拖拽 Session，changeCount 递增
        changeCount += 1
        monitor.processDragEvent(location: CGPoint(x: 200, y: 300))

        XCTAssertTrue(monitor.isDraggingActive)
        waitForExpectations(timeout: 1.0)
    }

    func test_processMouseUp_resetsDraggingActive_andSubsequentSameChangeCountDoesNotTrigger() {
        let testURLs = [URL(fileURLWithPath: "/tmp/test.txt")]
        var changeCount = 10
        var startCount = 0
        var endCount = 0

        let monitor = FinderDragMonitor(
            dragPasteboardReader: { testURLs },
            changeCountReader: { changeCount }
        )

        monitor.startMonitoring(
            onDragStart: { _, _ in startCount += 1 },
            onDragEnd: { endCount += 1 }
        )

        // 1. 真实拖拽
        changeCount += 1
        monitor.processDragEvent(location: CGPoint(x: 100, y: 100))
        XCTAssertTrue(monitor.isDraggingActive)

        // 2. 释放鼠标
        monitor.processMouseUpEvent()
        XCTAssertFalse(monitor.isDraggingActive)

        // 3. 释放后再次轻微移动，changeCount 未再改变
        monitor.processDragEvent(location: CGPoint(x: 105, y: 105))
        XCTAssertFalse(monitor.isDraggingActive)
    }
}
