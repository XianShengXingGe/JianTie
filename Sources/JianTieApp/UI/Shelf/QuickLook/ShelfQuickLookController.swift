import Cocoa
import QuickLookUI
import JianTieCore

/// Shelf Quick Look 原生预览控制器，管理 QLPreviewPanel 的数据提供、按键监听与系统级交互
@MainActor
public final class ShelfQuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    public static let shared = ShelfQuickLookController()

    private enum KeyCode {
        static let space: UInt16 = 49
        static let escape: UInt16 = 53
    }

    public let coordinator: ShelfQuickLookCoordinator

    public var previewURLs: [URL] { coordinator.previewURLs }
    public var currentPreviewIndex: Int { coordinator.currentPreviewIndex }
    public var isPreviewPanelOpen: Bool {
        guard let panel = QLPreviewPanel.shared() else { return false }
        return panel.isVisible
    }
    public var isHoveringShelf: Bool { coordinator.isHoveringShelf }

    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    public init(coordinator: ShelfQuickLookCoordinator) {
        self.coordinator = coordinator
        super.init()

        coordinator.onShowPreview = { [weak self] urls, initialIndex in
            self?.presentQuickLookPanel(urls: urls, initialIndex: initialIndex)
        }

        coordinator.onClosePreview = { [weak self] in
            self?.dismissQuickLookPanel()
        }
    }

    public convenience override init() {
        self.init(coordinator: .shared)
    }

    // MARK: - Hover Key Monitoring

    /// 当鼠标进入 Shelf 或其卡片悬停区域时，激活空格键与 ESC 轻量监听
    public func startHoverKeyMonitoring(urlsProvider: @escaping () -> [URL]) {
        coordinator.startHoverKeyMonitoring(urlsProvider: urlsProvider)

        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isHoveringShelf else { return event }
                if self.processKeyDownEvent(keyCode: event.keyCode) {
                    return nil
                }
                return event
            }
        }

        if globalKeyMonitor == nil {
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isHoveringShelf else { return }
                _ = self.processKeyDownEvent(keyCode: event.keyCode)
            }
        }
    }

    /// 当鼠标离开 Shelf 区域时，停止按键监听并可按需收起预览
    public func stopHoverKeyMonitoring(closePreviewIfOpen: Bool = false) {
        coordinator.stopHoverKeyMonitoring(closePreviewIfOpen: closePreviewIfOpen)

        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }

        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
    }

    // MARK: - Key Dispatch Helper

    @discardableResult
    private func processKeyDownEvent(keyCode: UInt16) -> Bool {
        switch keyCode {
        case KeyCode.space:
            return coordinator.handleSpaceKeyPress()
        case KeyCode.escape:
            return coordinator.handleEscapeKeyPress()
        default:
            return false
        }
    }

    // MARK: - Direct Action APIs

    public func handleSpaceKeyPress() {
        coordinator.handleSpaceKeyPress()
    }

    public func handleEscapeKeyPress() {
        coordinator.handleEscapeKeyPress()
    }

    public func preview(urls: [URL], initialIndex: Int = 0) {
        coordinator.preview(urls: urls, initialIndex: initialIndex)
    }

    public func closePreview() {
        coordinator.closePreview()
    }

    // MARK: - Quick Look Panel Presentation

    private func presentQuickLookPanel(urls: [URL], initialIndex: Int) {
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = initialIndex
        panel.reloadData()
        panel.orderFront(nil)
    }

    private func dismissQuickLookPanel() {
        guard let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
        panel.orderOut(nil)
    }

    // MARK: - QLPreviewPanelDataSource

    nonisolated public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated {
            coordinator.previewURLs.count
        }
    }

    nonisolated public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        MainActor.assumeIsolated {
            guard (0..<coordinator.previewURLs.count).contains(index) else {
                return nil
            }
            return coordinator.previewURLs[index] as NSURL
        }
    }

    // MARK: - QLPreviewPanelDelegate

    nonisolated public func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        MainActor.assumeIsolated {
            if event.type == .keyDown && (event.keyCode == KeyCode.space || event.keyCode == KeyCode.escape) {
                closePreview()
                return true
            }
            return false
        }
    }
}
