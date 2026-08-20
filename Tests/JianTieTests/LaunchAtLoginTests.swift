import XCTest
import ServiceManagement
@testable import JianTieCore

final class LaunchAtLoginTests: XCTestCase {
    func test_isEnabled_whenStatusIsEnabledOrRequiresApproval_returnsTrue() {
        let enabledService = LaunchAtLoginService(
            statusProvider: { .enabled },
            registerHandler: {},
            unregisterHandler: {}
        )
        XCTAssertTrue(enabledService.isEnabled)

        let requiresApprovalService = LaunchAtLoginService(
            statusProvider: { .requiresApproval },
            registerHandler: {},
            unregisterHandler: {}
        )
        XCTAssertTrue(requiresApprovalService.isEnabled)
    }

    func test_isEnabled_whenStatusIsNotRegisteredOrNotFound_returnsFalse() {
        let notRegisteredService = LaunchAtLoginService(
            statusProvider: { .notRegistered },
            registerHandler: {},
            unregisterHandler: {}
        )
        XCTAssertFalse(notRegisteredService.isEnabled)

        let notFoundService = LaunchAtLoginService(
            statusProvider: { .notFound },
            registerHandler: {},
            unregisterHandler: {}
        )
        XCTAssertFalse(notFoundService.isEnabled)
    }

    func test_register_whenHandlerSucceeds_returnsTrue() {
        var registerCalled = false
        let service = LaunchAtLoginService(
            statusProvider: { .notRegistered },
            registerHandler: { registerCalled = true },
            unregisterHandler: {}
        )

        let result = service.register()
        XCTAssertTrue(result)
        XCTAssertTrue(registerCalled)
    }

    func test_register_whenHandlerThrows_silentlyDegradesAndReturnsFalse() {
        struct MockError: Error {}
        let service = LaunchAtLoginService(
            statusProvider: { .notRegistered },
            registerHandler: { throw MockError() },
            unregisterHandler: {}
        )

        let result = service.register()
        XCTAssertFalse(result)
    }

    func test_unregister_whenHandlerSucceeds_returnsTrue() {
        var unregisterCalled = false
        let service = LaunchAtLoginService(
            statusProvider: { .enabled },
            registerHandler: {},
            unregisterHandler: { unregisterCalled = true }
        )

        let result = service.unregister()
        XCTAssertTrue(result)
        XCTAssertTrue(unregisterCalled)
    }

    func test_unregister_whenHandlerThrows_silentlyDegradesAndReturnsFalse() {
        struct MockError: Error {}
        let service = LaunchAtLoginService(
            statusProvider: { .enabled },
            registerHandler: {},
            unregisterHandler: { throw MockError() }
        )

        let result = service.unregister()
        XCTAssertFalse(result)
    }
}
