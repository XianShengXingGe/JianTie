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

/// Shelf 核心业务引擎，协调拖拽探测、多屏锚定计算与边缘停留状态机
@MainActor
public final class ShelfEngine: ObservableObject {
    @Published public private(set) var state: ShelfState = .hidden {
        didSet {
            sharedState.isRevealed = state.isVisible
        }
    }

    @Published public var edge: ShelfEdge = .left {
        didSet {
            sharedState.edge = edge
        }
    }

    public let dragMonitor: DragMonitoring
    public let edgeMonitor: ShelfEdgeMonitor
    public let geometryCalculator: ShelfGeometryCalculator

    public var onRequestReveal: ((_ visibleFrame: CGRect, _ hiddenFrame: CGRect, _ isDragging: Bool) -> Void)?
    public var onRequestHide: ((_ hiddenFrame: CGRect) -> Void)?
    public var onStateChanged: ((ShelfState) -> Void)?

    private var activeScreen: ScreenInfo?
    private let sharedState = SharedShelfState()

    public init(
        edge: ShelfEdge = .left,
        dragMonitor: DragMonitoring? = nil,
        edgeMonitor: ShelfEdgeMonitor? = nil,
        geometryCalculator: ShelfGeometryCalculator = ShelfGeometryCalculator(),
        autoStart: Bool = true
    ) {
        self.edge = edge
        self.geometryCalculator = geometryCalculator
        self.sharedState.edge = edge
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

    /// 启动所有监听服务
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
    }

    /// 停止所有监听服务
    public func stopMonitoring() {
        dragMonitor.stopMonitoring()
        edgeMonitor.stopMonitoring()
    }

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

        dismiss()
    }

    /// 处理边缘停留 150ms 触发
    public func handleEdgeDwell(on screen: ScreenInfo) {
        guard state == .hidden else { return }

        self.activeScreen = screen
        let (visibleFrame, hiddenFrame) = geometryCalculator.calculateWindowFrames(screen: screen, edge: edge)

        let newState = ShelfState.revealedEmpty(screenFrame: screen.frame, edge: edge)
        self.state = newState
        self.onStateChanged?(newState)
        self.onRequestReveal?(visibleFrame, hiddenFrame, false)
    }

    /// 处理移出 600ms 自动收回触发
    public func handleAutoRetract() {
        guard case .revealedEmpty = state else { return }

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
}
