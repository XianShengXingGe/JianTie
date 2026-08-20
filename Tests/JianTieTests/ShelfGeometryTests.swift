import XCTest
import CoreGraphics
@testable import JianTieCore

final class ShelfGeometryTests: XCTestCase {
    private var calculator: ShelfGeometryCalculator!

    override func setUp() {
        super.setUp()
        calculator = ShelfGeometryCalculator(
            edgeTriggerThreshold: 3.0,
            windowSize: CGSize(width: 140, height: 320),
            edgeMargin: 8.0
        )
    }

    // MARK: - Multi-Monitor Detection Tests

    func test_findScreen_singleMonitor_findsCorrectScreen() {
        let primaryScreen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        let pointInside = CGPoint(x: 500, y: 600)
        let found = calculator.findScreen(for: pointInside, in: [primaryScreen])

        XCTAssertEqual(found, primaryScreen)
    }

    func test_findScreen_dualMonitorsSideBySide_findsSecondScreen() {
        let screen1 = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let screen2 = ScreenInfo(
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 1920, y: 0, width: 2560, height: 1440)
        )

        let pointOnScreen2 = CGPoint(x: 2200, y: 500)
        let found = calculator.findScreen(for: pointOnScreen2, in: [screen1, screen2])

        XCTAssertEqual(found, screen2)
    }

    func test_findScreen_dualMonitorsStacked_findsTopScreen() {
        let bottomScreen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let topScreen = ScreenInfo(
            frame: CGRect(x: 0, y: 1080, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 1080, width: 1920, height: 1080)
        )

        let pointOnTop = CGPoint(x: 400, y: 1500)
        let found = calculator.findScreen(for: pointOnTop, in: [bottomScreen, topScreen])

        XCTAssertEqual(found, topScreen)
    }

    // MARK: - Edge Trigger Zone Tests

    func test_isPointInEdgeTriggerZone_leftEdge_withinThreshold_returnsTrue() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        // 左边缘 0 ~ 3px
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 0, y: 500), screen: screen, edge: .left))
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 2.5, y: 500), screen: screen, edge: .left))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 10, y: 500), screen: screen, edge: .left))
    }

    func test_isPointInEdgeTriggerZone_rightEdge_withinThreshold_returnsTrue() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        // 右边缘 1917 ~ 1920px
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1920, y: 500), screen: screen, edge: .right))
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1918, y: 500), screen: screen, edge: .right))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1910, y: 500), screen: screen, edge: .right))
    }

    func test_isPointInEdgeTriggerZone_outsideYBounds_returnsFalse() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        // Y 轴超出屏幕
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 1200), screen: screen, edge: .left))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: -10), screen: screen, edge: .left))
    }

    // MARK: - Window Frame Calculation Tests

    func test_calculateWindowFrames_leftEdge() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        let (visible, hidden) = calculator.calculateWindowFrames(screen: screen, edge: .left)

        // visibleFrame 应在屏幕左边缘加 margin 处，Y 居中
        XCTAssertEqual(visible.origin.x, 8.0)
        XCTAssertEqual(visible.origin.y, 25 + 1055 / 2 - 320 / 2)
        XCTAssertEqual(visible.width, 140)
        XCTAssertEqual(visible.height, 320)

        // hiddenFrame 应在屏幕左侧外部
        XCTAssertEqual(hidden.origin.x, -160) // 0 - 140 - 20
        XCTAssertEqual(hidden.origin.y, visible.origin.y)
    }

    func test_calculateWindowFrames_rightEdge() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        let (visible, hidden) = calculator.calculateWindowFrames(screen: screen, edge: .right)

        // visibleFrame 应在屏幕右边缘减 width - margin 处
        XCTAssertEqual(visible.origin.x, 1920 - 140 - 8.0)
        XCTAssertEqual(visible.origin.y, 25 + 1055 / 2 - 320 / 2)

        // hiddenFrame 应在屏幕右侧外部
        XCTAssertEqual(hidden.origin.x, 1940) // 1920 + 20
    }

    // MARK: - Popover Frame Calculation Tests

    func test_calculatePopoverFrame_leftEdge_anchorsToRight() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let cardFrame = CGRect(x: 8, y: 500, width: 124, height: 52)
        let popoverSize = CGSize(width: 260, height: 180)

        let frame = calculator.calculatePopoverFrame(
            cardScreenFrame: cardFrame,
            popoverSize: popoverSize,
            screen: screen,
            edge: .left,
            spacing: 8.0
        )

        // 左停靠时向右展开：x = cardFrame.maxX + 8 = 132 + 8 = 140
        XCTAssertEqual(frame.origin.x, 140.0)
        // y 居中对齐 cardFrame.midY (526) - 180 / 2 = 436
        XCTAssertEqual(frame.origin.y, 436.0)
        XCTAssertEqual(frame.width, 260.0)
        XCTAssertEqual(frame.height, 180.0)
    }

    func test_calculatePopoverFrame_rightEdge_anchorsToLeft() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let cardFrame = CGRect(x: 1788, y: 500, width: 124, height: 52)
        let popoverSize = CGSize(width: 260, height: 180)

        let frame = calculator.calculatePopoverFrame(
            cardScreenFrame: cardFrame,
            popoverSize: popoverSize,
            screen: screen,
            edge: .right,
            spacing: 8.0
        )

        // 右停靠时向左展开：x = cardFrame.minX - 260 - 8 = 1788 - 268 = 1520
        XCTAssertEqual(frame.origin.x, 1520.0)
        XCTAssertEqual(frame.origin.y, 436.0)
    }

    func test_calculatePopoverFrame_topClamping_doesNotExceedVisibleTop() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055) // maxY = 1080
        )
        // 卡片位于屏幕极顶部
        let cardFrame = CGRect(x: 8, y: 1000, width: 124, height: 52)
        let popoverSize = CGSize(width: 260, height: 200)

        let frame = calculator.calculatePopoverFrame(
            cardScreenFrame: cardFrame,
            popoverSize: popoverSize,
            screen: screen,
            edge: .left,
            spacing: 8.0
        )

        // 目标 midY = 1026 - 100 = 926. 最大 y = 1080 - 200 - 8 = 872
        XCTAssertEqual(frame.origin.y, 872.0)
        XCTAssertEqual(frame.origin.x, 140.0)
    }

    func test_calculatePopoverFrame_bottomClamping_doesNotExceedVisibleBottom() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055) // minY = 25
        )
        // 卡片位于屏幕极底部
        let cardFrame = CGRect(x: 8, y: 30, width: 124, height: 52)
        let popoverSize = CGSize(width: 260, height: 200)

        let frame = calculator.calculatePopoverFrame(
            cardScreenFrame: cardFrame,
            popoverSize: popoverSize,
            screen: screen,
            edge: .left,
            spacing: 8.0
        )

        // 目标 midY = 56 - 100 = -44. 最小 y = 25 + 8 = 33
        XCTAssertEqual(frame.origin.y, 33.0)
        XCTAssertEqual(frame.origin.x, 140.0)
    }
}
