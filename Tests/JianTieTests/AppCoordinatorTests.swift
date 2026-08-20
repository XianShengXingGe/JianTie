import XCTest
import AppKit
@testable import JianTieCore

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func test_start_whenUntrusted_presentsAccessibilityGuidance() {
        var guidancePresented = false
        let permissionService = AccessibilityPermissionService(
            isTrustedProvider: { false }
        )
        let coordinator = AppCoordinator(
            accessibilityService: permissionService,
            menuBuilder: StatusBarMenuBuilder(),
            presentGuidanceHandler: { guidancePresented = true },
            statusItemProvider: { nil }
        )

        coordinator.start()

        XCTAssertTrue(guidancePresented)
    }

    func test_start_whenTrusted_doesNotPresentAccessibilityGuidance() {
        var guidancePresented = false
        let permissionService = AccessibilityPermissionService(
            isTrustedProvider: { true }
        )
        let coordinator = AppCoordinator(
            accessibilityService: permissionService,
            menuBuilder: StatusBarMenuBuilder(),
            presentGuidanceHandler: { guidancePresented = true },
            statusItemProvider: { nil }
        )

        coordinator.start()

        XCTAssertFalse(guidancePresented)
    }

    func test_handleAccessibilityAction_opensSettings() {
        var settingsOpened = false
        let permissionService = AccessibilityPermissionService(
            isTrustedProvider: { false },
            openSettingsHandler: { settingsOpened = true }
        )
        let coordinator = AppCoordinator(
            accessibilityService: permissionService,
            menuBuilder: StatusBarMenuBuilder(),
            presentGuidanceHandler: {},
            statusItemProvider: { nil }
        )

        coordinator.openAccessibilitySettings()

        XCTAssertTrue(settingsOpened)
    }
}
