import Foundation
import CoreGraphics
import Combine
#if canImport(AppKit)
import AppKit
#endif

/// 线程安全的跨线程状态共享容器
final class SharedShelfState: @unchecked Sendable {
    private let lock = NSLock()
    private var _edge: ShelfEdge = .left
    private var _isRevealed: Bool = false

    var edge: ShelfEdge {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _edge
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _edge = newValue
        }
    }

    var isRevealed: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isRevealed
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isRevealed = newValue
        }
    }
}

/// Shelf 核心业务引擎，协调拖拽探测、多屏锚定、Stack 暂存生命周期与后台巡检
@MainActor
public final class ShelfEngine: ObservableObject {
    @Published public private(set) var state: ShelfState = .hidden {
        didSet {
            sharedState.isRevealed = state.isVisible
        }
    }

    @Published public var edge: ShelfEdge = .left {
        didSet {
            guard oldValue != edge else { return }
            sharedState.edge = edge
            preferences?.shelfEdge = edge
            updateRevealedPositionForCurrentEdge()
        }
    }

    @Published public private(set) var stacks: [ShelfStack] = []
    @Published public private(set) var isStackDragging: Bool = false
    @Published public private(set) var activeDraggingStack: ShelfStack?
    @Published public private(set) var actionFeedback: String?

    public var isActionZoneVisible: Bool {
        return state.isDragging || isStackDragging || actionFeedback != nil
    }

    public let preferences: PreferencesProviding?
    public let dragMonitor: DragMonitoring
    public let edgeMonitor: ShelfEdgeMonitor
    public let geometryCalculator: ShelfGeometryCalculator
    public let pruner: ShelfPruner
    public let airDropService: AirDropSharingProviding
    public let pasteboardWriter: PasteboardWriting

    public var onRequestReveal: ((_ visibleFrame: CGRect, _ hiddenFrame: CGRect, _ isDragging: Bool) -> Void)?
    public var onRequestHide: ((_ hiddenFrame: CGRect) -> Void)?
    public var onStateChanged: ((ShelfState) -> Void)?

    private var activeScreen: ScreenInfo?
    private let sharedState = SharedShelfState()
    private var feedbackTask: Task<Void, Never>?

    public init(
        edge: ShelfEdge? = nil,
        preferences: PreferencesProviding? = nil,
        dragMonitor: DragMonitoring? = nil,
        edgeMonitor: ShelfEdgeMonitor? = nil,
        geometryCalculator: ShelfGeometryCalculator = ShelfGeometryCalculator(),
        pruner: ShelfPruner? = nil,
        airDropService: AirDropSharingProviding? = nil,
        pasteboardWriter: PasteboardWriting? = nil,
        autoStart: Bool = true
    ) {
        let actualPreferences = preferences ?? UserDefaultsPreferences.shared
        self.preferences = actualPreferences
        let initialEdge = edge ?? actualPreferences.shelfEdge
        self.edge = initialEdge
        self.geometryCalculator = geometryCalculator
        self.pruner = pruner ?? ShelfPruner()
        #if canImport(AppKit)
        self.airDropService = airDropService ?? SystemAirDropService()
        self.pasteboardWriter = pasteboardWriter ?? SystemPasteboardWriter()
        #else
        self.airDropService = airDropService ?? MockAirDropFallback()
        self.pasteboardWriter = pasteboardWriter ?? MockPasteboardFallback()
        #endif
        self.sharedState.edge = initialEdge
        self.sharedState.isRevealed = false

        let actualDragMonitor = dragMonitor ?? FinderDragMonitor()
        self.dragMonitor = actualDragMonitor

        let capturedShared = self.sharedState
        let actualEdgeMonitor = edgeMonitor ?? ShelfEdgeMonitor(
            screensProvider: {
                #if canImport(AppKit)
                return ScreenInfo.currentScreens()
                #else
                return []
                #endif
            },
            edgeProvider: { capturedShared.edge },
            isRevealedProvider: { capturedShared.isRevealed }
        )
        self.edgeMonitor = actualEdgeMonitor

        if autoStart {
            startMonitoring()
        }
    }

