import XCTest
import Combine
@testable import JianTieCore

private final class MockPreferences: PreferencesProviding, @unchecked Sendable {
    var launchAtLogin: Bool = true
    var hasConfiguredLaunchAtLogin: Bool = false
    var hotKeyTrigger: HotKeyTrigger = .default
    var shelfEdge: ShelfEdge = .left
    var shelfVerticalPercent: Double = 0.5
    var clipboardCapacityLimit: ClipboardCapacityLimit = .count1000
    var clipboardRetentionPeriod: ClipboardRetentionPeriod = .unlimited
    var appLanguage: AppLanguage = .system
}

private final class MockLaunchAtLoginService: LaunchAtLoginProviding, @unchecked Sendable {
    var isEnabled: Bool = false
    var registerCallCount = 0
    var unregisterCallCount = 0

    @discardableResult
    func register() -> Bool {
        registerCallCount += 1
        isEnabled = true
        return true
    }

    @discardableResult
    func unregister() -> Bool {
        unregisterCallCount += 1
        isEnabled = false
        return true
    }
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

private final class MockHotKeyService: HotKeyServiceProviding, @unchecked Sendable {
    var currentTrigger: HotKeyTrigger = .default
    var isMonitoring: Bool = false
    var updatedTriggers: [HotKeyTrigger] = []

    func startMonitoring(onTrigger: @escaping @Sendable () -> Void) {
        isMonitoring = true
    }

    func stopMonitoring() {
        isMonitoring = false
    }

    func updateTrigger(_ trigger: HotKeyTrigger) {
        currentTrigger = trigger
        updatedTriggers.append(trigger)
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
        XCTAssertTrue(prefs.launchAtLogin)
        XCTAssertFalse(prefs.hasConfiguredLaunchAtLogin)
        XCTAssertEqual(prefs.hotKeyTrigger, .default)
        XCTAssertEqual(prefs.shelfEdge, .left)
        XCTAssertEqual(prefs.shelfVerticalPercent, 0.5)
        XCTAssertEqual(prefs.clipboardCapacityLimit, .count1000)
        XCTAssertEqual(prefs.clipboardRetentionPeriod, .unlimited)
        XCTAssertEqual(prefs.appLanguage, .system)
    }

    func test_userDefaultsPreferences_persistsNewValues() {
        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        prefs.launchAtLogin = false
        prefs.hasConfiguredLaunchAtLogin = true
        prefs.hotKeyTrigger = .keyCombination(keyCode: 9, modifiers: [.option])
        prefs.shelfEdge = .right
        prefs.shelfVerticalPercent = 0.75
        prefs.clipboardCapacityLimit = .count300
        prefs.clipboardRetentionPeriod = .days30
        prefs.appLanguage = .en

        XCTAssertFalse(prefs.launchAtLogin)
        XCTAssertTrue(prefs.hasConfiguredLaunchAtLogin)
        XCTAssertEqual(prefs.hotKeyTrigger, .keyCombination(keyCode: 9, modifiers: [.option]))
        XCTAssertEqual(prefs.shelfEdge, .right)
        XCTAssertEqual(prefs.shelfVerticalPercent, 0.75)
        XCTAssertEqual(prefs.clipboardCapacityLimit, .count300)
        XCTAssertEqual(prefs.clipboardRetentionPeriod, .days30)
        XCTAssertEqual(prefs.appLanguage, .en)

        // 读取新实例验证已持久化
        let prefs2 = UserDefaultsPreferences(userDefaults: testUserDefaults)
        XCTAssertFalse(prefs2.launchAtLogin)
        XCTAssertTrue(prefs2.hasConfiguredLaunchAtLogin)
        XCTAssertEqual(prefs2.hotKeyTrigger, .keyCombination(keyCode: 9, modifiers: [.option]))
        XCTAssertEqual(prefs2.shelfEdge, .right)
        XCTAssertEqual(prefs2.shelfVerticalPercent, 0.75)
        XCTAssertEqual(prefs2.clipboardCapacityLimit, .count300)
        XCTAssertEqual(prefs2.clipboardRetentionPeriod, .days30)
        XCTAssertEqual(prefs2.appLanguage, .en)
    }

