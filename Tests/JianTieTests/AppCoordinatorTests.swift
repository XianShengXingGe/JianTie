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

        var receivedTarget: AppTarget?
        coordinator.onDoubleTapCommand = { target in
            receivedTarget = target
        }

        coordinator.start()
        XCTAssertTrue(mockMonitor.isMonitoring)

        // 模拟触发双击 Command
        mockMonitor.simulateTrigger()

        coordinator.handleDoubleTapCommand()

        XCTAssertEqual(coordinator.lastFrontmostApp, expectedTarget)
        XCTAssertEqual(receivedTarget, expectedTarget)
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

        var presentedTarget: AppTarget?
        let coordinator = AppCoordinator(
            appActivator: activator,
            presentClipboardHandler: { target in
                presentedTarget = target
            },
            statusItemProvider: { nil }
        )

        coordinator.handleDoubleTapCommand()

        XCTAssertEqual(presentedTarget, expectedTarget)
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
}
