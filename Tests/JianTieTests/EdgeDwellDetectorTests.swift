import XCTest
import CoreGraphics
@testable import JianTieCore

final class EdgeDwellDetectorTests: XCTestCase {
    private var detector: EdgeDwellDetector!
    private let testScreen = ScreenInfo(
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
    )

    override func setUp() {
        super.setUp()
        detector = EdgeDwellDetector(
            dwellThreshold: 0.15, // 150ms
            retractThreshold: 0.60 // 600ms
        )
    }

    // MARK: - 150ms Edge Dwell Tests

    func test_dwellOnEdge_under150ms_doesNotTriggerReveal() {
        let edgePoint = CGPoint(x: 1.0, y: 500)

        // T = 1.0s: 鼠标刚进入边缘
        let action1 = detector.handleMouseMove(
            point: edgePoint,
            timestamp: 1.0,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: false
        )
        XCTAssertEqual(action1, .none)

        // T = 1.10s (停留 100ms < 150ms)
        let action2 = detector.handleMouseMove(
            point: edgePoint,
            timestamp: 1.10,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: false
        )
        XCTAssertEqual(action2, .none)
    }

    func test_dwellOnEdge_atOrOver150ms_triggersReveal() {
        let edgePoint = CGPoint(x: 1.0, y: 500)

        // T = 1.0s: 进入边缘
        _ = detector.handleMouseMove(
            point: edgePoint,
            timestamp: 1.0,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: false
        )

        // T = 1.15s: 停留满 150ms
        let action = detector.handleMouseMove(
            point: edgePoint,
            timestamp: 1.15,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: false
        )

        XCTAssertEqual(action, .reveal(screen: testScreen))
    }

    func test_dwellOnEdge_leavingBefore150ms_cancelsDwell() {
        let edgePoint = CGPoint(x: 1.0, y: 500)
        let centerPoint = CGPoint(x: 500, y: 500)

        // T = 1.0s: 进入边缘
        _ = detector.handleMouseMove(
            point: edgePoint,
            timestamp: 1.0,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: false
        )

        // T = 1.08s (80ms): 移向屏幕中间
        let actionLeave = detector.handleMouseMove(
            point: centerPoint,
            timestamp: 1.08,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: false
        )
        XCTAssertEqual(actionLeave, .none)

        // T = 1.20s: 即使总时间超过 150ms，也不会唤出
        let actionLater = detector.handleMouseMove(
            point: centerPoint,
            timestamp: 1.20,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: false
        )
        XCTAssertEqual(actionLater, .none)
    }

    // MARK: - 600ms Auto-Retract Tests

    func test_autoRetract_whenMouseLeavesShelf_triggersAfter600ms() {
        let shelfFrame = CGRect(x: 8, y: 380, width: 140, height: 320)
        let outsidePoint = CGPoint(x: 500, y: 500)

        // T = 2.0s: 鼠标离开 Shelf 区域
        let action1 = detector.handleMouseMove(
            point: outsidePoint,
            timestamp: 2.0,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: true,
            shelfFrame: shelfFrame
        )
        XCTAssertEqual(action1, .none)

        // T = 2.40s (400ms < 600ms)
        let action2 = detector.handleMouseMove(
            point: outsidePoint,
            timestamp: 2.40,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: true,
            shelfFrame: shelfFrame
        )
        XCTAssertEqual(action2, .none)

        // T = 2.60s (达到 600ms)
        let action3 = detector.handleMouseMove(
            point: outsidePoint,
            timestamp: 2.60,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: true,
            shelfFrame: shelfFrame
        )
        XCTAssertEqual(action3, .retract)
    }

    func test_autoRetract_reenteringShelf_resetsRetractTimer() {
        let shelfFrame = CGRect(x: 8, y: 380, width: 140, height: 320)
        let outsidePoint = CGPoint(x: 500, y: 500)
        let insidePoint = CGPoint(x: 50, y: 450)

        // T = 2.0s: 移出 Shelf
        _ = detector.handleMouseMove(
            point: outsidePoint,
            timestamp: 2.0,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: true,
            shelfFrame: shelfFrame
        )

        // T = 2.40s (400ms): 重新移入 Shelf
        let actionInside = detector.handleMouseMove(
            point: insidePoint,
            timestamp: 2.40,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: true,
            shelfFrame: shelfFrame
        )
        XCTAssertEqual(actionInside, .none)

        // T = 2.70s: 距离第一次移出已 700ms，但在 Shelf 内不缩回
        let actionStillInside = detector.handleMouseMove(
            point: insidePoint,
            timestamp: 2.70,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: true,
            shelfFrame: shelfFrame
        )
        XCTAssertEqual(actionStillInside, .none)
    }

    // MARK: - Timer Driven Tests

    func test_checkTimer_triggersDwellAndRetract() {
        let edgePoint = CGPoint(x: 1.0, y: 500)

        // 鼠标进入边缘并在 1.0s 停住不动
        _ = detector.handleMouseMove(
            point: edgePoint,
            timestamp: 1.0,
            screens: [testScreen],
            edge: .left,
            isShelfRevealed: false
        )

        // 定时器在 1.10s 检查：未超时
        XCTAssertEqual(detector.checkTimer(timestamp: 1.10, isShelfRevealed: false), .none)

        // 定时器在 1.16s 检查：超时 150ms 唤出
        XCTAssertEqual(detector.checkTimer(timestamp: 1.16, isShelfRevealed: false), .reveal(screen: testScreen))
    }
}
