import XCTest
@testable import JianTieCore

final class AccessibilityPermissionTests: XCTestCase {
    func test_isTrusted_returnsUnderlyingState() {
        var mockState = false
        let service = AccessibilityPermissionService(
            isTrustedProvider: { mockState },
            promptProvider: { false },
            openSettingsHandler: {}
        )

        XCTAssertFalse(service.isTrusted)

        mockState = true
        XCTAssertTrue(service.isTrusted)
    }

    func test_promptForPermission_callsPromptAndReturnsResult() {
        var promptCalled = false
        let service = AccessibilityPermissionService(
            isTrustedProvider: { false },
            promptProvider: {
                promptCalled = true
                return true
            },
            openSettingsHandler: {}
        )

        let result = service.promptForPermission()
        XCTAssertTrue(promptCalled)
        XCTAssertTrue(result)
    }

    func test_openSystemAccessibilitySettings_triggersSettingsOpening() {
        var settingsOpened = false
        let service = AccessibilityPermissionService(
            isTrustedProvider: { false },
            promptProvider: { false },
            openSettingsHandler: { settingsOpened = true }
        )

        service.openSystemAccessibilitySettings()
        XCTAssertTrue(settingsOpened)
    }
}
