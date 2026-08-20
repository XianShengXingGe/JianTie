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

    private func setupContentView(window: ShelfPanelWindow) {
        let rootView = ShelfPanelView(engine: engine)
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
            // 底部 0~46 为 Copy Path，46~86 为 AirDrop
            if location.y >= 0 && location.y < 46 {
                self.engine.handleCopyPath(urls: urls)
                return true
            } else if location.y >= 46 && location.y < 86 {
                self.engine.handleAirDrop(urls: urls)
                return true
            }
            return false
        }

        hostView.onDropFiles = { [weak self] urls in
            self?.engine.dropFiles(urls)
        }

        window.contentView = hostView
    }

    private func bindEngine() {
        engine.onRequestReveal = { [weak self] visibleFrame, hiddenFrame, isDragging in
            self?.revealWithAnimation(visibleFrame: visibleFrame, hiddenFrame: hiddenFrame)
        }

        engine.onRequestHide = { [weak self] hiddenFrame in
            self?.hideWithAnimation(hiddenFrame: hiddenFrame)
        }
    }

    /// 执行 180ms ease-out 平滑滑入动效
    public func revealWithAnimation(visibleFrame: CGRect, hiddenFrame: CGRect) {
        guard let window = self.window else { return }

        // 若当前未展示，先定位到屏幕边缘外隐藏位置
        if !window.isVisible {
            window.setFrame(hiddenFrame, display: false)
            window.orderFront(nil)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18 // 180ms 滑入
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(visibleFrame, display: true)
        }
    }

    /// 执行 220ms ease-in 平滑收起隐藏动效
    public func hideWithAnimation(hiddenFrame: CGRect) {
        guard let window = self.window, window.isVisible else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22 // 220ms 滑出
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(hiddenFrame, display: true)
        }, completionHandler: { [weak self] in
            guard let self = self, !self.engine.state.isVisible else { return }
            self.window?.orderOut(nil)
        })
    }
}
