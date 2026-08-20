import SwiftUI
import AppKit
import JianTieCore

/// 自定义 Shelf 卡片悬停富信息浮层无边框非激活 Window
public final class ShelfHoverPopoverPanel: NSPanel {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

/// Shelf 暂存卡片悬停富信息浮层控制器，管理 150ms 防抖唤出、方向锚定与联动收起
@MainActor
public final class ShelfHoverPopoverController: NSObject, ObservableObject {
    public static let shared = ShelfHoverPopoverController()

    public let coordinator: ShelfHoverPopoverCoordinator
    public var activeStack: ShelfStack? { coordinator.activeStack }
    public var isPopoverVisible: Bool { coordinator.isPopoverVisible }

    private var popoverWindow: ShelfHoverPopoverPanel?
    private let geometryCalculator = ShelfGeometryCalculator()

    public init(coordinator: ShelfHoverPopoverCoordinator? = nil) {
        let actualCoordinator = coordinator ?? ShelfHoverPopoverCoordinator.shared
        self.coordinator = actualCoordinator
        super.init()

        actualCoordinator.onShowPopover = { [weak self] stack, cardScreenFrame, screen, edge in
            self?.showPopover(for: stack, cardScreenFrame: cardScreenFrame, screen: screen, edge: edge)
        }

        actualCoordinator.onHidePopover = { [weak self] animated in
            self?.performWindowHide(animated: animated)
        }
    }

    // MARK: - Hover Trigger & Debounce Forwarding

    public func notifyMouseEnteredCard(
        stack: ShelfStack,
        cardScreenFrame: CGRect,
        screen: ScreenInfo,
        edge: ShelfEdge,
        delay: TimeInterval = 0.150
    ) {
        coordinator.notifyMouseEnteredCard(
            stack: stack,
            cardScreenFrame: cardScreenFrame,
            screen: screen,
            edge: edge,
            delay: delay
        )
    }

    public func notifyMouseExitedCard(gracePeriod: TimeInterval = 0.180) {
        coordinator.notifyMouseExitedCard(gracePeriod: gracePeriod)
    }

    public func notifyMouseEnteredPopover() {
        coordinator.notifyMouseEnteredPopover()
    }

    public func notifyMouseExitedPopover(gracePeriod: TimeInterval = 0.180) {
        coordinator.notifyMouseExitedPopover(gracePeriod: gracePeriod)
    }

    public func notifyDragStarted() {
        coordinator.notifyDragStarted()
    }

    public func cancelPendingShow() {
        coordinator.cancelPendingShow()
    }

    public func hidePopover(animated: Bool = true) {
        if animated {
            coordinator.hideAnimated()
        } else {
            coordinator.hideImmediately()
        }
    }

    // MARK: - Presentation & Window Management

    /// 展示富信息浮层
    public func showPopover(
        for stack: ShelfStack,
        cardScreenFrame: CGRect,
        screen: ScreenInfo,
        edge: ShelfEdge
    ) {
        let popoverSize = calculatePopoverSize(for: stack)
        let targetFrame = geometryCalculator.calculatePopoverFrame(
            cardScreenFrame: cardScreenFrame,
            popoverSize: popoverSize,
            screen: screen,
            edge: edge,
            spacing: 8.0
        )

        let window = getOrCreateWindow(targetFrame: targetFrame)

        let popoverContent = ShelfStackHoverPopoverView(
            stack: stack,
            onPreviewSingleFile: { url in
                ShelfQuickLookController.shared.preview(urls: [url])
            }
        )

        let hostingView = NSHostingView(rootView: popoverContent)
        window.contentView = hostingView

        window.setFrame(targetFrame, display: true)

        if !window.isVisible || window.alphaValue < 0.1 {
            window.alphaValue = 0.0
            window.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                window.animator().alphaValue = 1.0
            }
        } else {
            window.animator().setFrame(targetFrame, display: true)
            window.animator().alphaValue = 1.0
        }
    }

    /// 执行 Window 级别收起并隐藏动效
    private func performWindowHide(animated: Bool) {
        guard let window = popoverWindow, window.isVisible else { return }

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                context.allowsImplicitAnimation = true
                window.animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self, !self.isPopoverVisible else { return }
                    self.popoverWindow?.orderOut(nil)
                }
            })
        } else {
            window.alphaValue = 0.0
            window.orderOut(nil)
        }
    }

    private func calculatePopoverSize(for stack: ShelfStack) -> CGSize {
        let width: CGFloat = 260.0
        let headerHeight: CGFloat = 34.0
        let footerHeight: CGFloat = 32.0
        let itemHeight: CGFloat = 38.0
        let visibleItems = min(stack.files.count, 5)
        let listHeight = CGFloat(visibleItems) * itemHeight + 8.0
        let totalHeight = headerHeight + listHeight + footerHeight
        return CGSize(width: width, height: min(max(totalHeight, 110), 320))
    }

    private func getOrCreateWindow(targetFrame: CGRect) -> ShelfHoverPopoverPanel {
        if let existing = popoverWindow {
            return existing
        }

        let window = ShelfHoverPopoverPanel(
            contentRect: targetFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.popoverWindow = window
        return window
    }
}
