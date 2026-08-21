//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import CoreGraphics
import AppKit

/// Shelf 暂存卡片气泡生命周期状态枚举
public enum ShelfHoverState: Equatable, Sendable {
    case idle
    case hoverPending(stackId: UUID)
    case bubbleActive(stackId: UUID)
    case draggingSuppressed
}

/// Shelf 暂存卡片悬停富信息浮层调度协调器
/// 基于 4 状态确定性状态机 (FSM) 与几何安全区 (Safe Zone) 实现 300ms 防抖唤出、卡片即时切换、0ms 移出销毁与拖拽全局静默
@MainActor
public final class ShelfHoverPopoverCoordinator: ObservableObject {
    public static let shared = ShelfHoverPopoverCoordinator()

    @Published public private(set) var state: ShelfHoverState = .idle
    @Published public private(set) var activeStack: ShelfStack?
    @Published public private(set) var isPopoverVisible: Bool = false
    public private(set) var hoveringStackId: UUID?

    public private(set) var lastCardScreenFrame: CGRect?
    public private(set) var lastPopoverScreenFrame: CGRect?
    public private(set) var isDraggingSuppressed: Bool = false

    private var hoverShowTask: Task<Void, Never>?

    public var onShowPopover: ((_ stack: ShelfStack, _ cardScreenFrame: CGRect, _ shelfWindowFrame: CGRect?, _ screen: ScreenInfo, _ edge: ShelfEdge) -> Void)?
    public var onHidePopover: ((_ animated: Bool) -> Void)?
    public var isMousePhysicallyInside: (@MainActor () -> Bool)?
    public var isShelfVisibleProvider: (@MainActor () -> Bool)?
    public var currentMouseLocationProvider: (@MainActor () -> CGPoint)?

    public init() {}

    // MARK: - Safe Zone Geometry

    /// 计算卡片与浮层窗口之间的连通矩形过渡区
    public static func computeSafeZoneConnector(cardFrame: CGRect, popoverFrame: CGRect) -> CGRect {
        let gapMinX: CGFloat
        let gapMaxX: CGFloat
        if cardFrame.maxX <= popoverFrame.minX {
            gapMinX = cardFrame.maxX
            gapMaxX = popoverFrame.minX
        } else if popoverFrame.maxX <= cardFrame.minX {
            gapMinX = popoverFrame.maxX
            gapMaxX = cardFrame.minX
        } else {
            gapMinX = min(cardFrame.minX, popoverFrame.minX)
            gapMaxX = max(cardFrame.maxX, popoverFrame.maxX)
        }
        let minY = min(cardFrame.minY, popoverFrame.minY)
        let maxY = max(cardFrame.maxY, popoverFrame.maxY)
        return CGRect(x: gapMinX, y: minY, width: max(gapMaxX - gapMinX, 0), height: max(maxY - minY, 0))
    }

    /// 判定指定屏幕坐标是否位于几何安全区内（Card + Popover + Connector）
    public func isInsideSafeZone(point: CGPoint) -> Bool {
        guard let cardFrame = lastCardScreenFrame else { return false }
        if cardFrame.contains(point) {
            return true
        }
        guard let popoverFrame = lastPopoverScreenFrame else {
            return false
        }
        if popoverFrame.contains(point) {
            return true
        }
        let connector = Self.computeSafeZoneConnector(cardFrame: cardFrame, popoverFrame: popoverFrame)
        return connector.contains(point)
    }

    /// 记录当前展示的 Popover 实际屏幕 Frame
    public func notifyPopoverFrameCalculated(popoverFrame: CGRect) {
        self.lastPopoverScreenFrame = popoverFrame
    }

    // MARK: - Mouse Hover & FSM Transitions

