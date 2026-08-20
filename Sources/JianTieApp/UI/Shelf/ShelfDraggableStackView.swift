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
            isDragging: isDragging,
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

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let newArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(newArea)
        self.trackingArea = newArea
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard !isDraggingSessionActive, !isDragging else { return }

        guard let win = self.window else { return }
        let screenRect = win.convertToScreen(convert(bounds, to: nil))
        let screen = win.screen.map { ScreenInfo(screen: $0) }
            ?? ScreenInfo.currentScreens().first
            ?? ScreenInfo(frame: .zero, visibleFrame: .zero)

        ShelfHoverPopoverController.shared.notifyMouseEnteredCard(
            stack: stack,
            cardScreenFrame: screenRect,
            screen: screen,
            edge: edge
        )
        ShelfQuickLookController.shared.startHoverKeyMonitoring { [weak self] in
            self?.stack.resolvedURLs ?? []
        }
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        ShelfHoverPopoverController.shared.notifyMouseExitedCard()
        if !ShelfHoverPopoverController.shared.isPopoverVisible {
            ShelfQuickLookController.shared.stopHoverKeyMonitoring(closePreviewIfOpen: false)
        }
    }

    // MARK: - Mouse & Drag Session

    public override func mouseDown(with event: NSEvent) {
        self.initialMouseDownLocation = convert(event.locationInWindow, from: nil)
        super.mouseDown(with: event)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard !isDraggingSessionActive, let initialPoint = initialMouseDownLocation else {
            super.mouseDragged(with: event)
            return
        }

        let currentPoint = convert(event.locationInWindow, from: nil)
        let dx = currentPoint.x - initialPoint.x
        let dy = currentPoint.y - initialPoint.y
        let distance = sqrt(dx * dx + dy * dy)

        // 超过拖拽最小阈值（4px）启动系统拖拽会话
        if distance > 4 {
            startDragSession(with: event)
        } else {
            super.mouseDragged(with: event)
        }
    }

    private func startDragSession(with event: NSEvent) {
        let validURLs = stack.resolvedURLs
        guard !validURLs.isEmpty else { return }

        ShelfHoverPopoverController.shared.notifyDragStarted()
        ShelfQuickLookController.shared.stopHoverKeyMonitoring(closePreviewIfOpen: true)

        self.isDraggingSessionActive = true
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
        return [.copy, .generic]
    }

    public func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        self.isDraggingSessionActive = false
        self.initialMouseDownLocation = nil

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

