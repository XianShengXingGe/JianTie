import Foundation
import CoreGraphics
import AppKit

extension ShelfEngine {
    // MARK: - Lifecycle & State Machine Transitions

    /// 处理 Finder 拖拽开始事件
    public func handleDragStarted(files: [URL], at location: CGPoint) {
        let screens = screensProvider()
        let targetScreen: ScreenInfo
        if let existing = activeScreen, !stacks.isEmpty {
            // 当 Shelf 里已有文件暂存时，维持原屏幕位置，不再跟随鼠标切换屏幕
            targetScreen = existing
        } else {
            guard let screen = geometryCalculator.findScreen(for: location, in: screens) ?? screens.first else {
                return
            }
            targetScreen = screen
            self.activeScreen = screen
        }

        let (visibleFrame, hiddenFrame) = geometryCalculator.calculateWindowFrames(
            screen: targetScreen,
            edge: edge,
            verticalPercent: verticalPercent
        )

        let newState = ShelfState.revealedDragging(screenFrame: targetScreen.frame, edge: edge)
        self.state = newState
        self.onStateChanged?(newState)
        self.onRequestReveal?(visibleFrame, hiddenFrame, true)
    }

    /// 处理拖拽结束事件
    public func handleDragEnded() {
        guard case .revealedDragging = state else { return }

        if !stacks.isEmpty {
            // 如果 Shelf 中已有暂存 Stack，恢复为 Stored 展示状态
            let screenFrame = activeScreen?.frame ?? .zero
            let newState = ShelfState.stored(screenFrame: screenFrame, edge: edge)
            self.state = newState
            self.onStateChanged?(newState)
        } else {
            dismiss()
        }
    }

    /// 处理边缘停留 150ms 触发
    public func handleEdgeDwell(on screen: ScreenInfo) {
        guard state == .hidden else { return }

        self.activeScreen = screen
        let (visibleFrame, hiddenFrame) = geometryCalculator.calculateWindowFrames(
            screen: screen,
            edge: edge,
            verticalPercent: verticalPercent
        )

        let newState: ShelfState
        if stacks.isEmpty {
            newState = .revealedEmpty(screenFrame: screen.frame, edge: edge)
        } else {
            newState = .stored(screenFrame: screen.frame, edge: edge)
        }

        self.state = newState
        self.onStateChanged?(newState)
        self.onRequestReveal?(visibleFrame, hiddenFrame, false)
    }

    /// 处理移出 600ms 自动收回触发
    public func handleAutoRetract() {
        // 仅在空状态悬停展开且无任何 Stack 时自动收回
        guard case .revealedEmpty = state, stacks.isEmpty else { return }

        dismiss()
    }

    /// 鼠标移入 Shelf 区域通知
    public func handleMouseEnteredShelf() {
        edgeMonitor.notifyMouseEnteredShelf()
    }

    /// 鼠标移出 Shelf 区域通知
    public func handleMouseExitedShelf() {
        edgeMonitor.notifyMouseExitedShelf()
    }

    // MARK: - Interactive Panel Dragging & Snapping

    /// 用户开始交互式拖拽 Shelf 面板
    public func notifyPanelDragStarted() {
        self.isPanelDragging = true
    }

    /// 用户拖拽 Shelf 面板移动过程中实时调用，检测是否跨越屏幕中线切换停靠边缘
    public func notifyPanelDragMoved(to frame: CGRect, on screen: ScreenInfo) {
        self.activeScreen = screen
        let targetEdge = geometryCalculator.determineEdge(for: frame, in: screen)
        if self.edge != targetEdge {
            self.edge = targetEdge
        }
    }

    /// 用户结束拖拽释放 Shelf 面板，计算就近吸附边缘与垂直比例，触发吸附动效并持久化
    @discardableResult
    public func notifyPanelDragEnded(
        finalFrame: CGRect,
        on screen: ScreenInfo
    ) -> (edge: ShelfEdge, verticalPercent: CGFloat, snappedFrame: CGRect) {
        self.activeScreen = screen

        let snapped = geometryCalculator.calculateSnappedPosition(currentFrame: finalFrame, screen: screen)
        // 保持 isPanelDragging = true 时更新位置属性，避免 didSet 触发冗余的二次入场动画
        updatePosition(edge: snapped.edge, verticalPercent: snapped.verticalPercent)
        self.isPanelDragging = false

        return snapped
    }

    /// 交互式拖拽吸附更新 Shelf 停靠位置
    public func updatePosition(edge newEdge: ShelfEdge? = nil, verticalPercent newVerticalPercent: CGFloat? = nil) {
        if let newEdge = newEdge {
            self.edge = newEdge
        }
        if let newVerticalPercent = newVerticalPercent {
            self.verticalPercent = newVerticalPercent
        }
    }

    /// 收回并隐藏 Shelf
    public func dismiss() {
        guard state.isVisible else { return }

        let screen = activeScreen ?? screensProvider().first

        if let screen = screen {
            let (_, hiddenFrame) = geometryCalculator.calculateWindowFrames(
                screen: screen,
                edge: edge,
                verticalPercent: verticalPercent
            )
            self.onRequestHide?(hiddenFrame)
        }

        self.state = .hidden
        self.onStateChanged?(.hidden)
        self.activeScreen = nil
    }

    internal func updateRevealedPositionForCurrentEdge() {
        guard state.isVisible, !isPanelDragging else { return }
        let screens = screensProvider()
        let screen = activeScreen ?? screens.first
        guard let screen = screen else { return }

        let (visibleFrame, hiddenFrame) = geometryCalculator.calculateWindowFrames(
            screen: screen,
            edge: edge,
            verticalPercent: verticalPercent
        )
        let isDragging: Bool
        let newState: ShelfState
        switch state {
        case .stored:
            newState = .stored(screenFrame: screen.frame, edge: edge)
            isDragging = false
        case .revealedEmpty:
            newState = .revealedEmpty(screenFrame: screen.frame, edge: edge)
            isDragging = false
        case .revealedDragging:
            newState = .revealedDragging(screenFrame: screen.frame, edge: edge)
            isDragging = true
        case .hidden:
            return
        }

        self.state = newState
        self.onStateChanged?(newState)
        self.onRequestReveal?(visibleFrame, hiddenFrame, isDragging)
    }
}