    /// 鼠标进入卡片，调度 300ms 防抖唤出
    public func notifyMouseEnteredCard(
        stack: ShelfStack,
        cardScreenFrame: CGRect,
        shelfWindowFrame: CGRect? = nil,
        screen: ScreenInfo,
        edge: ShelfEdge,
        delay: TimeInterval = 0.300
    ) {
        guard !isDraggingSuppressed else { return }
        guard isShelfVisibleProvider?() != false else { return }

        // 若当前已经为同一卡片展示气泡，仅刷新坐标
        if isPopoverVisible && activeStack?.id == stack.id {
            self.lastCardScreenFrame = cardScreenFrame
            return
        }

        // 若之前正在展示另外一个不同卡片的气泡，0ms 立即销毁旧气泡
        if isPopoverVisible && activeStack?.id != stack.id {
            hideImmediately()
        }

        self.lastCardScreenFrame = cardScreenFrame

        // 若当前已经在此卡片的防抖倒计时中，保持已有倒计时运行，避免因鼠标在卡片内移动导致计时器被无限重置
        if hoveringStackId == stack.id && hoverShowTask != nil {
            return
        }

        self.hoveringStackId = stack.id
        self.state = .hoverPending(stackId: stack.id)

        // 调度当前卡片的 300ms 防抖任务
        hoverShowTask?.cancel()
        let targetStackId = stack.id
        hoverShowTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard let self = self,
                  !Task.isCancelled,
                  self.hoveringStackId == targetStackId,
                  !self.isDraggingSuppressed,
                  self.isShelfVisibleProvider?() != false else {
                return
            }

            // 防抖到期时严格校验：鼠标当前物理坐标是否仍在卡片内
            let mousePos = self.currentMouseLocationProvider?() ?? NSEvent.mouseLocation
            let currentCardFrame = self.lastCardScreenFrame ?? cardScreenFrame
            let isInsideCard = currentCardFrame.contains(mousePos) || (self.isMousePhysicallyInside?() == true)
            guard isInsideCard else {
                self.hoveringStackId = nil
                self.state = .idle
                return
            }

            self.activeStack = stack
            self.isPopoverVisible = true
            self.state = .bubbleActive(stackId: stack.id)
            self.onShowPopover?(stack, currentCardFrame, shelfWindowFrame, screen, edge)
        }
    }

    /// 鼠标离开卡片
    public func notifyMouseExitedCard(stack: ShelfStack? = nil) {
        guard !isDraggingSuppressed else { return }

        // 检查鼠标物理位置：若鼠标实际上仍在此卡片内部（例如因 SwiftUI 重新渲染或子视图边界产生的偶发 exit 事件），予以忽略
        let mousePos = currentMouseLocationProvider?() ?? NSEvent.mouseLocation
        let physicallyInsideCard = (lastCardScreenFrame?.contains(mousePos) == true) || (isMousePhysicallyInside?() == true)
        if physicallyInsideCard {
            return
        }

        // 若仍在 300ms 防抖等待阶段，立即取消并重置为 idle
        if let currentTarget = hoveringStackId, stack == nil || currentTarget == stack?.id {
            if !isPopoverVisible {
                cancelPendingShow()
                self.hoveringStackId = nil
                self.state = .idle
                return
            }
        }

        // 若气泡已处于激活展示态，检查鼠标是否仍在安全区（朝气泡移动中）
        if isPopoverVisible {
            let insideSafeZone = isInsideSafeZone(point: mousePos) || (isMousePhysicallyInside?() == true)
            if insideSafeZone {
                // 鼠标处于桥接过渡区或气泡内部，保持开启
                return
            } else {
                // 鼠标移向桌面或离开 Shelf，0ms 立即销毁
                hideImmediately()
            }
        }
    }

    /// 鼠标进入浮层窗口内部
    public func notifyMouseEnteredPopover() {
        guard !isDraggingSuppressed, isShelfVisibleProvider?() != false else {
            hideImmediately()
            return
        }
        if let stack = activeStack {
            self.state = .bubbleActive(stackId: stack.id)
        }
    }

    /// 鼠标离开浮层窗口内部
    public func notifyMouseExitedPopover() {
        guard !isDraggingSuppressed else { return }

        let mousePos = currentMouseLocationProvider?() ?? NSEvent.mouseLocation
        if lastCardScreenFrame?.contains(mousePos) == true {
            // 鼠标回到了原卡片内部，保持气泡
            return
        }

        // 鼠标离开气泡向外，0ms 立即销毁
        hideImmediately()
    }

    // MARK: - Drag Suppression & External Dismissals

    /// 当开始拖拽时（文件外拖 / 外部拖入 / 面板拖动），立即强制销毁气泡并全局静默
    public func notifyDragStarted() {
        self.isDraggingSuppressed = true
        self.state = .draggingSuppressed
        cancelPendingShow()
        hideImmediately()
    }

    /// 当拖拽会话结束时，解除静默状态
    public func notifyDragEnded() {
        self.isDraggingSuppressed = false
        if self.state == .draggingSuppressed {
            self.state = .idle
        }
    }

    /// 当 Shelf 主面板隐藏或收回时，立即强制清除并隐藏气泡
    public func notifyShelfHidden() {
        cancelPendingShow()
        hideImmediately()
    }

    /// 当指定 Stack 被删除或消费时，若正显示该 Stack 的气泡，立即关闭
    public func notifyStackRemoved(id: UUID) {
        if activeStack?.id == id || hoveringStackId == id {
            cancelPendingShow()
            hideImmediately()
        }
    }

    /// 取消所有挂起的延时任务
    public func cancelPendingShow() {
        hoverShowTask?.cancel()
        hoverShowTask = nil
    }

    /// 立即强制隐藏浮层（0ms 立即执行）
    public func hideImmediately() {
        cancelPendingShow()
        guard isPopoverVisible || activeStack != nil || hoveringStackId != nil else { return }
        self.isPopoverVisible = false
        self.activeStack = nil
        self.hoveringStackId = nil
        self.lastCardScreenFrame = nil
        self.lastPopoverScreenFrame = nil
        if !isDraggingSuppressed {
            self.state = .idle
        }
        onHidePopover?(false)
    }

    /// 平滑隐藏浮层
    public func hideAnimated() {
        cancelPendingShow()
        guard isPopoverVisible || activeStack != nil || hoveringStackId != nil else { return }
        self.isPopoverVisible = false
        self.activeStack = nil
        self.hoveringStackId = nil
        self.lastCardScreenFrame = nil
        self.lastPopoverScreenFrame = nil
        if !isDraggingSuppressed {
            self.state = .idle
        }
        onHidePopover?(true)
    }
}
