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

        // 若当前未展示，先定位到屏幕边缘起始隐藏位置并设为透明
        if !window.isVisible {
            window.alphaValue = 0.0
            window.setFrame(hiddenFrame, display: false)
            window.orderFront(nil)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18 // 180ms 滑入
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
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
