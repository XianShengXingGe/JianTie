import Foundation
import CoreGraphics

/// Shelf 暂存卡片悬停富信息浮层调度协调器，负责 150ms 悬停防抖触发、移出收起与状态生命周期管理
@MainActor
public final class ShelfHoverPopoverCoordinator: ObservableObject {
    public static let shared = ShelfHoverPopoverCoordinator()

    @Published public private(set) var activeStack: ShelfStack?
    @Published public private(set) var isPopoverVisible: Bool = false

    private var hoverShowTask: Task<Void, Never>?
    private var hoverHideTask: Task<Void, Never>?

    public private(set) var isMouseInCard: Bool = false
    public private(set) var isMouseInPopover: Bool = false

    public var onShowPopover: ((_ stack: ShelfStack, _ cardScreenFrame: CGRect, _ screen: ScreenInfo, _ edge: ShelfEdge) -> Void)?
    public var onHidePopover: ((_ animated: Bool) -> Void)?

    public init() {}

    /// 鼠标进入卡片，调度 150ms 防抖唤出
    public func notifyMouseEnteredCard(
        stack: ShelfStack,
        cardScreenFrame: CGRect,
        screen: ScreenInfo,
        edge: ShelfEdge,
        delay: TimeInterval = 0.150
    ) {
        self.isMouseInCard = true
        hoverHideTask?.cancel()
        hoverHideTask = nil

        if isPopoverVisible && activeStack?.id == stack.id {
            return
        }

        hoverShowTask?.cancel()
        hoverShowTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard let self = self, !Task.isCancelled, self.isMouseInCard else { return }

            self.activeStack = stack
            self.isPopoverVisible = true
            self.onShowPopover?(stack, cardScreenFrame, screen, edge)
        }
    }

    /// 鼠标离开卡片，在缓冲时间后若未进入浮层则平滑淡出收起
    public func notifyMouseExitedCard(gracePeriod: TimeInterval = 0.100) {
        self.isMouseInCard = false
        hoverShowTask?.cancel()
        hoverShowTask = nil

        scheduleHide(gracePeriod: gracePeriod)
    }

    /// 鼠标进入浮层窗口内部
    public func notifyMouseEnteredPopover() {
        self.isMouseInPopover = true
        hoverHideTask?.cancel()
        hoverHideTask = nil
    }

    /// 鼠标离开浮层窗口内部
    public func notifyMouseExitedPopover(gracePeriod: TimeInterval = 0.100) {
        self.isMouseInPopover = false
        scheduleHide(gracePeriod: gracePeriod)
    }

    /// 当开始拖拽（Drag Out / Finder Drag）或 Shelf 收回时，立即取消并隐藏
    public func notifyDragStarted() {
        cancelPendingShow()
        hideImmediately()
    }

    /// 取消所有挂起的延时任务
    public func cancelPendingShow() {
        hoverShowTask?.cancel()
        hoverShowTask = nil
        hoverHideTask?.cancel()
        hoverHideTask = nil
    }

    /// 立即强制隐藏浮层
    public func hideImmediately() {
        cancelPendingShow()
        guard isPopoverVisible || activeStack != nil else { return }
        self.isPopoverVisible = false
        self.activeStack = nil
        self.isMouseInCard = false
        self.isMouseInPopover = false
        onHidePopover?(false)
    }

    /// 调度平滑隐藏
    public func hideAnimated() {
        cancelPendingShow()
        guard isPopoverVisible || activeStack != nil else { return }
        self.isPopoverVisible = false
        self.activeStack = nil
        self.isMouseInCard = false
        self.isMouseInPopover = false
        onHidePopover?(true)
    }

    private func scheduleHide(gracePeriod: TimeInterval) {
        hoverHideTask?.cancel()
        hoverHideTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(gracePeriod * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard let self = self, !Task.isCancelled else { return }
            if !self.isMouseInCard && !self.isMouseInPopover {
                self.hideAnimated()
            }
        }
    }
}
