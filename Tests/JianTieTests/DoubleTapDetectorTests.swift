import XCTest
import AppKit
@testable import JianTieCore

final class DoubleTapDetectorTests: XCTestCase {

    func test_validDoubleTap_within300ms_triggersDoubleTap() {
        let detector = DoubleTapDetector(maxInterval: 0.3)

        // 1. 第一次按下 Command (t = 1.00)
        var result = detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: false, timestamp: 1.00)
        XCTAssertFalse(result)
        XCTAssertEqual(detector.state, .firstDown(timestamp: 1.00))

        // 2. 第一次释放 Command (t = 1.05)
        result = detector.handleFlagsChanged(isCommandPressed: false, otherModifiersPressed: false, timestamp: 1.05)
        XCTAssertFalse(result)
        XCTAssertEqual(detector.state, .firstUp(timestamp: 1.05))

        // 3. 第二次按下 Command (t = 1.20, 间隔 0.15s <= 0.30s)
        result = detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: false, timestamp: 1.20)
        XCTAssertFalse(result)
        XCTAssertEqual(detector.state, .secondDown(timestamp: 1.20))

        // 4. 第二次释放 Command (t = 1.25, 间隔 0.05s <= 0.30s)
        result = detector.handleFlagsChanged(isCommandPressed: false, otherModifiersPressed: false, timestamp: 1.25)
        XCTAssertTrue(result)
        XCTAssertEqual(detector.state, .idle)
    }

    func test_doubleTap_exceeding300ms_doesNotTrigger_andRestarts() {
        let detector = DoubleTapDetector(maxInterval: 0.3)

        // 第一次击键
        detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: false, timestamp: 1.00)
        detector.handleFlagsChanged(isCommandPressed: false, otherModifiersPressed: false, timestamp: 1.05)

        // 第二次击键在 0.40s 之后 (t = 1.45 > 1.05 + 0.30)
        let result = detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: false, timestamp: 1.45)
        XCTAssertFalse(result)
        // 应该超时并作为新的第一次按下
        XCTAssertEqual(detector.state, .firstDown(timestamp: 1.45))
    }

    func test_doubleTap_withInterveningKeyDown_resetsState() {
        let detector = DoubleTapDetector(maxInterval: 0.3)

        // 模拟用户按下 ⌘
        detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: false, timestamp: 1.00)

        // 用户按下了普通键 'C' (例如执行 ⌘C 复制)
        detector.handleKeyEvent(timestamp: 1.02)
        XCTAssertEqual(detector.state, .idle)

        // 释放 ⌘
        let result = detector.handleFlagsChanged(isCommandPressed: false, otherModifiersPressed: false, timestamp: 1.05)
        XCTAssertFalse(result)
        XCTAssertEqual(detector.state, .idle)
    }

    func test_doubleTap_withOtherModifiers_resetsState() {
        let detector = DoubleTapDetector(maxInterval: 0.3)

        // 第一次敲击 Command
        detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: false, timestamp: 1.00)
        detector.handleFlagsChanged(isCommandPressed: false, otherModifiersPressed: false, timestamp: 1.05)

        // 第二次按下时同时带有 Shift 修饰键 (⌘ + Shift)
        let result = detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: true, timestamp: 1.15)
        XCTAssertFalse(result)
        XCTAssertEqual(detector.state, .idle)
    }

    func test_doubleTap_holdingFirstTapTooLong_doesNotTrigger() {
        let detector = DoubleTapDetector(maxInterval: 0.3)

        // 按下 Command 超过 300ms 才释放
        detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: false, timestamp: 1.00)
        let releaseResult = detector.handleFlagsChanged(isCommandPressed: false, otherModifiersPressed: false, timestamp: 1.40)
        XCTAssertFalse(releaseResult)
        XCTAssertEqual(detector.state, .idle)
    }

    func test_doubleTap_holdingSecondTapTooLong_doesNotTrigger() {
        let detector = DoubleTapDetector(maxInterval: 0.3)

        // 第一次敲击正常
        detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: false, timestamp: 1.00)
        detector.handleFlagsChanged(isCommandPressed: false, otherModifiersPressed: false, timestamp: 1.05)

        // 第二次按下并在 0.5s 后才释放
        detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: false, timestamp: 1.15)
        let result = detector.handleFlagsChanged(isCommandPressed: false, otherModifiersPressed: false, timestamp: 1.65)
        XCTAssertFalse(result)
        XCTAssertEqual(detector.state, .idle)
    }

    func test_doubleTapMonitor_processEvent_triggersCallback() {
        let detector = DoubleTapDetector(maxInterval: 0.3)
        let monitor = DoubleTapMonitor(detector: detector)

        var triggerCount = 0
        monitor.startMonitoring {
            triggerCount += 1
        }
        XCTAssertTrue(monitor.isMonitoring)

        // 模拟第一次敲击
        detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: false, timestamp: 1.00)
        detector.handleFlagsChanged(isCommandPressed: false, otherModifiersPressed: false, timestamp: 1.05)

        // 模拟第二次敲击
        detector.handleFlagsChanged(isCommandPressed: true, otherModifiersPressed: false, timestamp: 1.15)
        let triggered = detector.handleFlagsChanged(isCommandPressed: false, otherModifiersPressed: false, timestamp: 1.20)

        if triggered {
            triggerCount += 1
        }

        XCTAssertEqual(triggerCount, 1)

        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)
    }
}
