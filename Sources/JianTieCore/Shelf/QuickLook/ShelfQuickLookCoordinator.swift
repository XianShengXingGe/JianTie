//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// Shelf Quick Look 暂存架快速预览协调器，管理预览目标分层切换、空格键 Toggle 与生命周期联动
@MainActor
public final class ShelfQuickLookCoordinator: ObservableObject {
    public static let shared = ShelfQuickLookCoordinator()

    @Published public private(set) var previewURLs: [URL] = []
    @Published public private(set) var currentPreviewIndex: Int = 0
    @Published public private(set) var isPreviewOpen: Bool = false
    @Published public private(set) var isHoveringShelf: Bool = false

    public var currentHoverURLsProvider: (() -> [URL])?

    public var onShowPreview: ((_ urls: [URL], _ initialIndex: Int) -> Void)?
    public var onClosePreview: (() -> Void)?

    public init() {}

    // MARK: - Hover Key Monitoring State

    /// 鼠标进入 Shelf 卡片或浮层子项时激活悬停监控
    public func startHoverKeyMonitoring(urlsProvider: @escaping () -> [URL]) {
        self.currentHoverURLsProvider = urlsProvider
        self.isHoveringShelf = true
    }

    /// 鼠标移出时停止悬停按键监控
    public func stopHoverKeyMonitoring(closePreviewIfOpen: Bool = false) {
        self.isHoveringShelf = false
        self.currentHoverURLsProvider = nil

        if closePreviewIfOpen && isPreviewOpen {
            closePreview()
        }
    }

    // MARK: - Key Event Handling

    /// 处理空格键按键事件（Toggle 行为：开启则关闭，关闭则打开）
    @discardableResult
    public func handleSpaceKeyPress() -> Bool {
        if isPreviewOpen {
            closePreview()
            return true
        } else if let rawURLs = currentHoverURLsProvider?() {
            let validURLs = filterExistingURLs(rawURLs)
            guard !validURLs.isEmpty else { return false }
            preview(urls: validURLs, initialIndex: 0)
            return true
        }
        return false
    }

    /// 处理 ESC 键按键事件（仅在预览开启时关闭）
    @discardableResult
    public func handleEscapeKeyPress() -> Bool {
        if isPreviewOpen {
            closePreview()
            return true
        }
        return false
    }

    // MARK: - Preview Operations

    /// 针对指定文件列表打开 Quick Look 预览
    public func preview(urls: [URL], initialIndex: Int = 0) {
        let validURLs = filterExistingURLs(urls)
        guard !validURLs.isEmpty else { return }

        self.previewURLs = validURLs
        self.currentPreviewIndex = min(max(0, initialIndex), validURLs.count - 1)
        self.isPreviewOpen = true

        onShowPreview?(self.previewURLs, self.currentPreviewIndex)
    }

    /// 关闭 Quick Look 预览
    public func closePreview() {
        guard isPreviewOpen else { return }
        self.isPreviewOpen = false
        onClosePreview?()
    }

    // MARK: - Lifecycle Dismissal Hooks

    /// 拖拽开始时联动收起预览并清理悬停
    public func notifyDragStarted() {
        stopHoverKeyMonitoring(closePreviewIfOpen: true)
    }

    /// Shelf 自动退回收起或隐藏时联动关闭预览
    public func notifyShelfHidden() {
        stopHoverKeyMonitoring(closePreviewIfOpen: true)
    }

    // MARK: - Helpers

    private func filterExistingURLs(_ urls: [URL]) -> [URL] {
        return urls.filter { FileManager.default.fileExists(atPath: $0.path) }
    }
}
