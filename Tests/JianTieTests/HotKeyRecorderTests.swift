import XCTest
import Combine
import AppKit
import Carbon.HIToolbox
@testable import JianTieCore

private final class MockPreferences: PreferencesProviding, @unchecked Sendable {
    var launchAtLogin: Bool = true
    var hasConfiguredLaunchAtLogin: Bool = false
    var hotKeyTrigger: HotKeyTrigger = .default
    var shelfEdge: ShelfEdge = .left
    var clipboardCapacityLimit: ClipboardCapacityLimit = .count1000
    var clipboardRetentionPeriod: ClipboardRetentionPeriod = .unlimited
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
final class HotKeyRecorderTests: XCTestCase {
    private var mockPrefs: MockPreferences!
    private var mockHotKeyService: MockHotKeyService!
    private var preferencesViewModel: PreferencesViewModel!
    private var recorderViewModel: HotKeyRecorderViewModel!

    override func setUp() {
        super.setUp()
        mockPrefs = MockPreferences()
        mockHotKeyService = MockHotKeyService()
        preferencesViewModel = PreferencesViewModel(
            preferences: mockPrefs,
            hotKeyService: mockHotKeyService
        )
        recorderViewModel = HotKeyRecorderViewModel(preferencesViewModel: preferencesViewModel)
    }

