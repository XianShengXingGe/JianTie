import Foundation
import Combine

/// 剪贴板历史核心引擎，统一协调监听、持久化存储与内存状态
@MainActor
public final class ClipboardEngine: ObservableObject {
    @Published public private(set) var items: [ClipboardItem] = []

    public let pasteboard: PasteboardProviding
    public let storage: ClipboardStorageProviding
    public let monitor: ClipboardMonitor

    public init(
        pasteboard: PasteboardProviding = SystemPasteboardReader(),
        storage: ClipboardStorageProviding = FileClipboardStorage(),
        autoStart: Bool = true
    ) {
        self.pasteboard = pasteboard
        self.storage = storage
        self.items = (try? storage.prune()) ?? (try? storage.load()) ?? []

        final class HandlerBox: @unchecked Sendable {
            var handler: (@Sendable (ClipboardItem) -> Void)?
        }
        let box = HandlerBox()

        let monitor = ClipboardMonitor(pasteboard: pasteboard) { item in
            box.handler?(item)
        }
        self.monitor = monitor

        box.handler = { [weak self] capturedItem in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.handleCapturedItem(capturedItem)
                }
            } else {
                DispatchQueue.main.async {
                    self?.handleCapturedItem(capturedItem)
                }
            }
        }

        if autoStart {
            startMonitoring()
        }
    }

    /// 启动剪贴板监听
    public func startMonitoring() {
        monitor.start()
    }

    /// 停止剪贴板监听
    public func stopMonitoring() {
        monitor.stop()
    }

    /// 处理新捕获到的剪贴板项目
    public func handleCapturedItem(_ item: ClipboardItem) {
        do {
            let updatedList = try storage.append(item: item)
            self.items = updatedList
        } catch {
            // 如果存储失败，仍更新内存状态以保证当次会话一致
            var current = items
            current.removeAll { $0.content.isContentEqual(to: item.content) }
            current.insert(item, at: 0)
            self.items = current
        }
    }

    /// 执行剪贴板历史容量与生命周期修剪
    public func pruneHistory(now: Date = Date()) {
        if let updatedList = try? storage.prune(now: now) {
            self.items = updatedList
        }
    }

    /// 删除指定 ID 的条目
    public func deleteItem(id: UUID) {
        do {
            let updatedList = try storage.delete(id: id)
            self.items = updatedList
        } catch {
            self.items.removeAll { $0.id == id }
        }
    }

    /// 清空所有剪贴板历史
    public func clearHistory() {
        try? storage.clear()
        self.items.removeAll()
    }
}
