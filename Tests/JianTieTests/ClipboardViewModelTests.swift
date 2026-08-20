import Foundation
#if canImport(XCTest)
import XCTest
#endif
import Combine
@testable import JianTieCore

@MainActor
final class ClipboardViewModelTests: XCTestCase {
    private func createTextItem(_ text: String, id: UUID = UUID(), timestamp: Date = Date()) -> ClipboardItem {
        ClipboardItem(
            id: id,
            timestamp: timestamp,
            content: .text(ClipboardTextContent(plainText: text))
        )
    }

    private func createImageItem(id: UUID = UUID(), timestamp: Date = Date()) -> ClipboardItem {
        ClipboardItem(
            id: id,
            timestamp: timestamp,
            content: .image(ClipboardImageContent(imageData: Data([0x89, 0x50, 0x4E, 0x47]), format: "png"))
        )
    }

    private func makeViewModel(items: [ClipboardItem] = []) -> (ClipboardViewModel, MockClipboardStorage, ClipboardEngine) {
        let storage = MockClipboardStorage()
        storage.storedItems = items
        let engine = ClipboardEngine(
            pasteboard: MockPasteboardReader(),
            storage: storage,
            autoStart: false
        )
        let viewModel = ClipboardViewModel(engine: engine)
        return (viewModel, storage, engine)
    }

    func test_initialState_withItems_selectsFirstItem() {
        let item1 = createTextItem("First Item")
        let item2 = createTextItem("Second Item")

        let (viewModel, _, _) = makeViewModel(items: [item1, item2])

        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.filteredItems.count, 2)
        XCTAssertEqual(viewModel.selectedIndex, 0)
        XCTAssertEqual(viewModel.selectedItem?.id, item1.id)
        XCTAssertTrue(viewModel.searchText.isEmpty)
    }

    func test_initialState_whenEmpty_hasZeroSelection() {
        let (viewModel, _, _) = makeViewModel(items: [])

        XCTAssertEqual(viewModel.items.count, 0)
        XCTAssertEqual(viewModel.filteredItems.count, 0)
        XCTAssertEqual(viewModel.selectedIndex, 0)
        XCTAssertNil(viewModel.selectedItem)
    }

    func test_filter_textMatchesCaseInsensitive() {
        let item1 = createTextItem("SwiftUI and AppKit development")
        let item2 = createTextItem("Kotlin Multiplatform")
        let item3 = createTextItem("Swift Concurrency")

        let (viewModel, _, _) = makeViewModel(items: [item1, item2, item3])

        viewModel.searchText = "swift"

        XCTAssertEqual(viewModel.filteredItems.count, 2)
        XCTAssertEqual(viewModel.filteredItems[0].id, item1.id)
        XCTAssertEqual(viewModel.filteredItems[1].id, item3.id)
    }

    func test_filter_imageItem_includedWhenSearchEmpty_excludedWhenSearchActive() {
        let textItem = createTextItem("Sample Text")
        let imageItem = createImageItem()

        let (viewModel, _, _) = makeViewModel(items: [textItem, imageItem])

        // 空搜索时包含图片
        XCTAssertEqual(viewModel.filteredItems.count, 2)
        XCTAssertTrue(viewModel.filteredItems.contains(where: { $0.id == imageItem.id }))

        // 激活搜索时排除无文本匹配的图片
        viewModel.searchText = "Sample"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems.first?.id, textItem.id)
    }

    func test_searchTextChange_resetsSelectedIndexToZero() {
        let item1 = createTextItem("Alpha 1")
        let item2 = createTextItem("Alpha 2")
        let item3 = createTextItem("Beta 1")

        let (viewModel, _, _) = makeViewModel(items: [item1, item2, item3])
        viewModel.moveSelectionDown()
        XCTAssertEqual(viewModel.selectedIndex, 1)

        viewModel.searchText = "Alpha"
        XCTAssertEqual(viewModel.selectedIndex, 0)
        XCTAssertEqual(viewModel.selectedItem?.id, item1.id)
    }

    func test_keyboardNavigation_moveSelectionDown_and_moveSelectionUp() {
        let item1 = createTextItem("Item 1")
        let item2 = createTextItem("Item 2")
        let item3 = createTextItem("Item 3")

        let (viewModel, _, _) = makeViewModel(items: [item1, item2, item3])
        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.moveSelectionDown()
        XCTAssertEqual(viewModel.selectedIndex, 1)

        viewModel.moveSelectionDown()
        XCTAssertEqual(viewModel.selectedIndex, 2)

        // 边界测试：已在末尾，不再向下增加
        viewModel.moveSelectionDown()
        XCTAssertEqual(viewModel.selectedIndex, 2)

        // 向上导航
        viewModel.moveSelectionUp()
        XCTAssertEqual(viewModel.selectedIndex, 1)

        viewModel.moveSelectionUp()
        XCTAssertEqual(viewModel.selectedIndex, 0)

        // 边界测试：已在头部，不再向上减少
        viewModel.moveSelectionUp()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func test_deleteItem_removesFromStorageAndUpdatesFilteredItems() {
        let item1 = createTextItem("Item 1")
        let item2 = createTextItem("Item 2")
        let item3 = createTextItem("Item 3")

        let (viewModel, _, _) = makeViewModel(items: [item1, item2, item3])
        viewModel.moveSelectionDown()
        viewModel.moveSelectionDown()
        XCTAssertEqual(viewModel.selectedIndex, 2)

        // 删除当前选中的末尾项
        viewModel.deleteItem(id: item3.id)

        XCTAssertEqual(viewModel.filteredItems.count, 2)
        XCTAssertFalse(viewModel.filteredItems.contains(where: { $0.id == item3.id }))
        // selectedIndex 自动收缩到合法末尾索引 1
        XCTAssertEqual(viewModel.selectedIndex, 1)
        XCTAssertEqual(viewModel.selectedItem?.id, item2.id)
    }

    func test_resetForPresentation_clearsSearchAndResetsSelection() {
        let item1 = createTextItem("Item 1")
        let item2 = createTextItem("Item 2")

        let (viewModel, _, _) = makeViewModel(items: [item1, item2])
        viewModel.searchText = "Item 2"
        viewModel.moveSelectionDown()

        viewModel.resetForPresentation()

        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.selectedIndex, 0)
        XCTAssertEqual(viewModel.selectedItem?.id, item1.id)
    }

    func test_confirmSelection_returnsCurrentlySelectedItem() {
        let item1 = createTextItem("First")
        let item2 = createTextItem("Second")

        let (viewModel, _, _) = makeViewModel(items: [item1, item2])
        viewModel.moveSelectionDown()

        let confirmed = viewModel.confirmSelection()
        XCTAssertEqual(confirmed?.id, item2.id)
    }
}

private final class MockClipboardStorage: ClipboardStorageProviding, @unchecked Sendable {
    var storedItems: [ClipboardItem] = []

    func load() throws -> [ClipboardItem] {
        storedItems
    }

    func save(items: [ClipboardItem]) throws {
        storedItems = items
    }

    func append(item: ClipboardItem) throws -> [ClipboardItem] {
        storedItems.insert(item, at: 0)
        return storedItems
    }

    func delete(id: UUID) throws -> [ClipboardItem] {
        storedItems.removeAll { $0.id == id }
        return storedItems
    }

    func prune(now: Date) throws -> [ClipboardItem] {
        return storedItems
    }

    func clear() throws {
        storedItems.removeAll()
    }
}

private final class MockPasteboardReader: PasteboardProviding, @unchecked Sendable {
    var changeCount: Int = 0
    func readItem() -> ClipboardContent? { nil }
}
