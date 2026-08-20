import Foundation
#if canImport(XCTest)
import XCTest
#endif
import AppKit
@testable import JianTieCore

private final class MockHotKeyService: HotKeyServiceProviding, @unchecked Sendable {
    var currentTrigger: HotKeyTrigger = .default
    var isMonitoring: Bool = false
    var triggerHandler: (@Sendable () -> Void)?
    var updateTriggerCallCount = 0
    var stopCallCount = 0

    func startMonitoring(onTrigger: @escaping @Sendable () -> Void) {
        self.isMonitoring = true
        self.triggerHandler = onTrigger
    }

    func stopMonitoring() {
        self.isMonitoring = false
        self.triggerHandler = nil
        self.stopCallCount += 1
    }

    func updateTrigger(_ trigger: HotKeyTrigger) {
        self.currentTrigger = trigger
        self.updateTriggerCallCount += 1
    }

    func simulateTrigger() {
        triggerHandler?()
    }
}

private final class MockAppActivator: AppActivating, @unchecked Sendable {
    var currentFrontmost: AppTarget? = AppTarget(bundleIdentifier: "com.apple.Notes", processIdentifier: 1234, localizedName: "Notes")
    var activatedTargets: [AppTarget] = []
    var activateResult: Bool = true

    func frontmostApp() -> AppTarget? {
        currentFrontmost
    }

    func activate(target: AppTarget) -> Bool {
        activatedTargets.append(target)
        return activateResult
    }
}

private final class MockPasteboardWriter: PasteboardWriting, @unchecked Sendable {
    var writeResult: Bool = true
    var writtenContents: [ClipboardContent] = []

    func write(content: ClipboardContent) -> Bool {
        writtenContents.append(content)
        return writeResult
    }
}

private final class MockKeySynthesizer: KeyEventSynthesizing, @unchecked Sendable {
    var synthesizeResult: Bool = true
    var synthesizedCount: Int = 0

    func synthesizeCommandV() -> Bool {
        synthesizedCount += 1
        return synthesizeResult
    }
}

private final class MockPreferences: PreferencesProviding, @unchecked Sendable {
    var launchAtLogin: Bool = false
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

private final class TestBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func test_start_whenUntrusted_presentsAccessibilityGuidance() {
        let guidancePresented = TestBox(false)
        let permissionService = AccessibilityPermissionService(
            isTrustedProvider: { false }
        )
        let coordinator = AppCoordinator(
            accessibilityService: permissionService,
            menuBuilder: StatusBarMenuBuilder(),
            presentGuidanceHandler: { guidancePresented.value = true },
            statusItemProvider: { nil }
        )

        coordinator.start()

        XCTAssertTrue(guidancePresented.value)
    }

    func test_start_whenTrusted_doesNotPresentAccessibilityGuidance() {
        let guidancePresented = TestBox(false)
        let permissionService = AccessibilityPermissionService(
            isTrustedProvider: { true }
        )
        let coordinator = AppCoordinator(
            accessibilityService: permissionService,
            menuBuilder: StatusBarMenuBuilder(),
            presentGuidanceHandler: { guidancePresented.value = true },
            statusItemProvider: { nil }
        )

        coordinator.start()

        XCTAssertFalse(guidancePresented.value)
    }

    func test_handleAccessibilityAction_opensSettings() {
        let settingsOpened = TestBox(false)
        let permissionService = AccessibilityPermissionService(
            isTrustedProvider: { false },
            openSettingsHandler: { settingsOpened.value = true }
        )
        let coordinator = AppCoordinator(
            accessibilityService: permissionService,
            menuBuilder: StatusBarMenuBuilder(),
            presentGuidanceHandler: {},
            statusItemProvider: { nil }
        )

        coordinator.openAccessibilitySettings()

        XCTAssertTrue(settingsOpened.value)
    }

    func test_start_startsClipboardMonitoring() {
        let coordinator = AppCoordinator(
            statusItemProvider: { nil }
        )

        coordinator.start()

        XCTAssertNotNil(coordinator.clipboardEngine)
    }

