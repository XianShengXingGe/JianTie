import XCTest
@testable import JianTieCore

final class HotKeyTriggerTests: XCTestCase {

    // MARK: - ModifierKey Tests

    func test_modifierKey_symbolsAndTitles() {
        XCTAssertEqual(ModifierKey.command.symbol, "⌘")
        XCTAssertEqual(ModifierKey.option.symbol, "⌥")
        XCTAssertEqual(ModifierKey.control.symbol, "⌃")
        XCTAssertEqual(ModifierKey.shift.symbol, "⇧")

        XCTAssertEqual(ModifierKey.command.doubleTapTitle, "双击 ⌘")
        XCTAssertEqual(ModifierKey.option.doubleTapTitle, "双击 ⌥")
        XCTAssertEqual(ModifierKey.control.doubleTapTitle, "双击 ⌃")
        XCTAssertEqual(ModifierKey.shift.doubleTapTitle, "双击 ⇧")

        XCTAssertEqual(ModifierKey.allCases, [.command, .option, .control, .shift])
    }

    // MARK: - KeyModifiers Tests

    func test_keyModifiers_displaySymbols_order() {
        let all: KeyModifiers = [.command, .option, .control, .shift]
        XCTAssertEqual(all.displaySymbols, "⌃⌥⇧⌘")

        let optCmd: KeyModifiers = [.option, .command]
        XCTAssertEqual(optCmd.displaySymbols, "⌥⌘")

        let ctrlShift: KeyModifiers = [.control, .shift]
        XCTAssertEqual(ctrlShift.displaySymbols, "⌃⇧")

        let empty: KeyModifiers = []
        XCTAssertEqual(empty.displaySymbols, "")
    }

    func test_keyModifiers_carbonFlags() {
        let cmd: KeyModifiers = [.command]
        XCTAssertEqual(cmd.carbonModifierFlags, 256) // cmdKey

        let opt: KeyModifiers = [.option]
        XCTAssertEqual(opt.carbonModifierFlags, 2048) // optionKey

        let ctrl: KeyModifiers = [.control]
        XCTAssertEqual(ctrl.carbonModifierFlags, 4096) // controlKey

        let shift: KeyModifiers = [.shift]
        XCTAssertEqual(shift.carbonModifierFlags, 512) // shiftKey

        let combo: KeyModifiers = [.command, .shift]
        XCTAssertEqual(combo.carbonModifierFlags, 256 | 512)
    }

    // MARK: - KeyCodeHelper Tests

    func test_keyCodeHelper_alphanumericAndFunctions() {
        // ANSI key codes: V = 9, C = 8, A = 0, 1 = 18, Space = 49
        XCTAssertEqual(KeyCodeHelper.title(for: 9), "V")
        XCTAssertEqual(KeyCodeHelper.title(for: 8), "C")
        XCTAssertEqual(KeyCodeHelper.title(for: 0), "A")
        XCTAssertEqual(KeyCodeHelper.title(for: 18), "1")
        XCTAssertEqual(KeyCodeHelper.title(for: 49), "Space")

        // Function keys: F1 = 122, F5 = 96, F12 = 111
        XCTAssertEqual(KeyCodeHelper.title(for: 122), "F1")
        XCTAssertEqual(KeyCodeHelper.title(for: 96), "F5")
        XCTAssertEqual(KeyCodeHelper.title(for: 111), "F12")
    }

    // MARK: - HotKeyTrigger Display Title Tests

    func test_hotKeyTrigger_displayTitle() {
        let doubleTapCmd = HotKeyTrigger.doubleTap(modifier: .command)
        XCTAssertEqual(doubleTapCmd.displayTitle, "双击 ⌘")

        let doubleTapOpt = HotKeyTrigger.doubleTap(modifier: .option)
        XCTAssertEqual(doubleTapOpt.displayTitle, "双击 ⌥")

        // ⌥V (V = 9)
        let optV = HotKeyTrigger.keyCombination(keyCode: 9, modifiers: [.option])
        XCTAssertEqual(optV.displayTitle, "⌥V")

        // ⌘⇧V
        let cmdShiftV = HotKeyTrigger.keyCombination(keyCode: 9, modifiers: [.command, .shift])
        XCTAssertEqual(cmdShiftV.displayTitle, "⇧⌘V")

        // F1 (F1 = 122)
        let f1 = HotKeyTrigger.keyCombination(keyCode: 122, modifiers: [])
        XCTAssertEqual(f1.displayTitle, "F1")

        // ⌥F5
        let optF5 = HotKeyTrigger.keyCombination(keyCode: 96, modifiers: [.option])
        XCTAssertEqual(optF5.displayTitle, "⌥F5")
    }

    // MARK: - Codable Tests

    func test_hotKeyTrigger_codableRoundtrip_doubleTap() throws {
        let trigger = HotKeyTrigger.doubleTap(modifier: .option)
        let encoder = JSONEncoder()
        let data = try encoder.encode(trigger)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HotKeyTrigger.self, from: data)

        XCTAssertEqual(decoded, trigger)
    }

    func test_hotKeyTrigger_codableRoundtrip_keyCombination() throws {
        let trigger = HotKeyTrigger.keyCombination(keyCode: 9, modifiers: [.command, .shift])
        let encoder = JSONEncoder()
        let data = try encoder.encode(trigger)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HotKeyTrigger.self, from: data)

        XCTAssertEqual(decoded, trigger)
    }

    func test_hotKeyTrigger_defaultValue() {
        XCTAssertEqual(HotKeyTrigger.default, .doubleTap(modifier: .command))
    }
}
