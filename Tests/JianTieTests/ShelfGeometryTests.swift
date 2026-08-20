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

        // 默认 verticalPercent = 0.5: targetY = 25 + (1055 - 320) * 0.5 = 392.5
        // Shelf 区域: [392.5, 712.5], ±20px 容错: [372.5, 732.5]
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

        // 右边缘 1917 ~ 1920px (y = 500 在 [372.5, 732.5] 内)
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1920, y: 500), screen: screen, edge: .right))
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1918, y: 500), screen: screen, edge: .right))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1910, y: 500), screen: screen, edge: .right))
    }

    func test_isPointInEdgeTriggerZone_toleranceBoundaryConditions() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        // targetY = 392.5, height = 320, tolerance = 20
        // minY = 372.5, maxY = 732.5

        // 下边界
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 372.5), screen: screen, edge: .left))
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 373.0), screen: screen, edge: .left))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 372.0), screen: screen, edge: .left))

        // 上边界
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 732.5), screen: screen, edge: .left))
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 732.0), screen: screen, edge: .left))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 733.0), screen: screen, edge: .left))
    }

    func test_isPointInEdgeTriggerZone_outsideRestrictedVerticalZone_returnsFalse() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        // 鼠标在屏幕极顶部 (y = 1000) 或极底部 (y = 100)，即使在 X 边缘也不应触发悬停
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 1000), screen: screen, edge: .left, isFinderDrag: false))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 100), screen: screen, edge: .left, isFinderDrag: false))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1919, y: 950), screen: screen, edge: .right, isFinderDrag: false))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1919, y: 200), screen: screen, edge: .right, isFinderDrag: false))
    }

    func test_isPointInEdgeTriggerZone_finderDrag_allowsFullVerticalScreenHeight() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        // Finder 拖拽时，屏幕全高边缘均应返回 true
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 1000), screen: screen, edge: .left, isFinderDrag: true))
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 100), screen: screen, edge: .left, isFinderDrag: true))
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 500), screen: screen, edge: .left, isFinderDrag: true))
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1919, y: 1050), screen: screen, edge: .right, isFinderDrag: true))
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1919, y: 10), screen: screen, edge: .right, isFinderDrag: true))

        // X 超出边缘依然返回 false
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 50, y: 1000), screen: screen, edge: .left, isFinderDrag: true))
    }

    func test_isPointInEdgeTriggerZone_customVerticalPercent() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        // verticalPercent = 1.0 (顶部停靠): targetY = 25 + 735 * 1.0 = 760
        // 有效区间: [760 - 20, 760 + 320 + 20] = [740, 1100]
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 800), screen: screen, edge: .left, verticalPercent: 1.0))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 500), screen: screen, edge: .left, verticalPercent: 1.0))

        // verticalPercent = 0.0 (底部停靠): targetY = 25 + 735 * 0.0 = 25
        // 有效区间: [25 - 20, 25 + 320 + 20] = [5, 365]
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 100), screen: screen, edge: .left, verticalPercent: 0.0))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1, y: 500), screen: screen, edge: .left, verticalPercent: 0.0))
    }

    func test_isPointInEdgeTriggerZone_multiDisplaySecondaryScreen() {
        let screen2 = ScreenInfo(
            frame: CGRect(x: 1920, y: 100, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 1920, y: 100, width: 2560, height: 1440)
        )
        // targetY = 100 + (1440 - 320) * 0.5 = 100 + 560 = 660
        // 有效区间: [640, 660 + 320 + 20] = [640, 1000]

        // Screen 2 左边缘 (1920 ~ 1923)
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1921, y: 700), screen: screen2, edge: .left))
        XCTAssertFalse(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1921, y: 1300), screen: screen2, edge: .left))
        XCTAssertTrue(calculator.isPointInEdgeTriggerZone(point: CGPoint(x: 1921, y: 1300), screen: screen2, edge: .left, isFinderDrag: true))
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

        // hiddenFrame 应在屏幕左侧，限制在屏幕边界内以防多屏溢出
        XCTAssertEqual(hidden.origin.x, 0.0)
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

        // hiddenFrame 应限制在屏幕右边界内
        XCTAssertEqual(hidden.origin.x, 1920 - 140)
    }

    func test_calculateWindowFrames_secondaryScreenRightOfPrimary_doesNotOverlapPrimaryScreen() {
        let screen1 = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let screen2 = ScreenInfo(
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 1920, y: 0, width: 2560, height: 1440)
        )

        let (visible, hidden) = calculator.calculateWindowFrames(screen: screen2, edge: .left)

        // 验证：visibleFrame 与 hiddenFrame 均必须位于 screen2 内部，不得溢出进入 screen1
        XCTAssertGreaterThanOrEqual(visible.minX, screen2.frame.minX)
        XCTAssertGreaterThanOrEqual(hidden.minX, screen2.frame.minX)
        XCTAssertEqual(hidden.minX, 1920.0)

        // 验证：hiddenFrame 绝不能与主屏 (screen1) 的内容区域重叠
        let overlapWithScreen1 = hidden.intersection(screen1.frame)
        XCTAssertTrue(overlapWithScreen1.isNull || overlapWithScreen1.width <= 0)
    }

    func test_calculateWindowFrames_secondaryScreenLeftOfPrimary_doesNotOverlapPrimaryScreen() {
        let screen1 = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let screen2 = ScreenInfo(
            frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        )

        let (visible, hidden) = calculator.calculateWindowFrames(screen: screen2, edge: .right)

        // 验证：visibleFrame 与 hiddenFrame 均必须位于 screen2 内部，不得溢出进入 screen1
        XCTAssertLessThanOrEqual(visible.maxX, screen2.frame.maxX)
        XCTAssertLessThanOrEqual(hidden.maxX, screen2.frame.maxX)
        XCTAssertEqual(hidden.maxX, 0.0)

        // 验证：hiddenFrame 绝不能与主屏 (screen1) 的内容区域重叠
        let overlapWithScreen1 = hidden.intersection(screen1.frame)
        XCTAssertTrue(overlapWithScreen1.isNull || overlapWithScreen1.width <= 0)
    }

    func test_calculateWindowFrames_withVerticalPercentsAndClamping() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        // 1. verticalPercent = 0.0 (底部)
        let (vis0, _) = calculator.calculateWindowFrames(screen: screen, edge: .left, verticalPercent: 0.0)
        XCTAssertEqual(vis0.origin.y, 25.0)

        // 2. verticalPercent = 1.0 (顶部)
        let (vis1, _) = calculator.calculateWindowFrames(screen: screen, edge: .left, verticalPercent: 1.0)
        XCTAssertEqual(vis1.origin.y, 25.0 + 1055.0 - 320.0)

        // 3. verticalPercent = -0.5 (下溢 clamp 到 0.0)
        let (visUnderflow, _) = calculator.calculateWindowFrames(screen: screen, edge: .left, verticalPercent: -0.5)
        XCTAssertEqual(visUnderflow.origin.y, 25.0)

        // 4. verticalPercent = 1.5 (上溢 clamp 到 1.0)
        let (visOverflow, _) = calculator.calculateWindowFrames(screen: screen, edge: .left, verticalPercent: 1.5)
        XCTAssertEqual(visOverflow.origin.y, 25.0 + 1055.0 - 320.0)
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

    // MARK: - Interactive Dragging & Snapping Tests

    func test_clampFrameToVisibleBounds_withinBounds_returnsUnchanged() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        let frame = CGRect(x: 100, y: 200, width: 140, height: 320)
        let clamped = calculator.clampFrameToVisibleBounds(frame, screen: screen)

        XCTAssertEqual(clamped, frame)
    }

    func test_clampFrameToVisibleBounds_exceedsTopBottomLeftRight_clampsStrictly() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055) // maxY = 1080
        )

        // 1. 下边界溢出（进入 Dock / 负坐标）
        let bottomFrame = CGRect(x: 100, y: 0, width: 140, height: 320)
        let clampedBottom = calculator.clampFrameToVisibleBounds(bottomFrame, screen: screen)
        XCTAssertEqual(clampedBottom.origin.y, 25.0)

        // 2. 上边界溢出（进入 Menu Bar）
        let topFrame = CGRect(x: 100, y: 900, width: 140, height: 320) // maxY = 1220 > 1080
        let clampedTop = calculator.clampFrameToVisibleBounds(topFrame, screen: screen)
        XCTAssertEqual(clampedTop.origin.y, 1080.0 - 320.0)

        // 3. 左边界溢出
        let leftFrame = CGRect(x: -50, y: 300, width: 140, height: 320)
        let clampedLeft = calculator.clampFrameToVisibleBounds(leftFrame, screen: screen)
        XCTAssertEqual(clampedLeft.origin.x, 0.0)

        // 4. 右边界溢出
        let rightFrame = CGRect(x: 1900, y: 300, width: 140, height: 320)
        let clampedRight = calculator.clampFrameToVisibleBounds(rightFrame, screen: screen)
        XCTAssertEqual(clampedRight.origin.x, 1920.0 - 140.0)
    }

    func test_determineEdge_leftAndRightHalves() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        // 屏幕中心 X = 960
        // 1. 左半屏 (midX < 960)
        let leftPanel = CGRect(x: 100, y: 300, width: 140, height: 320) // midX = 170
        XCTAssertEqual(calculator.determineEdge(for: leftPanel, in: screen), .left)

        // 2. 右半屏 (midX >= 960)
        let rightPanel = CGRect(x: 1500, y: 300, width: 140, height: 320) // midX = 1570
        XCTAssertEqual(calculator.determineEdge(for: rightPanel, in: screen), .right)

        // 3. 刚好在中心左侧与右侧
        let justLeft = CGRect(x: 960 - 140, y: 300, width: 140, height: 320) // midX = 890
        XCTAssertEqual(calculator.determineEdge(for: justLeft, in: screen), .left)

        let justRight = CGRect(x: 960, y: 300, width: 140, height: 320) // midX = 1030
        XCTAssertEqual(calculator.determineEdge(for: justRight, in: screen), .right)
    }

    func test_calculateVerticalPercent_variousPositions() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        // availableHeight = 1055 - 320 = 735
        // 1. 底部 (y = 25)
        let bottom = CGRect(x: 100, y: 25, width: 140, height: 320)
        XCTAssertEqual(calculator.calculateVerticalPercent(for: bottom, in: screen), 0.0)

        // 2. 顶部 (y = 25 + 735 = 760)
        let top = CGRect(x: 100, y: 760, width: 140, height: 320)
        XCTAssertEqual(calculator.calculateVerticalPercent(for: top, in: screen), 1.0)

        // 3. 居中 (y = 25 + 367.5 = 392.5)
        let mid = CGRect(x: 100, y: 392.5, width: 140, height: 320)
        XCTAssertEqual(calculator.calculateVerticalPercent(for: mid, in: screen), 0.5)

        // 4. 超出边界 clamp
        let underflow = CGRect(x: 100, y: -50, width: 140, height: 320)
        XCTAssertEqual(calculator.calculateVerticalPercent(for: underflow, in: screen), 0.0)

        let overflow = CGRect(x: 100, y: 900, width: 140, height: 320)
        XCTAssertEqual(calculator.calculateVerticalPercent(for: overflow, in: screen), 1.0)
    }

    func test_calculateSnappedPosition_leftAndRightSnapping() {
        let screen = ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )

        // 1. 拖拽到左半屏中上位置
        let leftDragged = CGRect(x: 300, y: 760, width: 140, height: 320)
        let leftResult = calculator.calculateSnappedPosition(currentFrame: leftDragged, screen: screen)

        XCTAssertEqual(leftResult.edge, .left)
        XCTAssertEqual(leftResult.verticalPercent, 1.0)
        XCTAssertEqual(leftResult.snappedFrame.origin.x, 8.0) // minX + edgeMargin
        XCTAssertEqual(leftResult.snappedFrame.origin.y, 760.0)

        // 2. 拖拽到右半屏中间位置
        let rightDragged = CGRect(x: 1200, y: 392.5, width: 140, height: 320)
        let rightResult = calculator.calculateSnappedPosition(currentFrame: rightDragged, screen: screen)

        XCTAssertEqual(rightResult.edge, .right)
        XCTAssertEqual(rightResult.verticalPercent, 0.5)
        XCTAssertEqual(rightResult.snappedFrame.origin.x, 1920 - 140 - 8.0) // maxX - width - edgeMargin
        XCTAssertEqual(rightResult.snappedFrame.origin.y, 392.5)
    }
}

