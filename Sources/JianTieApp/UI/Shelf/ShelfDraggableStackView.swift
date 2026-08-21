//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import SwiftUI
import AppKit
import JianTieCore

/// 封装 NSDraggingSource 协议的 AppKit 容器 View，支持将 Stack 完整拖出到外部并精确监听 Drop 结果与悬停富信息浮层
public final class ShelfStackDragHostingView: NSView, NSDraggingSource {
    public var stack: ShelfStack
    public var edge: ShelfEdge
    public var isDragging: Bool = false
    public var onDragStart: (() -> Void)?
    public var onDragOutEnded: ((Bool) -> Void)?
    public var onDiscard: (() -> Void)?

    private var trackingArea: NSTrackingArea?
    private var initialMouseDownLocation: NSPoint?
    private var isDraggingSessionActive = false
    private var isHovered: Bool = false
    private var hostingView: NSHostingView<ShelfStackCardView>?

    public init(
        stack: ShelfStack,
        edge: ShelfEdge,
        isDragging: Bool = false,
        onDragStart: (() -> Void)? = nil,
        onDiscard: @escaping () -> Void,
        onDragOutEnded: @escaping (Bool) -> Void
    ) {
        self.stack = stack
        self.edge = edge
        self.isDragging = isDragging
        self.onDragStart = onDragStart
        self.onDiscard = onDiscard
        self.onDragOutEnded = onDragOutEnded
        super.init(frame: .zero)

        setupContentView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        return self
    }

    public func update(
        stack: ShelfStack,
        edge: ShelfEdge,
        isDragging: Bool,
        onDragStart: (() -> Void)?,
        onDiscard: @escaping () -> Void,
        onDragOutEnded: @escaping (Bool) -> Void
    ) {
        self.stack = stack
        self.edge = edge
        self.isDragging = isDragging
        self.onDragStart = onDragStart
        self.onDiscard = onDiscard
        self.onDragOutEnded = onDragOutEnded

        self.hostingView?.rootView = makeCardView()
    }

