//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import CoreGraphics
import Combine
import AppKit

/// 线程安全的跨线程状态共享容器
final class SharedShelfState: @unchecked Sendable {
    private let lock = NSLock()
    private var _edge: ShelfEdge = .left
    private var _verticalPercent: CGFloat = 0.5
    private var _isRevealed: Bool = false

    var edge: ShelfEdge {
        get { lock.lock(); defer { lock.unlock() }; return _edge }
        set { lock.lock(); defer { lock.unlock() }; _edge = newValue }
    }

    var verticalPercent: CGFloat {
        get { lock.lock(); defer { lock.unlock() }; return _verticalPercent }
        set { lock.lock(); defer { lock.unlock() }; _verticalPercent = newValue }
    }

    var isRevealed: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isRevealed }
        set { lock.lock(); defer { lock.unlock() }; _isRevealed = newValue }
    }
}

/// Shelf 核心业务引擎，协调拖拽探测、多屏锚定、Stack 暂存生命周期与后台巡检
@MainActor
public final class ShelfEngine: ObservableObject {
    @Published public internal(set) var state: ShelfState = .hidden {
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

    @Published public var verticalPercent: CGFloat = 0.5 {
        didSet {
            let clamped = min(max(verticalPercent, 0.0), 1.0)
            if clamped != verticalPercent {
                verticalPercent = clamped
                return
            }
            guard oldValue != verticalPercent else { return }
            sharedState.verticalPercent = verticalPercent
            preferences?.shelfVerticalPercent = Double(verticalPercent)
            updateRevealedPositionForCurrentEdge()
        }
    }

    @Published public internal(set) var stacks: [ShelfStack] = []
    @Published public internal(set) var isStackDragging: Bool = false
    @Published public internal(set) var isPanelDragging: Bool = false
    @Published public internal(set) var activeDraggingStack: ShelfStack?
    @Published public internal(set) var actionFeedback: String?

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

    internal var activeScreen: ScreenInfo?
    internal let sharedState = SharedShelfState()
    private var feedbackTask: Task<Void, Never>?
    internal let screensProvider: @Sendable () -> [ScreenInfo]

    public init(
        edge: ShelfEdge? = nil,
        verticalPercent: CGFloat? = nil,
        preferences: PreferencesProviding? = nil,
        dragMonitor: DragMonitoring? = nil,
        edgeMonitor: ShelfEdgeMonitor? = nil,
        geometryCalculator: ShelfGeometryCalculator = ShelfGeometryCalculator(),
        pruner: ShelfPruner? = nil,
        airDropService: AirDropSharingProviding? = nil,
        pasteboardWriter: PasteboardWriting? = nil,
        screensProvider: @escaping @Sendable () -> [ScreenInfo] = { ScreenInfo.currentScreens() },
        autoStart: Bool = true
    ) {
        let actualPreferences = preferences ?? UserDefaultsPreferences.shared
        self.preferences = actualPreferences
        let initialEdge = edge ?? actualPreferences.shelfEdge
        self.edge = initialEdge
        let initialVerticalPercent = verticalPercent ?? CGFloat(actualPreferences.shelfVerticalPercent)
        self.verticalPercent = initialVerticalPercent
        self.geometryCalculator = geometryCalculator
        self.pruner = pruner ?? ShelfPruner()
        self.airDropService = airDropService ?? SystemAirDropService()
        self.pasteboardWriter = pasteboardWriter ?? SystemPasteboardWriter()
        self.screensProvider = screensProvider
        self.sharedState.edge = initialEdge
        self.sharedState.verticalPercent = initialVerticalPercent
        self.sharedState.isRevealed = false

        let actualDragMonitor = dragMonitor ?? FinderDragMonitor()
        self.dragMonitor = actualDragMonitor

        let capturedShared = self.sharedState
        let capturedScreens = screensProvider
        let capturedDragMonitor = actualDragMonitor
        let actualEdgeMonitor = edgeMonitor ?? ShelfEdgeMonitor(
            screensProvider: capturedScreens,
            edgeProvider: { capturedShared.edge },
            verticalPercentProvider: { capturedShared.verticalPercent },
            isFinderDragProvider: { capturedDragMonitor.isDraggingActive },
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
    public func dropFiles(_ urls: [URL], on targetScreen: ScreenInfo? = nil) -> ShelfStack? {
        guard !urls.isEmpty else { return nil }

        let references = urls.map { ShelfFileReference(url: $0) }
        let stack = ShelfStack(files: references)
        stacks.insert(stack, at: 0)

        let screens = screensProvider()
        let screen: ScreenInfo?
        if let existing = activeScreen {
            screen = existing
        } else if let target = targetScreen {
            screen = target
            self.activeScreen = target
        } else if let mouseScreen = geometryCalculator.findScreen(for: NSEvent.mouseLocation, in: screens) {
            screen = mouseScreen
            self.activeScreen = mouseScreen
        } else {
            screen = screens.first
            self.activeScreen = screen
        }

        if let screen = screen {
            let (visibleFrame, hiddenFrame) = geometryCalculator.calculateWindowFrames(
                screen: screen,
                edge: edge,
                verticalPercent: verticalPercent
            )
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

        let targetStackId = resolveTargetStackId(urls: urls, sourceStackId: sourceStackId)

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
        self.actionFeedback = L10n.tr("shelf.action_path_copied")
        feedbackTask?.cancel()
        feedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self?.actionFeedback = nil
        }

        let targetStackId = resolveTargetStackId(urls: urls, sourceStackId: sourceStackId)

        if let targetId = targetStackId {
            self.removeStack(id: targetId)
        }
    }

    private func resolveTargetStackId(urls: [URL], sourceStackId: UUID?) -> UUID? {
        sourceStackId ?? activeDraggingStack?.id ?? stacks.first(where: { stack in
            Set(stack.resolvedURLs) == Set(urls)
        })?.id
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
                let screens = ScreenInfo.currentScreens()
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
}