    func test_userDefaultsPreferences_invalidValueDefaults() {
        testUserDefaults.set("invalid_edge_key", forKey: UserDefaultsPreferences.Keys.shelfEdge)
        testUserDefaults.set(99999, forKey: UserDefaultsPreferences.Keys.clipboardCapacityLimit)
        testUserDefaults.set(99999, forKey: UserDefaultsPreferences.Keys.clipboardRetentionPeriod)
        testUserDefaults.set("corrupted_data".data(using: .utf8), forKey: UserDefaultsPreferences.Keys.hotKeyTrigger)
        testUserDefaults.set("invalid_lang_key", forKey: UserDefaultsPreferences.Keys.appLanguage)

        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        XCTAssertEqual(prefs.shelfEdge, .left)
        XCTAssertEqual(prefs.shelfVerticalPercent, 0.5)
        XCTAssertEqual(prefs.clipboardCapacityLimit, .count1000)
        XCTAssertEqual(prefs.clipboardRetentionPeriod, .unlimited)
        XCTAssertEqual(prefs.hotKeyTrigger, .default)
        XCTAssertEqual(prefs.appLanguage, .system)
    }

    // MARK: - PreferencesViewModel Tests

    func test_preferencesViewModel_initialValues() {
        let mockPrefs = MockPreferences()
        mockPrefs.hotKeyTrigger = .doubleTap(modifier: .option)
        mockPrefs.shelfEdge = .right
        mockPrefs.clipboardCapacityLimit = .count500
        mockPrefs.clipboardRetentionPeriod = .days7
        let mockLaunchAtLogin = MockLaunchAtLoginService()
        mockLaunchAtLogin.isEnabled = true
        let mockAccessibility = MockAccessibilityPermissionService()
        mockAccessibility.isTrusted = true

        let vm = PreferencesViewModel(
            preferences: mockPrefs,
            launchAtLoginService: mockLaunchAtLogin,
            accessibilityService: mockAccessibility
        )

        XCTAssertTrue(vm.launchAtLogin)
        XCTAssertEqual(vm.hotKeyTrigger, .doubleTap(modifier: .option))
        XCTAssertEqual(vm.shelfEdge, .right)
        XCTAssertEqual(vm.clipboardCapacityLimit, .count500)
        XCTAssertEqual(vm.clipboardRetentionPeriod, .days7)
        XCTAssertTrue(vm.isAccessibilityTrusted)
        XCTAssertTrue(vm.clipboardRetentionDescription.contains("FIFO"))
        XCTAssertFalse(vm.appVersionText.isEmpty)
        XCTAssertFalse(vm.showClearConfirmationAlert)
    }

    func test_preferencesViewModel_setHotKeyTrigger_updatesPrefsAndHotKeyService() {
        let mockPrefs = MockPreferences()
        let mockHotKey = MockHotKeyService()

        let vm = PreferencesViewModel(
            preferences: mockPrefs,
            hotKeyService: mockHotKey
        )

        let newTrigger = HotKeyTrigger.keyCombination(keyCode: 9, modifiers: [.option])
        vm.setHotKeyTrigger(newTrigger)

        XCTAssertEqual(vm.hotKeyTrigger, newTrigger)
        XCTAssertEqual(mockPrefs.hotKeyTrigger, newTrigger)
        XCTAssertEqual(mockHotKey.updatedTriggers, [newTrigger])
        XCTAssertEqual(mockHotKey.currentTrigger, newTrigger)
        XCTAssertFalse(vm.isDefaultHotKey)

        // 切换为双击 Option
        vm.setDoubleTapModifier(.option)
        XCTAssertEqual(vm.hotKeyTrigger, .doubleTap(modifier: .option))
        XCTAssertEqual(mockPrefs.hotKeyTrigger, .doubleTap(modifier: .option))
        XCTAssertEqual(mockHotKey.currentTrigger, .doubleTap(modifier: .option))
        XCTAssertFalse(vm.isDefaultHotKey)

        // 一键重置为默认值 (双击 ⌘)
        vm.resetHotKeyToDefault()
        XCTAssertEqual(vm.hotKeyTrigger, .default)
        XCTAssertEqual(mockPrefs.hotKeyTrigger, .default)
        XCTAssertEqual(mockHotKey.currentTrigger, .default)
        XCTAssertTrue(vm.isDefaultHotKey)
    }

