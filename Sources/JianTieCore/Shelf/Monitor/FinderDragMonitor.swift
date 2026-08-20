//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import CoreGraphics
import AppKit

/// 系统级 Finder 文件拖拽监听器
public final class FinderDragMonitor: DragMonitoring, @unchecked Sendable {
    public private(set) var isMonitoring: Bool = false
    public private(set) var isDraggingActive: Bool = false

    private var globalDragMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var localDragMonitor: Any?
    private var localMouseUpMonitor: Any?

    private var dragStartHandler: (@Sendable ([URL], CGPoint) -> Void)?
    private var dragEndHandler: (@Sendable () -> Void)?

    private let dragPasteboardReader: @Sendable () -> [URL]
    private let changeCountReader: @Sendable () -> Int
    private var lastObservedChangeCount: Int = -1
    private let lock = NSLock()

    public init(
        dragPasteboardReader: @escaping @Sendable () -> [URL] = {
            let pboard = NSPasteboard(name: .drag)
            guard let items = pboard.pasteboardItems, !items.isEmpty else { return [] }
            // 检查是否包含文件类型
            let hasFiles = pboard.types?.contains(where: {
                $0 == .fileURL ||
                $0.rawValue == "NSFilenamesPboardType" ||
                $0.rawValue == "com.apple.finder.node"
            }) ?? false

            guard hasFiles else { return [] }
            return pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        },
        changeCountReader: @escaping @Sendable () -> Int = {
            return NSPasteboard(name: .drag).changeCount
        }
    ) {
        self.dragPasteboardReader = dragPasteboardReader
        self.changeCountReader = changeCountReader
        self.lastObservedChangeCount = changeCountReader()
    }

    public func startMonitoring(
        onDragStart: @escaping @Sendable ([URL], CGPoint) -> Void,
        onDragEnd: @escaping @Sendable () -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }

        guard !isMonitoring else { return }
        self.dragStartHandler = onDragStart
        self.dragEndHandler = onDragEnd
        self.isMonitoring = true
        self.isDraggingActive = false
        self.lastObservedChangeCount = changeCountReader()

        // 1. 全局监听拖拽与鼠标释放
        self.globalDragMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged]
        ) { [weak self] event in
            self?.processDragEvent(location: NSEvent.mouseLocation)
        }

        self.globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseUp]
        ) { [weak self] _ in
            self?.processMouseUpEvent()
        }

        // 2. 本地事件监听
        self.localDragMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged]
        ) { [weak self] event in
            self?.processDragEvent(location: NSEvent.mouseLocation)
            return event
        }

        self.localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseUp]
        ) { [weak self] event in
            self?.processMouseUpEvent()
            return event
        }
    }

    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        guard isMonitoring else { return }

        if let monitor = globalDragMonitor {
            NSEvent.removeMonitor(monitor)
            globalDragMonitor = nil
        }
        if let monitor = globalMouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseUpMonitor = nil
        }
        if let monitor = localDragMonitor {
            NSEvent.removeMonitor(monitor)
            localDragMonitor = nil
        }
        if let monitor = localMouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseUpMonitor = nil
        }

        dragStartHandler = nil
        dragEndHandler = nil
        isMonitoring = false
        isDraggingActive = false
    }

    /// 处理拖拽事件
    public func processDragEvent(location: CGPoint) {
        lock.lock()
        defer { lock.unlock() }

        guard isMonitoring else { return }

        let currentChangeCount = changeCountReader()

        if !isDraggingActive {
            // 只有当剪贴板 changeCount 发生变化（系统开启了新拖拽 Session）时才触发
            guard currentChangeCount != lastObservedChangeCount else {
                return
            }

            let urls = dragPasteboardReader()
            if !urls.isEmpty {
                isDraggingActive = true
                lastObservedChangeCount = currentChangeCount
                let startCallback = dragStartHandler
                DispatchQueue.main.async {
                    startCallback?(urls, location)
                }
            }
        }
    }

    /// 处理鼠标释放事件
    public func processMouseUpEvent() {
        lock.lock()
        defer { lock.unlock() }

        guard isMonitoring else { return }

        // 释放鼠标时同步更新 changeCount 记录，避免后续普通的无文件点击触发历史残留数据
        lastObservedChangeCount = changeCountReader()

        guard isDraggingActive else { return }

        isDraggingActive = false
        let endCallback = dragEndHandler
        DispatchQueue.main.async {
            endCallback?()
        }
    }

    deinit {
        stopMonitoring()
    }
}
