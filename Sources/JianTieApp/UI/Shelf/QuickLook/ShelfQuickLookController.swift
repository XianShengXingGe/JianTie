import Cocoa
import QuickLookUI
import JianTieCore

/// Shelf Quick Look 原生预览控制器，管理 QLPreviewPanel 的数据提供与空格键监听
@MainActor
public final class ShelfQuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    public static let shared = ShelfQuickLookController()

    public private(set) var previewURLs: [URL] = []
    public private(set) var currentPreviewIndex: Int = 0

    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var isHoveringShelf: Bool = false
    private var currentHoverURLsProvider: (() -> [URL])?

    public override init() {
        super.init()
    }

    // MARK: - Hover Key Monitoring

    /// 当鼠标进入 Shelf 或其卡片悬停区域时，激活空格键轻量监听
    public func startHoverKeyMonitoring(urlsProvider: @escaping () -> [URL]) {
        self.currentHoverURLsProvider = urlsProvider
        self.isHoveringShelf = true

        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isHoveringShelf else { return event }
                if event.keyCode == 49 { // Space
                    self.handleSpaceKeyPress()
                    return nil
                } else if event.keyCode == 53 { // ESC
                    if self.isPreviewPanelOpen {
                        self.closePreview()
                        return nil
                    }
                }
                return event
            }
        }
    }

    /// 当鼠标离开 Shelf 区域时，停止按键监听并可按需收起预览
    public func stopHoverKeyMonitoring(closePreviewIfOpen: Bool = false) {
        self.isHoveringShelf = false
        self.currentHoverURLsProvider = nil

        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }

        if closePreviewIfOpen && isPreviewPanelOpen {
            closePreview()
        }
    }

    // MARK: - Preview Panel Actions

    public var isPreviewPanelOpen: Bool {
        guard let panel = QLPreviewPanel.shared() else { return false }
        return panel.isVisible
    }

    public func handleSpaceKeyPress() {
        if isPreviewPanelOpen {
            closePreview()
        } else if let urls = currentHoverURLsProvider?(), !urls.isEmpty {
            preview(urls: urls, initialIndex: 0)
        }
    }

    /// 针对指定文件列表打开 Quick Look 预览面板
    public func preview(urls: [URL], initialIndex: Int = 0) {
        let validURLs = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !validURLs.isEmpty else { return }

        self.previewURLs = validURLs
        self.currentPreviewIndex = min(max(0, initialIndex), validURLs.count - 1)

        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = self.currentPreviewIndex
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    /// 关闭 Quick Look 预览面板
    public func closePreview() {
        guard let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
        panel.orderOut(nil)
    }

    // MARK: - QLPreviewPanelDataSource

    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return previewURLs.count
    }

    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard (0..<previewURLs.count).contains(index) else {
            return nil
        }
        return previewURLs[index] as NSURL
    }

    // MARK: - QLPreviewPanelDelegate

    public func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // 在 Quick Look 窗口中按空格或 ESC 退出
        if event.type == .keyDown && (event.keyCode == 49 || event.keyCode == 53) {
            closePreview()
            return true
        }
        return false
    }
}
