import XCTest
import AppKit
@testable import JianTieCore

final class StatusBarMenuTests: XCTestCase {
    @MainActor
    func test_buildMenu_createsStandardMenuItems() {
        let builder = StatusBarMenuBuilder()
        let menu = builder.buildMenu(target: nil)

        // 关于 简贴, 偏好设置..., 分隔线, 退出 简贴
        XCTAssertEqual(menu.items.count, 4)
        XCTAssertEqual(menu.items[0].title, "关于 简贴")
        XCTAssertEqual(menu.items[1].title, "偏好设置...")
        XCTAssertTrue(menu.items[2].isSeparatorItem)
        XCTAssertEqual(menu.items[3].title, "退出 简贴")
    }

    @MainActor
    func test_buildMenu_configuresKeyEquivalents() {
        let builder = StatusBarMenuBuilder()
        let menu = builder.buildMenu(target: nil)

        XCTAssertEqual(menu.items[1].keyEquivalent, ",")
        XCTAssertEqual(menu.items[3].keyEquivalent, "q")
    }
}
