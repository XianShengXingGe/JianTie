#if canImport(XCTest)
import XCTest
#endif
import Foundation

final class BundleLocalizationTests: XCTestCase {
    func test_infoPlist_hasChineseDisplayNameAndRequiredLocalizationKeys() throws {
        let repoRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // JianTieTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root

        let plistURL = repoRoot.appendingPathComponent("Sources/JianTieApp/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plistObj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = plistObj as? [String: Any] else {
            XCTFail("Failed to parse Info.plist as dictionary")
            return
        }

        XCTAssertEqual(dict["CFBundleDisplayName"] as? String, "简贴")
        XCTAssertEqual(dict["CFBundleName"] as? String, "简贴")
        XCTAssertEqual(dict["CFBundleDevelopmentRegion"] as? String, "zh_CN")
        XCTAssertEqual(dict["LSHasLocalizedDisplayName"] as? Bool, true)
        XCTAssertEqual(dict["CFBundleAllowMixedLocalizations"] as? Bool, true)
    }

    func test_infoPlistStrings_containsChineseDisplayName() throws {
        let repoRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let localizations = ["zh-Hans", "zh_CN", "en"]
        for loc in localizations {
            let stringsURL = repoRoot
                .appendingPathComponent("Sources/JianTieApp/Resources/\(loc).lproj/InfoPlist.strings")
            XCTAssertTrue(FileManager.default.fileExists(atPath: stringsURL.path), "InfoPlist.strings should exist for \(loc)")

            let content: String
            if let str16 = try? String(contentsOf: stringsURL, encoding: .utf16) {
                content = str16
            } else if let str8 = try? String(contentsOf: stringsURL, encoding: .utf8) {
                content = str8
            } else {
                content = try String(contentsOf: stringsURL)
            }
            XCTAssertTrue(content.contains("\"CFBundleDisplayName\" = \"简贴\";"), "CFBundleDisplayName should be 简贴 in \(loc)")
            XCTAssertTrue(content.contains("\"CFBundleName\" = \"简贴\";"), "CFBundleName should be 简贴 in \(loc)")
        }
    }
}
