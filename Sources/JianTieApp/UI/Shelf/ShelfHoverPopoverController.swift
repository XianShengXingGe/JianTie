//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

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
    private var lastCardScreenFrame: CGRect?
    private var lastShelfWindowFrame: CGRect?

    public init(coordinator: ShelfHoverPopoverCoordinator? = nil) {
        let actualCoordinator = coordinator ?? ShelfHoverPopoverCoordinator.shared
        self.coordinator = actualCoordinator
        super.init()

        actualCoordinator.onShowPopover = { [weak self] stack, cardScreenFrame, shelfWindowFrame, screen, edge in
            self?.showPopover(
                for: stack,
                cardScreenFrame: cardScreenFrame,
                shelfWindowFrame: shelfWindowFrame,
                screen: screen,
                edge: edge
            )
        }

        actualCoordinator.onHidePopover = { [weak self] animated in
            self?.performWindowHide(animated: animated)
        }

        actualCoordinator.isMousePhysicallyInside = { [weak self] in
            guard let self = self else { return false }
            guard self.coordinator.isShelfVisibleProvider?() != false else { return false }
            let mousePos = NSEvent.mouseLocation
            return self.coordinator.isInsideSafeZone(point: mousePos)
        }
    }

    // MARK: - Hover Trigger & Debounce Forwarding

    public func notifyMouseEnteredCard(
        stack: ShelfStack,
        cardScreenFrame: CGRect,
        shelfWindowFrame: CGRect? = nil,
        screen: ScreenInfo,
        edge: ShelfEdge,
        delay: TimeInterval = 0.300
    ) {
        self.lastCardScreenFrame = cardScreenFrame
        self.lastShelfWindowFrame = shelfWindowFrame
        coordinator.notifyMouseEnteredCard(
            stack: stack,
            cardScreenFrame: cardScreenFrame,
            shelfWindowFrame: shelfWindowFrame,
            screen: screen,
            edge: edge,
            delay: delay
        )
    }

    public func notifyMouseExitedCard(stack: ShelfStack? = nil) {
        coordinator.notifyMouseExitedCard(stack: stack)
    }

    public func notifyMouseEnteredPopover() {
        coordinator.notifyMouseEnteredPopover()
    }

    public func notifyMouseExitedPopover() {
        coordinator.notifyMouseExitedPopover()
    }

    public func notifyDragStarted() {
        self.lastCardScreenFrame = nil
        self.lastShelfWindowFrame = nil
        coordinator.notifyDragStarted()
    }

    public func notifyDragEnded() {
        coordinator.notifyDragEnded()
    }

    public func cancelPendingShow() {
        self.lastCardScreenFrame = nil
        self.lastShelfWindowFrame = nil
        coordinator.cancelPendingShow()
    }

    public func hidePopover(animated: Bool = false) {
        self.lastCardScreenFrame = nil
        self.lastShelfWindowFrame = nil
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
        shelfWindowFrame: CGRect? = nil,
        screen: ScreenInfo,
        edge: ShelfEdge
    ) {
        guard coordinator.isShelfVisibleProvider?() != false else {
            hidePopover(animated: false)
            return
        }

        self.lastCardScreenFrame = cardScreenFrame
        self.lastShelfWindowFrame = shelfWindowFrame
        let popoverSize = calculatePopoverSize(for: stack)
        let targetFrame = geometryCalculator.calculatePopoverFrame(
            cardScreenFrame: cardScreenFrame,
            shelfWindowFrame: shelfWindowFrame,
            popoverSize: popoverSize,
            screen: screen,
            edge: edge,
            spacing: 10.0
        )
        coordinator.notifyPopoverFrameCalculated(popoverFrame: targetFrame)

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
        self.lastCardScreenFrame = nil
        self.lastShelfWindowFrame = nil

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
        let width: CGFloat = 280.0
        // 头部高度(24) + 底部提示(22) + 两条分割线(2) + 上下边距与间距(42) = 90
        let baseOverhead: CGFloat = 90.0

        let visibleItems = Array(stack.files.prefix(5))
        var totalListHeight: CGFloat = 0

        for (index, file) in visibleItems.enumerated() {
            // 长文件名自动折行预留更多高度（56px），单行预留 46px
            let isLongName = file.fileName.count > 18
            let rowHeight: CGFloat = isLongName ? 56.0 : 46.0
            totalListHeight += rowHeight
            if index > 0 {
                totalListHeight += 6.0 // 项间距
            }
        }

        let computedHeight = baseOverhead + totalListHeight + 4.0
        let clampedHeight = min(max(computedHeight, 140.0), 380.0)
        return CGSize(width: width, height: clampedHeight)
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