    override func tearDown() {
        recorderViewModel.stopRecording()
        recorderViewModel = nil
        preferencesViewModel = nil
        mockHotKeyService = nil
        mockPrefs = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState() {
        XCTAssertFalse(recorderViewModel.isRecording)
        XCTAssertNil(recorderViewModel.errorMessage)
        XCTAssertEqual(recorderViewModel.shakeTrigger, 0)
        XCTAssertEqual(recorderViewModel.currentTrigger, .default)
        XCTAssertTrue(recorderViewModel.isDefaultHotKey)
    }

    // MARK: - Recording Start/Stop/Toggle

    func test_startAndStopRecording() {
        recorderViewModel.startRecording()
        XCTAssertTrue(recorderViewModel.isRecording)
        XCTAssertNil(recorderViewModel.errorMessage)

        recorderViewModel.stopRecording()
        XCTAssertFalse(recorderViewModel.isRecording)
    }

    func test_toggleRecording() {
        XCTAssertFalse(recorderViewModel.isRecording)
        recorderViewModel.toggleRecording()
        XCTAssertTrue(recorderViewModel.isRecording)
        recorderViewModel.toggleRecording()
        XCTAssertFalse(recorderViewModel.isRecording)
    }

    // MARK: - Key Event Handling

    func test_handleKeyDown_whenNotRecording_returnsFalse() {
        let handled = recorderViewModel.handleKeyDown(keyCode: UInt16(kVK_ANSI_V), modifierFlags: .option)
        XCTAssertFalse(handled)
        XCTAssertEqual(recorderViewModel.currentTrigger, .default)
    }

    func test_handleKeyDown_escape_cancelsRecordingWithoutModifyingTrigger() {
        recorderViewModel.startRecording()
        XCTAssertTrue(recorderViewModel.isRecording)

        let handled = recorderViewModel.handleKeyDown(keyCode: 53, modifierFlags: [])
        XCTAssertTrue(handled)
        XCTAssertFalse(recorderViewModel.isRecording)
        XCTAssertEqual(recorderViewModel.currentTrigger, .default)
    }

    func test_handleKeyDown_deleteWithoutModifiers_resetsToDefaultAndStopsRecording() {
        // 先设为一个自定义快捷键
        preferencesViewModel.setHotKeyTrigger(.keyCombination(keyCode: UInt32(kVK_ANSI_V), modifiers: [.option]))
        XCTAssertEqual(recorderViewModel.currentTrigger, .keyCombination(keyCode: UInt32(kVK_ANSI_V), modifiers: [.option]))
        XCTAssertFalse(recorderViewModel.isDefaultHotKey)

        recorderViewModel.startRecording()
        let handled = recorderViewModel.handleKeyDown(keyCode: 51, modifierFlags: []) // Delete key
        XCTAssertTrue(handled)
        XCTAssertFalse(recorderViewModel.isRecording)
        XCTAssertEqual(recorderViewModel.currentTrigger, .default)
        XCTAssertTrue(recorderViewModel.isDefaultHotKey)
    }

    func test_handleKeyDown_forwardDeleteWithoutModifiers_resetsToDefaultAndStopsRecording() {
        preferencesViewModel.setHotKeyTrigger(.keyCombination(keyCode: UInt32(kVK_ANSI_V), modifiers: [.option]))
        recorderViewModel.startRecording()

        let handled = recorderViewModel.handleKeyDown(keyCode: 117, modifierFlags: []) // Forward Delete key
        XCTAssertTrue(handled)
        XCTAssertFalse(recorderViewModel.isRecording)
        XCTAssertEqual(recorderViewModel.currentTrigger, .default)
    }

    func test_handleKeyDown_validKeyCombination_updatesTriggerAndStopsRecording() {
        recorderViewModel.startRecording()

        // 模拟按下 ⌥V (keyCode 9, optionKey)
        let handled = recorderViewModel.handleKeyDown(keyCode: UInt16(kVK_ANSI_V), modifierFlags: .option)
        XCTAssertTrue(handled)
        XCTAssertFalse(recorderViewModel.isRecording)
        XCTAssertNil(recorderViewModel.errorMessage)

        let expected = HotKeyTrigger.keyCombination(keyCode: UInt32(kVK_ANSI_V), modifiers: [.option])
        XCTAssertEqual(recorderViewModel.currentTrigger, expected)
        XCTAssertEqual(preferencesViewModel.hotKeyTrigger, expected)
        XCTAssertEqual(mockPrefs.hotKeyTrigger, expected)
        XCTAssertEqual(mockHotKeyService.currentTrigger, expected)
    }

    func test_handleKeyDown_validMultipleModifiers_updatesTrigger() {
        recorderViewModel.startRecording()

        // 模拟按下 ⌘⇧V (Command + Shift + V)
        let handled = recorderViewModel.handleKeyDown(
            keyCode: UInt16(kVK_ANSI_V),
            modifierFlags: [.command, .shift]
        )
        XCTAssertTrue(handled)
        XCTAssertFalse(recorderViewModel.isRecording)

        let expected = HotKeyTrigger.keyCombination(keyCode: UInt32(kVK_ANSI_V), modifiers: [.command, .shift])
        XCTAssertEqual(recorderViewModel.currentTrigger, expected)
    }

    func test_handleKeyDown_validFunctionKeyWithoutModifiers_updatesTrigger() {
        recorderViewModel.startRecording()

        // 模拟按下 F1 (keyCode 122, no modifier)
        let handled = recorderViewModel.handleKeyDown(keyCode: UInt16(kVK_F1), modifierFlags: [])
        XCTAssertTrue(handled)
        XCTAssertFalse(recorderViewModel.isRecording)

        let expected = HotKeyTrigger.keyCombination(keyCode: UInt32(kVK_F1), modifiers: [])
        XCTAssertEqual(recorderViewModel.currentTrigger, expected)
    }

    func test_handleKeyDown_invalidSingleKeyWithoutModifiers_showsErrorAndRemainsRecording() {
        recorderViewModel.startRecording()

        // 模拟按下单字符 'A' 无修饰键 (keyCode 0)
        let handled = recorderViewModel.handleKeyDown(keyCode: UInt16(kVK_ANSI_A), modifierFlags: [])
        XCTAssertTrue(handled)
        XCTAssertTrue(recorderViewModel.isRecording) // 保持录制状态
        XCTAssertNotNil(recorderViewModel.errorMessage)
        XCTAssertEqual(recorderViewModel.shakeTrigger, 1)
        XCTAssertEqual(recorderViewModel.currentTrigger, .default) // 未被篡改
    }

    // MARK: - Dropdown & Direct Actions

    func test_selectDoubleTapModifier_updatesTriggerAndStopsRecording() {
        recorderViewModel.startRecording()

        recorderViewModel.selectDoubleTapModifier(.option)
        XCTAssertFalse(recorderViewModel.isRecording)
        XCTAssertEqual(recorderViewModel.currentTrigger, .doubleTap(modifier: .option))
        XCTAssertEqual(preferencesViewModel.hotKeyTrigger, .doubleTap(modifier: .option))
        XCTAssertEqual(mockHotKeyService.currentTrigger, .doubleTap(modifier: .option))
    }

    func test_resetToDefault_updatesTriggerAndStopsRecording() {
        preferencesViewModel.setHotKeyTrigger(.keyCombination(keyCode: 9, modifiers: [.option]))
        recorderViewModel.startRecording()

        recorderViewModel.resetToDefault()
        XCTAssertFalse(recorderViewModel.isRecording)
        XCTAssertEqual(recorderViewModel.currentTrigger, .default)
        XCTAssertEqual(mockHotKeyService.currentTrigger, .default)
    }
}
