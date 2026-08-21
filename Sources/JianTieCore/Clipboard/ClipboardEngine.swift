//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

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

    /// 处理新捕获到的剪贴板项目（内存即时更新 + 异步后台持久化）
    public func handleCapturedItem(_ item: ClipboardItem) {
        // 1. 内存即时响应更新（无等待，零延迟 UI 刷新）
        var current = items
        current.removeAll { $0.isContentEqual(to: item) }
        current.insert(item, at: 0)
        self.items = current

        // 2. 异步后台落盘持久化
        Task { [weak self, storage] in
            let updatedList = try? await storage.appendAsync(item: item)
            if let updatedList = updatedList {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.items = updatedList
                }
            }
        }
    }

    /// 执行剪贴板历史容量与生命周期修剪（异步后台执行）
    public func pruneHistory(now: Date = Date()) {
        Task { [weak self, storage] in
            let updatedList = try? await storage.pruneAsync(now: now)
            if let updatedList = updatedList {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.items = updatedList
                }
            }
        }
    }

    /// 删除指定 ID 的条目（内存即时更新 + 异步后台持久化）
    public func deleteItem(id: UUID) {
        self.items.removeAll { $0.id == id }
        Task { [weak self, storage] in
            let updatedList = try? await storage.deleteAsync(id: id)
            if let updatedList = updatedList {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.items = updatedList
                }
            }
        }
    }

    /// 清空所有剪贴板历史（内存即时清空 + 异步后台持久化）
    public func clearHistory() {
        self.items.removeAll()
        Task { [storage] in
            try? await storage.clearAsync()
        }
    }
}