    /// 启动所有监听与巡检服务
    public func startMonitoring() {
        dragMonitor.startMonitoring(
            onDragStart: { [weak self] files, location in
                Task { @MainActor in
                    self?.handleDragStarted(files: files, at: location)
                }
            },
            onDragEnd: { [weak self] in
                Task { @MainActor in
                    self?.handleDragEnded()
                }
            }
        )

        edgeMonitor.startMonitoring(
            onDwell: { [weak self] screen in
                Task { @MainActor in
                    self?.handleEdgeDwell(on: screen)
                }
            },
            onRetract: { [weak self] in
                Task { @MainActor in
                    self?.handleAutoRetract()
                }
            }
        )

        pruner.startPeriodicPruning(
            getStacks: { [weak self] in
                guard let self = self else { return [] }
                if Thread.isMainThread {
                    return MainActor.assumeIsolated { self.stacks }
                } else {
                    return DispatchQueue.main.sync {
                        MainActor.assumeIsolated { self.stacks }
                    }
                }
            },
            onPruned: { [weak self] validStacks in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.stacks = validStacks
                    if validStacks.isEmpty && self.state.isVisible && !self.state.isDragging {
                        self.dismiss()
                    }
                }
            }
        )
    }

    /// 停止所有监听与巡检服务
    public func stopMonitoring() {
        dragMonitor.stopMonitoring()
        edgeMonitor.stopMonitoring()
        pruner.stopPeriodicPruning()
    }

    // MARK: - Stack Operations

    /// 接收拖入的文件 URL 列表，生成原子 Stack 并暂存
    @discardableResult
    public func dropFiles(_ urls: [URL]) -> ShelfStack? {
        guard !urls.isEmpty else { return nil }

        let references = urls.map { ShelfFileReference(url: $0) }
        let stack = ShelfStack(files: references)
        stacks.insert(stack, at: 0)

        #if canImport(AppKit)
        let screens = ScreenInfo.currentScreens()
        #else
        let screens: [ScreenInfo] = []
        #endif

        let screen = activeScreen ?? screens.first
        self.activeScreen = screen

        if let screen = screen {
            let (visibleFrame, hiddenFrame) = geometryCalculator.calculateWindowFrames(screen: screen, edge: edge)
            let newState = ShelfState.stored(screenFrame: screen.frame, edge: edge)
            self.state = newState
            self.onStateChanged?(newState)
            self.onRequestReveal?(visibleFrame, hiddenFrame, false)
        } else {
            let newState = ShelfState.stored(screenFrame: .zero, edge: edge)
            self.state = newState
            self.onStateChanged?(newState)
        }

        return stack
    }

    /// 移除指定 Stack（例如点击 ✕ 或外部成功消费）
    public func removeStack(id: UUID) {
        stacks.removeAll { $0.id == id }
        if stacks.isEmpty {
            dismiss()
        }
    }

    // MARK: - Action Zone & Drag Notifications

    /// 通知 Stack 拖拽开始，激活底部动作区
    public func notifyStackDragStarted(stack: ShelfStack) {
        self.isStackDragging = true
        self.activeDraggingStack = stack
    }

    /// 通知 Stack 拖拽结束
    public func notifyStackDragEnded() {
        self.isStackDragging = false
        self.activeDraggingStack = nil
    }

    /// 拖入 AirDrop 区域：调用系统分享并在成功后清除 Stack
    public func handleAirDrop(urls: [URL], sourceStackId: UUID? = nil) {
        guard !urls.isEmpty else { return }

        let targetStackId = sourceStackId ?? activeDraggingStack?.id ?? stacks.first(where: { stack in
            Set(stack.resolvedURLs) == Set(urls)
        })?.id

        airDropService.performAirDrop(urls: urls) { [weak self] success in
            guard let self = self else { return }
            if success {
                if let targetId = targetStackId {
                    self.removeStack(id: targetId)
                }
            }
        }
    }

    /// 拖入 Copy Path 区域：换行复制全部绝对路径，显示微小反馈并立即移除 Stack
    public func handleCopyPath(urls: [URL], sourceStackId: UUID? = nil) {
        guard !urls.isEmpty else { return }

        let pathString = urls.map { $0.path }.joined(separator: "\n")
        pasteboardWriter.write(content: .text(ClipboardTextContent(plainText: pathString)))

        // 展示轻量内联提示反馈
        self.actionFeedback = "✓ Path copied"
        feedbackTask?.cancel()
        feedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self?.actionFeedback = nil
        }

        let targetStackId = sourceStackId ?? activeDraggingStack?.id ?? stacks.first(where: { stack in
            Set(stack.resolvedURLs) == Set(urls)
        })?.id

        if let targetId = targetStackId {
            self.removeStack(id: targetId)
        }
    }

    /// 清除内联反馈提示
    public func clearActionFeedback() {
        feedbackTask?.cancel()
        feedbackTask = nil
        self.actionFeedback = nil
    }

    /// 处理 Stack 拖出（Drag Out）结束事件
    public func handleStackDragOutCompleted(stackId: UUID, success: Bool) {
        notifyStackDragEnded()
        if success {
            removeStack(id: stackId)
        } else {
            // 拖拽取消或失败，安全保留 Stack 并恢复为 Stored 状态
            if !stacks.isEmpty {
                #if canImport(AppKit)
                let screens = ScreenInfo.currentScreens()
                #else
                let screens: [ScreenInfo] = []
                #endif
                let screen = activeScreen ?? screens.first
                let frame = screen?.frame ?? .zero
                let newState = ShelfState.stored(screenFrame: frame, edge: edge)
                self.state = newState
                self.onStateChanged?(newState)
            }
        }
    }

    /// 手动/即时执行失效 Stack 淘汰
    public func pruneInvalidStacks() {
        let (valid, removed) = pruner.prune(stacks: stacks)
        if removed > 0 {
            self.stacks = valid
            if valid.isEmpty && state.isVisible && !state.isDragging {
                dismiss()
            }
        }
    }

    // MARK: - Lifecycle & State Machine Transitions

    /// 处理 Finder 拖拽开始事件
    public func handleDragStarted(files: [URL], at location: CGPoint) {
        #if canImport(AppKit)
        let screens = ScreenInfo.currentScreens()
        #else
        let screens: [ScreenInfo] = []
        #endif

        guard let screen = geometryCalculator.findScreen(for: location, in: screens) ?? screens.first else {
            return
        }

        self.activeScreen = screen
        let (visibleFrame, hiddenFrame) = geometryCalculator.calculateWindowFrames(screen: screen, edge: edge)

        let newState = ShelfState.revealedDragging(screenFrame: screen.frame, edge: edge)
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
        let (visibleFrame, hiddenFrame) = geometryCalculator.calculateWindowFrames(screen: screen, edge: edge)

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

    /// 收回并隐藏 Shelf
    public func dismiss() {
        guard state.isVisible else { return }

        let screen = activeScreen ?? {
            #if canImport(AppKit)
            return ScreenInfo.currentScreens().first
            #else
            return nil
            #endif
        }()

        if let screen = screen {
            let (_, hiddenFrame) = geometryCalculator.calculateWindowFrames(screen: screen, edge: edge)
            self.onRequestHide?(hiddenFrame)
        }

        self.state = .hidden
        self.onStateChanged?(.hidden)
        self.activeScreen = nil
    }

    private func updateRevealedPositionForCurrentEdge() {
        guard state.isVisible else { return }
        #if canImport(AppKit)
        let screens = ScreenInfo.currentScreens()
        #else
        let screens: [ScreenInfo] = []
        #endif
        let screen = activeScreen ?? screens.first
        guard let screen = screen else { return }

        let (visibleFrame, hiddenFrame) = geometryCalculator.calculateWindowFrames(screen: screen, edge: edge)
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

