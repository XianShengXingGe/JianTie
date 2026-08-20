//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import CoreGraphics

/// 边缘停留与判定上下文，聚合多屏、停靠边缘、垂直比例与拖拽状态
public struct EdgeDwellContext: Sendable, Equatable {
    public var screens: [ScreenInfo]
    public var edge: ShelfEdge
    public var verticalPercent: CGFloat
    public var isFinderDrag: Bool
    public var isShelfRevealed: Bool

    public init(
        screens: [ScreenInfo] = ScreenInfo.currentScreens(),
        edge: ShelfEdge = .left,
        verticalPercent: CGFloat = 0.5,
        isFinderDrag: Bool = false,
        isShelfRevealed: Bool = false
    ) {
        self.screens = screens
        self.edge = edge
        self.verticalPercent = verticalPercent
        self.isFinderDrag = isFinderDrag
        self.isShelfRevealed = isShelfRevealed
    }
}