    private func setupContentView() {
        let cardView = makeCardView()
        let host = NSHostingView(rootView: cardView)
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)

        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor),
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        self.hostingView = host
    }

    private func makeCardView() -> ShelfStackCardView {
        ShelfStackCardView(
            stack: stack,
            isHovered: isHovered,
            isDragging: isDragging || isDraggingSessionActive,
            onDiscard: { [weak self] in
                ShelfHoverPopoverController.shared.hidePopover(animated: false)
                ShelfQuickLookController.shared.closePreview()
                self?.onDiscard?()
            }
        )
    }

    // MARK: - Tracking Area & Hover

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect, .assumeInside]
        let newArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(newArea)
        self.trackingArea = newArea
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            if let tracking = trackingArea {
                removeTrackingArea(tracking)
                self.trackingArea = nil
            }
            self.isHovered = false
            ShelfHoverPopoverController.shared.notifyMouseExitedCard(stack: stack)
        }
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        self.isHovered = true
        self.hostingView?.rootView = makeCardView()
        handleMousePositionUpdate()
    }

    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        if !self.isHovered {
            self.isHovered = true
            self.hostingView?.rootView = makeCardView()
        }
        handleMousePositionUpdate()
    }

    private func handleMousePositionUpdate() {
        guard !isDraggingSessionActive, !isDragging else { return }
        guard NSEvent.pressedMouseButtons == 0 else { return }
        guard let win = self.window, win.isVisible else { return }

        let screenRect = win.convertToScreen(convert(bounds, to: nil))
        let shelfWindowFrame = win.frame
        let screen = win.screen.map { ScreenInfo(screen: $0) }
            ?? ScreenInfo.currentScreens().first
            ?? ScreenInfo(frame: .zero, visibleFrame: .zero)

        ShelfHoverPopoverController.shared.notifyMouseEnteredCard(
            stack: stack,
            cardScreenFrame: screenRect,
            shelfWindowFrame: shelfWindowFrame,
            screen: screen,
            edge: edge
        )
        ShelfQuickLookController.shared.startHoverKeyMonitoring { [weak self] in
            self?.stack.resolvedURLs ?? []
        }
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        self.isHovered = false
        self.hostingView?.rootView = makeCardView()
        ShelfHoverPopoverController.shared.notifyMouseExitedCard(stack: stack)
        if !ShelfHoverPopoverController.shared.isPopoverVisible {
            ShelfQuickLookController.shared.stopHoverKeyMonitoring(closePreviewIfOpen: false)
        }
    }

    // MARK: - Mouse & Drag Session

    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // 检查是否点击了左上角 ✕ 丢弃按钮
        if isHovered && !isDragging && !isDraggingSessionActive && isPointInDiscardButton(point) {
            ShelfHoverPopoverController.shared.hidePopover(animated: false)
            ShelfQuickLookController.shared.closePreview()
            onDiscard?()
            return
        }

        self.initialMouseDownLocation = point
    }

    public override func mouseUp(with event: NSEvent) {
        self.initialMouseDownLocation = nil
        super.mouseUp(with: event)
    }

    private func isPointInDiscardButton(_ point: NSPoint) -> Bool {
        // Cocoa 坐标系（原点在左下角），丢弃按钮在左上角 (padding 3, 尺寸 24~30)
        let discardRect = NSRect(x: 0, y: max(0, bounds.height - 32), width: 32, height: 32)
        return discardRect.contains(point)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard !isDraggingSessionActive, let initialPoint = initialMouseDownLocation else {
            return
        }

        let currentPoint = convert(event.locationInWindow, from: nil)
        let dx = currentPoint.x - initialPoint.x
        let dy = currentPoint.y - initialPoint.y
        let distance = sqrt(dx * dx + dy * dy)

        // 超过拖拽最小阈值（4px）启动系统拖拽会话
        if distance > 4 {
            startDragSession(with: event)
        }
    }

    private func startDragSession(with event: NSEvent) {
        let validURLs = stack.resolvedURLs
        guard !validURLs.isEmpty else { return }

        ShelfHoverPopoverController.shared.notifyDragStarted()
        ShelfQuickLookController.shared.stopHoverKeyMonitoring(closePreviewIfOpen: true)

        self.isDraggingSessionActive = true
        self.hostingView?.rootView = makeCardView()
        onDragStart?()

        let mousePos = convert(event.locationInWindow, from: nil)
        let draggingItems: [NSDraggingItem] = validURLs.map { url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            item.setDraggingFrame(NSRect(x: mousePos.x - 16, y: mousePos.y - 16, width: 32, height: 32), contents: icon)
            return item
        }

        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    // MARK: - NSDraggingSource

    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .every
    }

    public func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        self.isDraggingSessionActive = false
        self.initialMouseDownLocation = nil
        self.hostingView?.rootView = makeCardView()
        ShelfHoverPopoverController.shared.notifyDragEnded()

        // 若 operation 不为空（且不是 none），代表外部 App 或 Finder 成功接收并消费了 Drop
        let success = (operation != [])
        onDragOutEnded?(success)
    }
}

/// SwiftUI 包装器，将 ShelfStackDragHostingView 桥接至 SwiftUI
public struct ShelfDraggableStackView: NSViewRepresentable {
    public let stack: ShelfStack
    public let edge: ShelfEdge
    public let isDragging: Bool
    public let onDragStart: (() -> Void)?
    public let onDiscard: () -> Void
    public let onDragOutEnded: (Bool) -> Void

    public init(
        stack: ShelfStack,
        edge: ShelfEdge,
        isDragging: Bool = false,
        onDragStart: (() -> Void)? = nil,
        onDiscard: @escaping () -> Void,
        onDragOutEnded: @escaping (Bool) -> Void
    ) {
        self.stack = stack
        self.edge = edge
        self.isDragging = isDragging
        self.onDragStart = onDragStart
        self.onDiscard = onDiscard
        self.onDragOutEnded = onDragOutEnded
    }

    public func makeNSView(context: Context) -> ShelfStackDragHostingView {
        return ShelfStackDragHostingView(
            stack: stack,
            edge: edge,
            isDragging: isDragging,
            onDragStart: onDragStart,
            onDiscard: onDiscard,
            onDragOutEnded: onDragOutEnded
        )
    }

    public func updateNSView(_ nsView: ShelfStackDragHostingView, context: Context) {
        nsView.update(
            stack: stack,
            edge: edge,
            isDragging: isDragging,
            onDragStart: onDragStart,
            onDiscard: onDiscard,
            onDragOutEnded: onDragOutEnded
        )
    }
}