    func test_hotKeyTrigger_whenClipboardHidden_recordsFrontmostAndPresents() {
        let expectedTarget = AppTarget(bundleIdentifier: "com.apple.Notes", processIdentifier: 1234, localizedName: "Notes")
        let activator = MockAppActivator()
        activator.currentFrontmost = expectedTarget

        let mockHotKey = MockHotKeyService()
        let presentedTarget = TestBox<AppTarget?>(nil)
        let triggeredTarget = TestBox<AppTarget?>(nil)
        let isVisibleBox = TestBox(false)

        let coordinator = AppCoordinator(
            hotKeyService: mockHotKey,
            appActivator: activator,
            presentClipboardHandler: { target in
                presentedTarget.value = target
            },
            isClipboardVisibleHandler: {
                isVisibleBox.value
            },
            statusItemProvider: { nil }
        )
        coordinator.onHotKeyTriggered = { target in
            triggeredTarget.value = target
        }

        coordinator.start()
        XCTAssertTrue(mockHotKey.isMonitoring)

        // 模拟触发热键
        mockHotKey.simulateTrigger()
        coordinator.handleHotKeyTrigger()

        XCTAssertEqual(coordinator.lastFrontmostApp, expectedTarget)
        XCTAssertEqual(presentedTarget.value, expectedTarget)
        XCTAssertEqual(triggeredTarget.value, expectedTarget)
    }

    func test_hotKeyTrigger_whenClipboardVisible_togglesAndDismisses() {
        let activator = MockAppActivator()
        activator.currentFrontmost = AppTarget(bundleIdentifier: "com.apple.Notes", processIdentifier: 1234, localizedName: "Notes")

        let mockHotKey = MockHotKeyService()
        let presentedCalled = TestBox(false)
        let dismissCalled = TestBox(false)
        let isVisibleBox = TestBox(true)

        let coordinator = AppCoordinator(
            hotKeyService: mockHotKey,
            appActivator: activator,
            presentClipboardHandler: { _ in
                presentedCalled.value = true
            },
            dismissClipboardHandler: {
                dismissCalled.value = true
            },
            isClipboardVisibleHandler: {
                isVisibleBox.value
            },
            statusItemProvider: { nil }
        )

        coordinator.start()

        // 模拟在可见状态下按下快捷键
        coordinator.handleHotKeyTrigger()

        XCTAssertTrue(dismissCalled.value)
        XCTAssertFalse(presentedCalled.value)
    }

    func test_pasteItem_delegatesToDirectPasteService() async {
        let expectedTarget = AppTarget(bundleIdentifier: "com.apple.Safari", processIdentifier: 999, localizedName: "Safari")
        let activator = MockAppActivator()
        activator.currentFrontmost = expectedTarget

        let mockWriter = MockPasteboardWriter()
        let mockSynthesizer = MockKeySynthesizer()
        let pasteService = DirectPasteService(
            pasteboardWriter: mockWriter,
            appActivator: activator,
            keySynthesizer: mockSynthesizer
        )

        let coordinator = AppCoordinator(
            directPasteService: pasteService,
            appActivator: activator,
            statusItemProvider: { nil }
        )

        // 记录前台应用
        coordinator.handleHotKeyTrigger()
        XCTAssertEqual(coordinator.lastFrontmostApp, expectedTarget)

        let item = ClipboardItem(content: .text(ClipboardTextContent(plainText: "Coordinator Paste Test")))
        let result = await coordinator.pasteItem(item)

        XCTAssertTrue(result)
        XCTAssertEqual(mockWriter.writtenContents.count, 1)
        XCTAssertEqual(activator.activatedTargets.count, 1)
        XCTAssertEqual(mockSynthesizer.synthesizedCount, 1)
    }

    func test_start_startsShelfMonitoring() {
        let coordinator = AppCoordinator(
            statusItemProvider: { nil }
        )

        coordinator.start()

        XCTAssertNotNil(coordinator.shelfEngine)
        XCTAssertTrue(coordinator.shelfEngine.dragMonitor.isMonitoring)
        XCTAssertTrue(coordinator.shelfEngine.edgeMonitor.isMonitoring)
    }

