import SwiftUI
import AppKit
import JianTieCore

/// 自定义 Shelf 浮层 Panel 容器
public final class ShelfPanelWindow: NSPanel {
    public override var canBecomeKey: Bool {
        return false // Shelf 作为非激活辅助面板，不夺取前台焦点
    }

    public override var canBecomeMain: Bool {
        return false
    }
}

/// Shelf 窗口宿主 View，封装 NSDraggingDestination 与鼠标跟踪区域
final class ShelfContainerHostView<Content: View>: NSHostingView<Content> {
    private var trackingArea: NSTrackingArea?
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    var onActionDrop: ((NSPoint, [URL]) -> Bool)?
    var onDropFiles: (([URL]) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let newArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(newArea)
        self.trackingArea = newArea
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
            return false
        }

        let loc = sender.draggingLocation
        if onActionDrop?(loc, urls) == true {
            return true
        }

        onDropFiles?(urls)
        return true
    }
}

/// Shelf 暂存架浮层窗口控制器
@MainActor
public final class ShelfPanelWindowController: NSWindowController, NSWindowDelegate {
    public let engine: ShelfEngine
    private var isAnimating: Bool = false

    public init(engine: ShelfEngine) {
        self.engine = engine

        let defaultSize = engine.geometryCalculator.windowSize
        let window = ShelfPanelWindow(
            contentRect: NSRect(x: -defaultSize.width - 50, y: 100, width: defaultSize.width, height: defaultSize.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isFloatingPanel = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: window)
        window.delegate = self

        setupContentView(window: window)
        bindEngine()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private enum ActionZoneLayout {
        static let copyPathHeightRange: Range<CGFloat> = 0..<46
        static let airDropHeightRange: Range<CGFloat> = 46..<86
    }

    private var dragClickOffset: CGPoint?

    private func setupContentView(window: ShelfPanelWindow) {
        let rootView = ShelfPanelView(
            engine: engine,
            onPanelDragStart: { [weak self] in
                self?.handlePanelDragStarted()
            },
            onPanelDragMove: { [weak self] in
                self?.handlePanelDragMoved()
            },
            onPanelDragEnd: { [weak self] in
                self?.handlePanelDragEnded()
            }
        )
        let hostView = ShelfContainerHostView(rootView: rootView)
        hostView.registerForDraggedTypes([.fileURL])

        hostView.onMouseEntered = { [weak self] in
            self?.engine.handleMouseEnteredShelf()
        }

        hostView.onMouseExited = { [weak self] in
            self?.engine.handleMouseExitedShelf()
        }

        hostView.onActionDrop = { [weak self] location, urls in
            guard let self = self, self.engine.isActionZoneVisible else { return false }
            // Cocoa 坐标系：原点在左下角
            if ActionZoneLayout.copyPathHeightRange.contains(location.y) {
                self.engine.handleCopyPath(urls: urls)
                return true
            } else if ActionZoneLayout.airDropHeightRange.contains(location.y) {
                self.engine.handleAirDrop(urls: urls)
                return true
            }
            return false
        }

        hostView.onDropFiles = { [weak self] urls in
            let screen = self?.window?.screen.map { ScreenInfo(screen: $0) }
            self?.engine.dropFiles(urls, on: screen)
        }

        window.contentView = hostView
    }

    // MARK: - Interactive Panel Dragging & Snapping

    /// 用户开始拖拽 Shelf 面板
    public func handlePanelDragStarted() {
        guard let window = self.window else { return }
        ShelfHoverPopoverController.shared.hidePopover(animated: false)
        ShelfQuickLookController.shared.stopHoverKeyMonitoring(closePreviewIfOpen: true)

        let mouse = NSEvent.mouseLocation
        self.dragClickOffset = CGPoint(x: mouse.x - window.frame.origin.x, y: mouse.y - window.frame.origin.y)
        engine.notifyPanelDragStarted()
    }

    /// 用户拖拽 Shelf 面板移动过程中实时调用，限制在 visibleFrame 内并更新窗口坐标
    public func handlePanelDragMoved() {
        guard let window = self.window, let clickOffset = self.dragClickOffset else { return }
        let mouse = NSEvent.mouseLocation
        let proposedOrigin = CGPoint(x: mouse.x - clickOffset.x, y: mouse.y - clickOffset.y)
        let proposedFrame = CGRect(origin: proposedOrigin, size: window.frame.size)

        let currentScreen = resolveScreen(for: mouse)
        let clampedFrame = engine.geometryCalculator.clampFrameToVisibleBounds(proposedFrame, screen: currentScreen)
        window.setFrameOrigin(clampedFrame.origin)
        engine.notifyPanelDragMoved(to: clampedFrame, on: currentScreen)
    }

    /// 用户结束拖拽释放 Shelf 面板，就近贴边吸附并触发平滑弹性动画
    public func handlePanelDragEnded() {
        guard let window = self.window else { return }
        self.dragClickOffset = nil

        let mouse = NSEvent.mouseLocation
        let currentScreen = resolveScreen(for: mouse)
        let snapped = engine.notifyPanelDragEnded(finalFrame: window.frame, on: currentScreen)
        snapToPositionWithAnimation(to: snapped.snappedFrame)
    }

    /// 执行 320ms spring 弹性吸附动效
    public func snapToPositionWithAnimation(to targetFrame: CGRect) {
        guard let window = self.window else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.15)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(targetFrame, display: true)
        }
    }

    private func resolveScreen(for point: CGPoint) -> ScreenInfo {
        let screens = ScreenInfo.currentScreens()
        return engine.geometryCalculator.findScreen(for: point, in: screens)
            ?? window?.screen.map { ScreenInfo(screen: $0) }
            ?? screens.first
            ?? ScreenInfo(frame: .zero, visibleFrame: .zero)
    }

    private func bindEngine() {
        engine.onRequestReveal = { [weak self] visibleFrame, hiddenFrame, isDragging in
            self?.revealWithAnimation(visibleFrame: visibleFrame, hiddenFrame: hiddenFrame)
        }

        engine.onRequestHide = { [weak self] hiddenFrame in
            self?.hideWithAnimation(hiddenFrame: hiddenFrame)
        }
    }

    /// 执行平滑滑入/展示动效
    public func revealWithAnimation(visibleFrame: CGRect, hiddenFrame: CGRect) {
        guard let window = self.window else { return }

        // 若当前未展示，先定位到屏幕边缘起始隐藏位置并设为透明
        if !window.isVisible {
            window.alphaValue = 0.0
            window.setFrame(hiddenFrame, display: false)
            window.orderFront(nil)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.15)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(visibleFrame, display: true)
            window.animator().alphaValue = 1.0
        }
    }

    /// 执行 220ms ease-in 平滑收起隐藏动效
    public func hideWithAnimation(hiddenFrame: CGRect) {
        ShelfHoverPopoverController.shared.hidePopover(animated: false)
        ShelfQuickLookController.shared.stopHoverKeyMonitoring(closePreviewIfOpen: true)

        guard let window = self.window, window.isVisible else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22 // 220ms 滑出
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(hiddenFrame, display: true)
            window.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, !self.engine.state.isVisible else { return }
                self.window?.orderOut(nil)
                self.window?.alphaValue = 1.0
            }
        })
    }
}
