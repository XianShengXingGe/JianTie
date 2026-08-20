import Foundation
import CoreGraphics

/// 纯状态机：管理 150ms 边缘停留判定与 600ms 离开自动缩回计时
public final class EdgeDwellDetector: @unchecked Sendable {
    public enum Action: Equatable, Sendable {
        case none
        case reveal(screen: ScreenInfo)
        case retract
    }

    public let dwellThreshold: TimeInterval
    public let retractThreshold: TimeInterval
    public let geometryCalculator: ShelfGeometryCalculator

    private let precisionEpsilon: TimeInterval = 1e-4
    private var dwellStartTime: TimeInterval?
    private var dwellingScreen: ScreenInfo?
    private var retractStartTime: TimeInterval?
    private var isRevealed: Bool = false

    public init(
        dwellThreshold: TimeInterval = 0.15, // 150ms
        retractThreshold: TimeInterval = 0.60, // 600ms
        geometryCalculator: ShelfGeometryCalculator = ShelfGeometryCalculator()
    ) {
        self.dwellThreshold = dwellThreshold
        self.retractThreshold = retractThreshold
        self.geometryCalculator = geometryCalculator
    }

    /// 处理鼠标全局移动事件
    /// - Parameters:
    ///   - point: 当前鼠标坐标
    ///   - timestamp: 当前时间戳（秒）
    ///   - context: 包含显示器列表、停靠边缘、垂直比例与展示状态的上下文
    /// - Returns: 需要执行的动作（如唤出、缩回或无动作）
    public func handleMouseMove(
        point: CGPoint,
        timestamp: TimeInterval,
        context: EdgeDwellContext
    ) -> Action {
        self.isRevealed = context.isShelfRevealed

        guard let screen = geometryCalculator.findScreen(for: point, in: context.screens) else {
            return .none
        }

        let inEdgeZone = geometryCalculator.isPointInEdgeTriggerZone(
            point: point,
            screen: screen,
            edge: context.edge,
            verticalPercent: context.verticalPercent,
            isFinderDrag: context.isFinderDrag
        )

        if context.isShelfRevealed {
            // 处于展示状态：检查是否在边缘判定区内
            if inEdgeZone {
                // 鼠标在边缘区域内，取消自动收回计时
                retractStartTime = nil
                return .none
            } else {
                // 鼠标离开边缘区域
                if retractStartTime == nil {
                    retractStartTime = timestamp
                } else if timestamp - retractStartTime! >= retractThreshold - precisionEpsilon {
                    retractStartTime = nil
                    isRevealed = false
                    return .retract
                }
                return .none
            }
        } else {
            // 处于隐藏状态：检查是否在边缘停留
            if inEdgeZone {
                if let start = dwellStartTime, dwellingScreen == screen {
                    if timestamp - start >= dwellThreshold - precisionEpsilon {
                        // 停留满 150ms，触发唤出
                        dwellStartTime = nil
                        dwellingScreen = nil
                        isRevealed = true
                        return .reveal(screen: screen)
                    }
                } else {
                    // 刚进入边缘判定区
                    dwellStartTime = timestamp
                    dwellingScreen = screen
                }
                return .none
            } else {
                // 移出边缘判定区，取消停留计时
                dwellStartTime = nil
                dwellingScreen = nil
                return .none
            }
        }
    }

    /// 便捷重载：将离散参数包装为 EdgeDwellContext 执行判定
    @discardableResult
    public func handleMouseMove(
        point: CGPoint,
        timestamp: TimeInterval,
        screens: [ScreenInfo] = ScreenInfo.currentScreens(),
        edge: ShelfEdge = .left,
        verticalPercent: CGFloat = 0.5,
        isFinderDrag: Bool = false,
        isShelfRevealed: Bool = false
    ) -> Action {
        let context = EdgeDwellContext(
            screens: screens,
            edge: edge,
            verticalPercent: verticalPercent,
            isFinderDrag: isFinderDrag,
            isShelfRevealed: isShelfRevealed
        )
        return handleMouseMove(point: point, timestamp: timestamp, context: context)
    }

    /// 鼠标移入 Shelf 视图区域
    public func handleMouseEnteredShelf() {
        retractStartTime = nil
    }

    /// 鼠标移出 Shelf 视图区域
    public func handleMouseExitedShelf(timestamp: TimeInterval) {
        if retractStartTime == nil {
            retractStartTime = timestamp
        }
    }

    /// 定时检查（如通过 Timer 驱动判定 600ms 超时）
    public func checkTimer(timestamp: TimeInterval, isShelfRevealed: Bool) -> Action {
        self.isRevealed = isShelfRevealed

        if isShelfRevealed, let start = retractStartTime {
            if timestamp - start >= retractThreshold - precisionEpsilon {
                retractStartTime = nil
                self.isRevealed = false
                return .retract
            }
        }

        if !isShelfRevealed, let start = dwellStartTime, let screen = dwellingScreen {
            if timestamp - start >= dwellThreshold - precisionEpsilon {
                dwellStartTime = nil
                dwellingScreen = nil
                self.isRevealed = true
                return .reveal(screen: screen)
            }
        }

        return .none
    }

    /// 重置所有计时状态
    public func reset() {
        dwellStartTime = nil
        dwellingScreen = nil
        retractStartTime = nil
        isRevealed = false
    }
}