    func test_openPreferences_invokesPresentPreferencesHandler() {
        let preferencesPresented = TestBox(false)
        let coordinator = AppCoordinator(
            presentPreferencesHandler: {
                preferencesPresented.value = true
            },
            statusItemProvider: { nil }
        )

        coordinator.openPreferences()

        XCTAssertTrue(preferencesPresented.value)
    }

    func test_setupStatusItem_configuresStatusBarIconAndMenu() {
        let dummyItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let coordinator = AppCoordinator(
            statusItemProvider: { dummyItem }
        )

        coordinator.setupStatusItem()

        XCTAssertNotNil(coordinator.statusItem)
        XCTAssertNotNil(coordinator.statusItem?.menu)
        XCTAssertNotNil(coordinator.statusItem?.button?.image)
        XCTAssertTrue(coordinator.statusItem?.button?.image?.isTemplate == true)
        XCTAssertEqual(coordinator.statusItem?.button?.image?.size.width, 18)
        XCTAssertEqual(coordinator.statusItem?.button?.image?.size.height, 18)
    }

    func test_start_onFirstLaunch_enablesLaunchAtLoginAndRegisters() {
        let mockPrefs = MockPreferences()
        mockPrefs.hasConfiguredLaunchAtLogin = false
        mockPrefs.launchAtLogin = false
        let mockLaunchAtLogin = MockLaunchAtLoginService()

        let coordinator = AppCoordinator(
            preferences: mockPrefs,
            launchAtLoginService: mockLaunchAtLogin,
            statusItemProvider: { nil }
        )

        coordinator.start()

        XCTAssertTrue(mockPrefs.hasConfiguredLaunchAtLogin)
        XCTAssertTrue(mockPrefs.launchAtLogin)
        XCTAssertEqual(mockLaunchAtLogin.registerCallCount, 1)
        XCTAssertTrue(mockLaunchAtLogin.isEnabled)
    }

    func test_start_whenAlreadyConfigured_doesNotOverridePreferences() {
        let mockPrefs = MockPreferences()
        mockPrefs.hasConfiguredLaunchAtLogin = true
        mockPrefs.launchAtLogin = false
        let mockLaunchAtLogin = MockLaunchAtLoginService()
        mockLaunchAtLogin.isEnabled = false

        let coordinator = AppCoordinator(
            preferences: mockPrefs,
            launchAtLoginService: mockLaunchAtLogin,
            statusItemProvider: { nil }
        )

        coordinator.start()

        XCTAssertTrue(mockPrefs.hasConfiguredLaunchAtLogin)
        XCTAssertFalse(mockPrefs.launchAtLogin)
        XCTAssertEqual(mockLaunchAtLogin.registerCallCount, 0)
        XCTAssertFalse(mockLaunchAtLogin.isEnabled)
    }

    func test_languageChange_refreshesStatusItemMenu() {
        let dummyItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let mockPrefs = MockPreferences()
        mockPrefs.appLanguage = .zhHans
        let localizationManager = LocalizationManager(
            preferences: mockPrefs,
            preferredLanguagesProvider: { ["zh-Hans-CN"] }
        )

        let coordinator = AppCoordinator(
            preferences: mockPrefs,
            localizationManager: localizationManager,
            statusItemProvider: { dummyItem }
        )

        coordinator.setupStatusItem()
        XCTAssertEqual(coordinator.statusItem?.menu?.items[0].title, "关于 简贴")
        XCTAssertEqual(coordinator.statusItem?.menu?.items[1].title, "偏好设置...")
        XCTAssertEqual(coordinator.statusItem?.menu?.items[3].title, "退出 简贴")

        // 切换语言为英文并触发通知
        localizationManager.setLanguage(.en)

        XCTAssertEqual(coordinator.statusItem?.menu?.items[0].title, "About JianTie")
        XCTAssertEqual(coordinator.statusItem?.menu?.items[1].title, "Preferences...")
        XCTAssertEqual(coordinator.statusItem?.menu?.items[3].title, "Quit JianTie")
    }
}
