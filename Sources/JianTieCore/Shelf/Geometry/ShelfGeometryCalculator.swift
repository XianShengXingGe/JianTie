import Foundation
import CoreGraphics
import AppKit

/// 屏幕几何描述结构体，解耦具体 NSScreen 对象以支持纯逻辑单元测试
public struct ScreenInfo: Equatable, Sendable {
    public let frame: CGRect
    public let visibleFrame: CGRect

    public init(frame: CGRect, visibleFrame: CGRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }

    public init(screen: NSScreen) {
        self.frame = screen.frame
        self.visibleFrame = screen.visibleFrame
    }

    public static func currentScreens() -> [ScreenInfo] {
        return NSScreen.screens.map { ScreenInfo(screen: $0) }
    }
}

/// 多屏几何与 Shelf 窗口坐标计算器
public struct ShelfGeometryCalculator: Sendable {
    public let edgeTriggerThreshold: CGFloat
    public let windowSize: CGSize
    public let edgeMargin: CGFloat

    public init(
        edgeTriggerThreshold: CGFloat = 3.0,
        windowSize: CGSize = CGSize(width: 140, height: 320),
        edgeMargin: CGFloat = 8.0
    ) {
        self.edgeTriggerThreshold = edgeTriggerThreshold
        self.windowSize = windowSize
        self.edgeMargin = edgeMargin
    }

    /// 在给定的屏幕列表中查找鼠标当前所在的屏幕
    /// - Parameters:
    ///   - point: 鼠标绝对坐标 (Cocoa 坐标系，原点在主屏左下角)
    ///   - screens: 当前所有显示器信息
    /// - Returns: 鼠标所在的屏幕信息（若在缝隙处则返回最近的屏幕）
    public func findScreen(for point: CGPoint, in screens: [ScreenInfo]) -> ScreenInfo? {
        guard !screens.isEmpty else { return nil }

        // 1. 精确包含判定
        if let containingScreen = screens.first(where: { $0.frame.contains(point) }) {
            return containingScreen
        }

        // 2. 距离最近容错（如多屏交界处或边缘微小溢出）
        return screens.min(by: { screen1, screen2 in
            distance(from: point, to: screen1.frame) < distance(from: point, to: screen2.frame)
        })
    }

    /// 判定鼠标是否停靠在指定屏幕的触发边缘判定区内
    /// - Parameters:
    ///   - point: 鼠标绝对坐标
    ///   - screen: 目标屏幕
    ///   - edge: 停靠边缘 (左侧 / 右侧)
    /// - Returns: 是否在边缘判定区内
    public func isPointInEdgeTriggerZone(
        point: CGPoint,
        screen: ScreenInfo,
        edge: ShelfEdge
    ) -> Bool {
        let frame = screen.frame
        // Y 轴必须在屏幕高度范围内（允许适度容错）
        guard point.y >= frame.minY && point.y <= frame.maxY else {
            return false
        }

        switch edge {
        case .left:
            return point.x >= frame.minX - 1.0 && point.x <= frame.minX + edgeTriggerThreshold
        case .right:
            return point.x >= frame.maxX - edgeTriggerThreshold && point.x <= frame.maxX + 1.0
        }
    }

    /// 计算 Shelf 窗口的目标可见坐标与屏幕外隐藏坐标
    /// - Parameters:
    ///   - screen: 目标屏幕
    ///   - edge: 停靠边缘
    /// - Returns: (visibleFrame: 滑入后的最终展示位置, hiddenFrame: 滑出屏幕外的初始/隐藏位置)
    public func calculateWindowFrames(
        screen: ScreenInfo,
        edge: ShelfEdge
    ) -> (visibleFrame: CGRect, hiddenFrame: CGRect) {
        let visibleBounds = screen.visibleFrame
        let targetY = visibleBounds.midY - windowSize.height / 2

        switch edge {
        case .left:
            let visibleX = visibleBounds.minX + edgeMargin
            let hiddenX = screen.frame.minX - windowSize.width - 20
            let visible = CGRect(x: visibleX, y: targetY, width: windowSize.width, height: windowSize.height)
            let hidden = CGRect(x: hiddenX, y: targetY, width: windowSize.width, height: windowSize.height)
            return (visible, hidden)

        case .right:
            let visibleX = visibleBounds.maxX - windowSize.width - edgeMargin
            let hiddenX = screen.frame.maxX + 20
            let visible = CGRect(x: visibleX, y: targetY, width: windowSize.width, height: windowSize.height)
            let hidden = CGRect(x: hiddenX, y: targetY, width: windowSize.width, height: windowSize.height)
            return (visible, hidden)
        }
    }

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return sqrt(dx * dx + dy * dy)
    }
}
