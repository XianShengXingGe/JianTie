import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import JianTieCore

final class HotKeyValidationTests: XCTestCase {

    func test_validate_singleLetterWithoutModifier_isInvalid() {
        // 'A' (keyCode = 0) without modifiers -> Invalid
        let result = HotKeyValidator.validate(keyCode: 0, modifiers: [])
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, .modifierRequired)
    }

    func test_validate_letterWithModifier_isValid() {
        // ⌘V (keyCode = 9)
        let cmdV = HotKeyValidator.validate(keyCode: 9, modifiers: [.command])
        XCTAssertTrue(cmdV.isValid)
        XCTAssertNil(cmdV.error)

        // ⌥V
        let optV = HotKeyValidator.validate(keyCode: 9, modifiers: [.option])
        XCTAssertTrue(optV.isValid)

        // ⌃V
        let ctrlV = HotKeyValidator.validate(keyCode: 9, modifiers: [.control])
        XCTAssertTrue(ctrlV.isValid)

        // ⇧V
        let shiftV = HotKeyValidator.validate(keyCode: 9, modifiers: [.shift])
        XCTAssertTrue(shiftV.isValid)
    }

    func test_validate_functionKeyWithoutModifier_isValid() {
        // F1 = 122, F5 = 96, F12 = 111
        let f1 = HotKeyValidator.validate(keyCode: 122, modifiers: [])
        XCTAssertTrue(f1.isValid)

        let f5 = HotKeyValidator.validate(keyCode: 96, modifiers: [])
        XCTAssertTrue(f5.isValid)

        let f12 = HotKeyValidator.validate(keyCode: 111, modifiers: [])
        XCTAssertTrue(f12.isValid)
    }

    func test_validate_functionKeyWithModifier_isValid() {
        let optF1 = HotKeyValidator.validate(keyCode: 122, modifiers: [.option])
        XCTAssertTrue(optF1.isValid)

        let cmdF5 = HotKeyValidator.validate(keyCode: 96, modifiers: [.command])
        XCTAssertTrue(cmdF5.isValid)
    }

    func test_validate_specialStandaloneKeysWithoutModifier_isInvalid() {
        // Escape = 53
        let esc = HotKeyValidator.validate(keyCode: 53, modifiers: [])
        XCTAssertFalse(esc.isValid)
        XCTAssertEqual(esc.error, .modifierRequired)

        // Space = 49
        let space = HotKeyValidator.validate(keyCode: 49, modifiers: [])
        XCTAssertFalse(space.isValid)
        XCTAssertEqual(space.error, .modifierRequired)

        // Return = 36
        let ret = HotKeyValidator.validate(keyCode: 36, modifiers: [])
        XCTAssertFalse(ret.isValid)
        XCTAssertEqual(ret.error, .modifierRequired)

        // Tab = 48
        let tab = HotKeyValidator.validate(keyCode: 48, modifiers: [])
        XCTAssertFalse(tab.isValid)
        XCTAssertEqual(tab.error, .modifierRequired)

        // Delete = 51
        let del = HotKeyValidator.validate(keyCode: 51, modifiers: [])
        XCTAssertFalse(del.isValid)
        XCTAssertEqual(del.error, .modifierRequired)
    }

    func test_validate_trigger_enum() {
        let doubleTapTrigger = HotKeyTrigger.doubleTap(modifier: .command)
        XCTAssertTrue(HotKeyValidator.validate(trigger: doubleTapTrigger).isValid)

        let validComboTrigger = HotKeyTrigger.keyCombination(keyCode: 9, modifiers: [.option])
        XCTAssertTrue(HotKeyValidator.validate(trigger: validComboTrigger).isValid)

        let invalidComboTrigger = HotKeyTrigger.keyCombination(keyCode: 9, modifiers: [])
        XCTAssertFalse(HotKeyValidator.validate(trigger: invalidComboTrigger).isValid)
    }
}
