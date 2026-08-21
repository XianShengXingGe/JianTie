//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation
import Combine

/// 剪贴板历史浮层 ViewModel，处理实时搜索过滤、纯键盘选择状态与删除交互
@MainActor
public final class ClipboardViewModel: ObservableObject {
    @Published public private(set) var items: [ClipboardItem] = []
    @Published public var searchText: String = "" {
        didSet {
            handleSearchTextChange()
        }
    }
    @Published public private(set) var selectedIndex: Int = 0
    @Published public private(set) var presentationCount: Int = 0

    public let engine: ClipboardEngine
    private var cancellables = Set<AnyCancellable>()

    public init(engine: ClipboardEngine) {
        self.engine = engine
        self.items = engine.items

        // 订阅 Engine 数据更新
        engine.$items
            .sink { [weak self] newItems in
                guard let self = self else { return }
                self.items = newItems
                self.clampSelectedIndex()
            }
            .store(in: &cancellables)
    }

    /// 经由当前搜索词过滤后的条目列表
    public var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return items
        }

        return items.filter { item in
            guard let summary = item.plainTextSummary else {
                return false
            }
            return summary.localizedCaseInsensitiveContains(query)
        }
    }

    /// 当前选中的剪贴板记录项
    public var selectedItem: ClipboardItem? {
        let currentFiltered = filteredItems
        guard !currentFiltered.isEmpty, currentFiltered.indices.contains(selectedIndex) else {
            return nil
        }
        return currentFiltered[selectedIndex]
    }

    /// 向下移动选中项
    public func moveSelectionDown() {
        let count = filteredItems.count
        guard count > 0 else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(count - 1, selectedIndex + 1)
    }

    /// 向上移动选中项
    public func moveSelectionUp() {
        guard !filteredItems.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = max(0, selectedIndex - 1)
    }

    /// 设置指定索引为选中项
    public func selectItem(at index: Int) {
        let count = filteredItems.count
        guard count > 0, (0..<count).contains(index) else { return }
        selectedIndex = index
    }

    /// 确认当前选中项并返回以供 Direct Paste
    public func confirmSelection() -> ClipboardItem? {
        return selectedItem
    }

    /// 删除指定 ID 的记录
    public func deleteItem(id: UUID) {
        engine.deleteItem(id: id)
        clampSelectedIndex()
    }

    /// 面板唤出时的初始化状态重置
    public func resetForPresentation() {
        self.searchText = ""
        self.selectedIndex = 0
        self.presentationCount += 1
    }

    private func handleSearchTextChange() {
        self.selectedIndex = 0
    }

    private func clampSelectedIndex() {
        let count = filteredItems.count
        if count == 0 {
            selectedIndex = 0
        } else if selectedIndex >= count {
            selectedIndex = max(0, count - 1)
        }
    }
}