    func test_preferencesViewModel_setLaunchAtLogin_registersAndUnregisters() {
        let mockPrefs = MockPreferences()
        let mockLaunchAtLogin = MockLaunchAtLoginService()
        mockLaunchAtLogin.isEnabled = false

        let vm = PreferencesViewModel(
            preferences: mockPrefs,
            launchAtLoginService: mockLaunchAtLogin,
            accessibilityService: MockAccessibilityPermissionService()
        )

        XCTAssertFalse(vm.launchAtLogin)

        // 开启开机自启
        vm.setLaunchAtLogin(true)
        XCTAssertTrue(vm.launchAtLogin)
        XCTAssertTrue(mockPrefs.launchAtLogin)
        XCTAssertEqual(mockLaunchAtLogin.registerCallCount, 1)
        XCTAssertTrue(mockLaunchAtLogin.isEnabled)

        // 关闭开机自启
        vm.setLaunchAtLogin(false)
        XCTAssertFalse(vm.launchAtLogin)
        XCTAssertFalse(mockPrefs.launchAtLogin)
        XCTAssertEqual(mockLaunchAtLogin.unregisterCallCount, 1)
        XCTAssertFalse(mockLaunchAtLogin.isEnabled)
    }

    func test_preferencesViewModel_refreshLaunchAtLoginStatus_synchronizesWithService() {
        let mockPrefs = MockPreferences()
        let mockLaunchAtLogin = MockLaunchAtLoginService()
        mockLaunchAtLogin.isEnabled = false

        let vm = PreferencesViewModel(
            preferences: mockPrefs,
            launchAtLoginService: mockLaunchAtLogin,
            accessibilityService: MockAccessibilityPermissionService()
        )

        XCTAssertFalse(vm.launchAtLogin)

        // 外部（如系统设置）改变了状态
        mockLaunchAtLogin.isEnabled = true
        vm.refreshLaunchAtLoginStatus()

        XCTAssertTrue(vm.launchAtLogin)
        XCTAssertTrue(mockPrefs.launchAtLogin)
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

    func test_preferencesViewModel_refreshStatus_refreshesBothAccessibilityAndLaunchAtLogin() {
        let mockPrefs = MockPreferences()
        let mockLaunchAtLogin = MockLaunchAtLoginService()
        mockLaunchAtLogin.isEnabled = false
        let mockAccessibility = MockAccessibilityPermissionService()
        mockAccessibility.isTrusted = false

        let vm = PreferencesViewModel(
            preferences: mockPrefs,
            launchAtLoginService: mockLaunchAtLogin,
            accessibilityService: mockAccessibility
        )

        XCTAssertFalse(vm.isAccessibilityTrusted)
        XCTAssertFalse(vm.launchAtLogin)

        mockAccessibility.isTrusted = true
        mockLaunchAtLogin.isEnabled = true

        vm.refreshStatus()

        XCTAssertTrue(vm.isAccessibilityTrusted)
        XCTAssertTrue(vm.launchAtLogin)
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

    func test_preferencesViewModel_setAppLanguage_updatesPrefsAndLocalizationManager() {
        let mockPrefs = MockPreferences()
        mockPrefs.appLanguage = .system
        let localizationManager = LocalizationManager(
            preferences: mockPrefs,
            preferredLanguagesProvider: { ["zh-Hans-CN"] }
        )

        let vm = PreferencesViewModel(
            preferences: mockPrefs,
            localizationManager: localizationManager
        )

        XCTAssertEqual(vm.appLanguage, .system)
        XCTAssertEqual(vm.localizationManager.effectiveLanguage, .zhHans)

        vm.setAppLanguage(.en)

        XCTAssertEqual(vm.appLanguage, .en)
        XCTAssertEqual(mockPrefs.appLanguage, .en)
        XCTAssertEqual(localizationManager.currentLanguage, .en)
        XCTAssertEqual(localizationManager.effectiveLanguage, .en)
    }
}
