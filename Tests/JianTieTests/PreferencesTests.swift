import XCTest
import Combine
@testable import JianTieCore

private final class MockPreferences: PreferencesProviding, @unchecked Sendable {
    var shelfEdge: ShelfEdge = .left
}

private final class MockAccessibilityPermissionService: AccessibilityPermissionProviding, @unchecked Sendable {
    var isTrusted: Bool = false
    var promptCallCount = 0
    var openSettingsCallCount = 0

    @discardableResult
    func promptForPermission() -> Bool {
        promptCallCount += 1
        return isTrusted
    }

    func openSystemAccessibilitySettings() {
        openSettingsCallCount += 1
    }
}

@MainActor
final class PreferencesTests: XCTestCase {
    private var testUserDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.jiantie.preferences.\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: suiteName)
        testUserDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - UserDefaultsPreferences Tests

    func test_userDefaultsPreferences_defaultsToLeft() {
        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        XCTAssertEqual(prefs.shelfEdge, .left)
    }

    func test_userDefaultsPreferences_persistsNewValue() {
        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        prefs.shelfEdge = .right
        XCTAssertEqual(prefs.shelfEdge, .right)

        // 读取新实例验证已持久化
        let prefs2 = UserDefaultsPreferences(userDefaults: testUserDefaults)
        XCTAssertEqual(prefs2.shelfEdge, .right)
    }

    func test_userDefaultsPreferences_invalidValueDefaultsToLeft() {
        testUserDefaults.set("invalid_edge_key", forKey: UserDefaultsPreferences.Keys.shelfEdge)
        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        XCTAssertEqual(prefs.shelfEdge, .left)
    }

    // MARK: - PreferencesViewModel Tests

    func test_preferencesViewModel_initialValues() {
        let mockPrefs = MockPreferences()
        mockPrefs.shelfEdge = .right
        let mockAccessibility = MockAccessibilityPermissionService()
        mockAccessibility.isTrusted = true

        let vm = PreferencesViewModel(
            preferences: mockPrefs,
            accessibilityService: mockAccessibility
        )

        XCTAssertEqual(vm.shelfEdge, .right)
        XCTAssertTrue(vm.isAccessibilityTrusted)
        XCTAssertTrue(vm.clipboardRetentionDescription.contains("1000"))
        XCTAssertTrue(vm.clipboardRetentionDescription.contains("FIFO"))
        XCTAssertFalse(vm.appVersionText.isEmpty)
    }

    func test_preferencesViewModel_setShelfEdge_updatesPrefsAndEngine() {
        let mockPrefs = MockPreferences()
        mockPrefs.shelfEdge = .left
        let shelfEngine = ShelfEngine(preferences: mockPrefs, autoStart: false)
        let mockAccessibility = MockAccessibilityPermissionService()

        let vm = PreferencesViewModel(
            preferences: mockPrefs,
            accessibilityService: mockAccessibility,
            shelfEngine: shelfEngine
        )

        XCTAssertEqual(vm.shelfEdge, .left)
        XCTAssertEqual(mockPrefs.shelfEdge, .left)
        XCTAssertEqual(shelfEngine.edge, .left)

        vm.setShelfEdge(.right)

        XCTAssertEqual(vm.shelfEdge, .right)
        XCTAssertEqual(mockPrefs.shelfEdge, .right)
        XCTAssertEqual(shelfEngine.edge, .right)
    }

    func test_preferencesViewModel_refreshAccessibilityStatus() {
        let mockAccessibility = MockAccessibilityPermissionService()
        mockAccessibility.isTrusted = false
        let vm = PreferencesViewModel(
            preferences: MockPreferences(),
            accessibilityService: mockAccessibility
        )

        XCTAssertFalse(vm.isAccessibilityTrusted)

        mockAccessibility.isTrusted = true
        vm.refreshAccessibilityStatus()

        XCTAssertTrue(vm.isAccessibilityTrusted)
    }

    func test_preferencesViewModel_openAccessibilitySettings() {
        let mockAccessibility = MockAccessibilityPermissionService()
        let vm = PreferencesViewModel(
            preferences: MockPreferences(),
            accessibilityService: mockAccessibility
        )

        vm.openAccessibilitySettings()

        XCTAssertEqual(mockAccessibility.promptCallCount, 1)
        XCTAssertEqual(mockAccessibility.openSettingsCallCount, 1)
    }
}
