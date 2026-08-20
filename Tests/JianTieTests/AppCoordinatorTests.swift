import XCTest
import AppKit
@testable import JianTieCore

private final class MockDoubleTapMonitor: DoubleTapMonitoring, @unchecked Sendable {
    var isMonitoring: Bool = false
    var triggerHandler: (@Sendable () -> Void)?

    func startMonitoring(onTrigger: @escaping @Sendable () -> Void) {
        self.isMonitoring = true
        self.triggerHandler = onTrigger
    }

    func stopMonitoring() {
        self.isMonitoring = false
        self.triggerHandler = nil
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

    func test_doubleTap_triggersCallbackAndRecordsLastFrontmostApp() {
        let expectedTarget = AppTarget(bundleIdentifier: "com.apple.Notes", processIdentifier: 1234, localizedName: "Notes")
        let activator = MockAppActivator()
        activator.currentFrontmost = expectedTarget

        let mockMonitor = MockDoubleTapMonitor()
        let coordinator = AppCoordinator(
            doubleTapMonitor: mockMonitor,
            appActivator: activator,
            statusItemProvider: { nil }
        )

        let receivedTarget = TestBox<AppTarget?>(nil)
        coordinator.onDoubleTapCommand = { target in
            receivedTarget.value = target
        }

        coordinator.start()
        XCTAssertTrue(mockMonitor.isMonitoring)

        // 模拟触发双击 Command
        mockMonitor.simulateTrigger()

        coordinator.handleDoubleTapCommand()

        XCTAssertEqual(coordinator.lastFrontmostApp, expectedTarget)
        XCTAssertEqual(receivedTarget.value, expectedTarget)
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
        coordinator.handleDoubleTapCommand()
        XCTAssertEqual(coordinator.lastFrontmostApp, expectedTarget)

        let item = ClipboardItem(content: .text(ClipboardTextContent(plainText: "Coordinator Paste Test")))
        let result = await coordinator.pasteItem(item)

        XCTAssertTrue(result)
        XCTAssertEqual(mockWriter.writtenContents.count, 1)
        XCTAssertEqual(activator.activatedTargets.count, 1)
        XCTAssertEqual(mockSynthesizer.synthesizedCount, 1)
    }

    func test_doubleTap_triggersPresentClipboardHandler() {
        let expectedTarget = AppTarget(bundleIdentifier: "com.apple.Terminal", processIdentifier: 5678, localizedName: "Terminal")
        let activator = MockAppActivator()
        activator.currentFrontmost = expectedTarget

        let presentedTarget = TestBox<AppTarget?>(nil)
        let coordinator = AppCoordinator(
            appActivator: activator,
            presentClipboardHandler: { target in
                presentedTarget.value = target
            },
            statusItemProvider: { nil }
        )

        coordinator.handleDoubleTapCommand()

        XCTAssertEqual(presentedTarget.value, expectedTarget)
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
}
