//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

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
    ///   - verticalPercent: Shelf 垂直停靠比例 (0.0 ~ 1.0，默认 0.5)
    ///   - isFinderDrag: 是否为 Finder 文件拖拽操作（拖拽时全屏幕边缘有效，悬停停留时仅限 Shelf 垂直范围 ±20px）
    ///   - tolerance: 悬停触发的垂直高度容错边距（默认 20.0px）
    /// - Returns: 是否在边缘判定区内
    public func isPointInEdgeTriggerZone(
        point: CGPoint,
        screen: ScreenInfo,
        edge: ShelfEdge,
        verticalPercent: CGFloat = 0.5,
        isFinderDrag: Bool = false,
        tolerance: CGFloat = 20.0
    ) -> Bool {
        let frame = screen.frame

        // 1. 水平 X 轴边缘判定
        let isXInEdge: Bool
        switch edge {
        case .left:
            isXInEdge = point.x >= frame.minX - 1.0 && point.x <= frame.minX + edgeTriggerThreshold
        case .right:
            isXInEdge = point.x >= frame.maxX - edgeTriggerThreshold && point.x <= frame.maxX + 1.0
        }
        guard isXInEdge else { return false }

        // 2. 垂直 Y 轴限位判定
        if isFinderDrag {
            // Finder 文件拖拽：全屏边缘高度均可轻松触发
            return point.y >= frame.minY && point.y <= frame.maxY
        } else {
            // 鼠标边缘悬停：严格限位在 Shelf 实际高度区域 ± 20px
            let targetY = calculateTargetY(visibleBounds: screen.visibleFrame, verticalPercent: verticalPercent)
            let minY = targetY - tolerance
            let maxY = targetY + windowSize.height + tolerance
            return point.y >= minY && point.y <= maxY
        }
    }

    /// 计算 Shelf 窗口的目标可见坐标与屏幕边界收回隐藏坐标
    /// - Parameters:
    ///   - screen: 目标屏幕
    ///   - edge: 停靠边缘
    ///   - verticalPercent: Shelf 垂直停靠比例 (0.0 ~ 1.0，默认 0.5)
    /// - Returns: (visibleFrame: 滑入后的最终展示位置, hiddenFrame: 缩回/滑入起始位置，严格限制在当前屏幕边界内以防多屏溢出)
    public func calculateWindowFrames(
        screen: ScreenInfo,
        edge: ShelfEdge,
        verticalPercent: CGFloat = 0.5
    ) -> (visibleFrame: CGRect, hiddenFrame: CGRect) {
        let visibleBounds = screen.visibleFrame
        let targetY = calculateTargetY(visibleBounds: visibleBounds, verticalPercent: verticalPercent)

        switch edge {
        case .left:
            let visibleX = visibleBounds.minX + edgeMargin
            let hiddenX = max(screen.frame.minX, visibleX - 16)
            let visible = CGRect(x: visibleX, y: targetY, width: windowSize.width, height: windowSize.height)
            let hidden = CGRect(x: hiddenX, y: targetY, width: windowSize.width, height: windowSize.height)
            return (visible, hidden)

        case .right:
            let visibleX = visibleBounds.maxX - windowSize.width - edgeMargin
            let hiddenX = min(screen.frame.maxX - windowSize.width, visibleX + 16)
            let visible = CGRect(x: visibleX, y: targetY, width: windowSize.width, height: windowSize.height)
            let hidden = CGRect(x: hiddenX, y: targetY, width: windowSize.width, height: windowSize.height)
            return (visible, hidden)
        }
    }

    private func calculateTargetY(visibleBounds: CGRect, verticalPercent: CGFloat) -> CGFloat {
        let clampedPercent = min(max(verticalPercent, 0.0), 1.0)
        let availableHeight = max(0, visibleBounds.height - windowSize.height)
        return visibleBounds.minY + availableHeight * clampedPercent
    }

    /// 计算 Shelf 悬浮卡片对应的富信息浮层屏幕坐标
    /// - Parameters:
    ///   - cardScreenFrame: 卡片在屏幕坐标系中的 NSRect
    ///   - popoverSize: 浮层尺寸
    ///   - screen: 显示器信息
    ///   - edge: Shelf 停靠边缘
    ///   - spacing: 浮层与卡片间距（默认 8px）
    /// - Returns: 浮层在屏幕坐标系中的目标 Frame (自动 clamp 到 screen.visibleFrame 内)
    public func calculatePopoverFrame(
        cardScreenFrame: CGRect,
        popoverSize: CGSize,
        screen: ScreenInfo,
        edge: ShelfEdge,
        spacing: CGFloat = 8.0
    ) -> CGRect {
        let visibleBounds = screen.visibleFrame

        // 水平方向：依据边缘智能锚定展开方向
        let targetX: CGFloat
        switch edge {
        case .left:
            targetX = cardScreenFrame.maxX + spacing
        case .right:
            targetX = cardScreenFrame.minX - popoverSize.width - spacing
        }

        // 垂直方向：以卡片纵向中线为基准居中
        let targetY = cardScreenFrame.midY - popoverSize.height / 2

        // 智能边界保护：确保浮层完整落在屏幕可视工作区 (visibleFrame) 内
        let minX = visibleBounds.minX + spacing
        let maxX = max(minX, visibleBounds.maxX - popoverSize.width - spacing)
        let clampedX = min(max(targetX, minX), maxX)

        let minY = visibleBounds.minY + spacing
        let maxY = max(minY, visibleBounds.maxY - popoverSize.height - spacing)
        let clampedY = min(max(targetY, minY), maxY)

        return CGRect(x: clampedX, y: clampedY, width: popoverSize.width, height: popoverSize.height)
    }

    /// 限制 Shelf 窗口在拖拽过程中严格处于屏幕的安全可视区域 (visibleFrame) 内，防止与 Menu Bar 和 Dock 产生遮挡或穿透
    /// - Parameters:
    ///   - frame: 当前待限制的 Shelf Frame
    ///   - screen: 当前所在的屏幕信息
    /// - Returns: 限制在 visibleFrame 内部的有效 Frame
    public func clampFrameToVisibleBounds(_ frame: CGRect, screen: ScreenInfo) -> CGRect {
        let visibleBounds = screen.visibleFrame
        let minX = visibleBounds.minX
        let maxX = max(minX, visibleBounds.maxX - frame.width)
        let clampedX = min(max(frame.origin.x, minX), maxX)

        let minY = visibleBounds.minY
        let maxY = max(minY, visibleBounds.maxY - frame.height)
        let clampedY = min(max(frame.origin.y, minY), maxY)

        return CGRect(x: clampedX, y: clampedY, width: frame.width, height: frame.height)
    }

    /// 依据 Shelf 面板所在的横向屏幕中线划分，判断所属的目标贴边边缘
    /// - Parameters:
    ///   - frame: Shelf 面板当前 Frame
    ///   - screen: 当前所在的屏幕信息
    /// - Returns: 所属边缘 (.left / .right)
    public func determineEdge(for frame: CGRect, in screen: ScreenInfo) -> ShelfEdge {
        return frame.midX < screen.frame.midX ? .left : .right
    }

    /// 计算 Shelf 面板在当前屏幕可视区域内的归一化垂直比例 (0.0 ~ 1.0)
    /// - Parameters:
    ///   - frame: Shelf 面板当前 Frame
    ///   - screen: 当前所在的屏幕信息
    /// - Returns: 归一化垂直比例 (0.0 表示底部贴紧 visibleFrame.minY，1.0 表示顶部贴紧 visibleFrame.maxY)
    public func calculateVerticalPercent(for frame: CGRect, in screen: ScreenInfo) -> CGFloat {
        let visibleBounds = screen.visibleFrame
        let availableHeight = max(0, visibleBounds.height - windowSize.height)
        guard availableHeight > 0 else { return 0.5 }

        let relativeY = frame.minY - visibleBounds.minY
        let percent = relativeY / availableHeight
        return min(max(percent, 0.0), 1.0)
    }

    /// 根据拖拽释放时的位置，计算吸附的目标边缘、归一化垂直比例与最终吸附可见 Frame
    /// - Parameters:
    ///   - currentFrame: 释放时的 Shelf Frame
    ///   - screen: 当前所在的屏幕信息
    /// - Returns: (edge: 目标吸附边缘, verticalPercent: 垂直比例, snappedFrame: 吸附后展示的完整 Frame)
    public func calculateSnappedPosition(
        currentFrame: CGRect,
        screen: ScreenInfo
    ) -> (edge: ShelfEdge, verticalPercent: CGFloat, snappedFrame: CGRect) {
        let clamped = clampFrameToVisibleBounds(currentFrame, screen: screen)
        let edge = determineEdge(for: clamped, in: screen)
        let verticalPercent = calculateVerticalPercent(for: clamped, in: screen)
        let (visibleFrame, _) = calculateWindowFrames(
            screen: screen,
            edge: edge,
            verticalPercent: verticalPercent
        )
        return (edge: edge, verticalPercent: verticalPercent, snappedFrame: visibleFrame)
    }

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return sqrt(dx * dx + dy * dy)
    }
}
