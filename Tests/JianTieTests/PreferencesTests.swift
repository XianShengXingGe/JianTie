import XCTest
import Combine
@testable import JianTieCore

private final class MockPreferences: PreferencesProviding, @unchecked Sendable {
    var shelfEdge: ShelfEdge = .left
    var clipboardCapacityLimit: ClipboardCapacityLimit = .count1000
    var clipboardRetentionPeriod: ClipboardRetentionPeriod = .unlimited
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

    func test_userDefaultsPreferences_defaults() {
        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        XCTAssertEqual(prefs.shelfEdge, .left)
        XCTAssertEqual(prefs.clipboardCapacityLimit, .count1000)
        XCTAssertEqual(prefs.clipboardRetentionPeriod, .unlimited)
    }

    func test_userDefaultsPreferences_persistsNewValues() {
        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        prefs.shelfEdge = .right
        prefs.clipboardCapacityLimit = .count300
        prefs.clipboardRetentionPeriod = .days30

        XCTAssertEqual(prefs.shelfEdge, .right)
        XCTAssertEqual(prefs.clipboardCapacityLimit, .count300)
        XCTAssertEqual(prefs.clipboardRetentionPeriod, .days30)

        // 读取新实例验证已持久化
        let prefs2 = UserDefaultsPreferences(userDefaults: testUserDefaults)
        XCTAssertEqual(prefs2.shelfEdge, .right)
        XCTAssertEqual(prefs2.clipboardCapacityLimit, .count300)
        XCTAssertEqual(prefs2.clipboardRetentionPeriod, .days30)
    }

    func test_userDefaultsPreferences_invalidValueDefaults() {
        testUserDefaults.set("invalid_edge_key", forKey: UserDefaultsPreferences.Keys.shelfEdge)
        testUserDefaults.set(99999, forKey: UserDefaultsPreferences.Keys.clipboardCapacityLimit)
        testUserDefaults.set(99999, forKey: UserDefaultsPreferences.Keys.clipboardRetentionPeriod)

        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        XCTAssertEqual(prefs.shelfEdge, .left)
        XCTAssertEqual(prefs.clipboardCapacityLimit, .count1000)
        XCTAssertEqual(prefs.clipboardRetentionPeriod, .unlimited)
    }

    // MARK: - PreferencesViewModel Tests

    func test_preferencesViewModel_initialValues() {
        let mockPrefs = MockPreferences()
        mockPrefs.shelfEdge = .right
        mockPrefs.clipboardCapacityLimit = .count500
        mockPrefs.clipboardRetentionPeriod = .days7
        let mockAccessibility = MockAccessibilityPermissionService()
        mockAccessibility.isTrusted = true

        let vm = PreferencesViewModel(
            preferences: mockPrefs,
            accessibilityService: mockAccessibility
        )

        XCTAssertEqual(vm.shelfEdge, .right)
        XCTAssertEqual(vm.clipboardCapacityLimit, .count500)
        XCTAssertEqual(vm.clipboardRetentionPeriod, .days7)
        XCTAssertTrue(vm.isAccessibilityTrusted)
        XCTAssertTrue(vm.clipboardRetentionDescription.contains("FIFO"))
        XCTAssertFalse(vm.appVersionText.isEmpty)
        XCTAssertFalse(vm.showClearConfirmationAlert)
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

    func test_preferencesViewModel_setClipboardCapacityAndRetention_updatesPrefsAndPrunes() {
        let mockPrefs = MockPreferences()
        let storage = FileClipboardStorage(
            baseDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            preferences: mockPrefs
        )
        let clipboardEngine = ClipboardEngine(storage: storage, autoStart: false)
        let vm = PreferencesViewModel(
            preferences: mockPrefs,
            clipboardEngine: clipboardEngine
        )

        vm.setClipboardCapacityLimit(.count50)
        XCTAssertEqual(vm.clipboardCapacityLimit, .count50)
        XCTAssertEqual(mockPrefs.clipboardCapacityLimit, .count50)

        vm.setClipboardRetentionPeriod(.days3)
        XCTAssertEqual(vm.clipboardRetentionPeriod, .days3)
        XCTAssertEqual(mockPrefs.clipboardRetentionPeriod, .days3)
    }

    func test_preferencesViewModel_confirmClearClipboardHistory_clearsEngine() {
        let mockPrefs = MockPreferences()
        let storage = FileClipboardStorage(
            baseDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            preferences: mockPrefs
        )
        let clipboardEngine = ClipboardEngine(storage: storage, autoStart: false)
        clipboardEngine.handleCapturedItem(ClipboardItem(content: .text(ClipboardTextContent(plainText: "ItemToClear"))))
        XCTAssertEqual(clipboardEngine.items.count, 1)

        let vm = PreferencesViewModel(
            preferences: mockPrefs,
            clipboardEngine: clipboardEngine
        )

        vm.confirmClearClipboardHistory()
        XCTAssertTrue(clipboardEngine.items.isEmpty)
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
