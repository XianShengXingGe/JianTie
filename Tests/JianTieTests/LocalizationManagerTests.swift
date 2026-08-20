import XCTest
@testable import JianTieCore

@MainActor
final class LocalizationManagerTests: XCTestCase {
    private var testUserDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.jiantie.localization.\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: suiteName)
        testUserDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - AppLanguage Resolution Tests

    func test_appLanguage_resolveEffectiveLanguage_systemWithChinese() {
        let chineseVariants = [
            ["zh-Hans-CN", "en-US"],
            ["zh-Hant-TW", "en-US"],
            ["zh-HK", "en-US"],
            ["zh_CN", "en"],
            ["ZH-HANS"],
            ["zh"]
        ]

        for langs in chineseVariants {
            let resolved = AppLanguage.system.resolveEffectiveLanguage(preferredLanguages: langs)
            XCTAssertEqual(resolved, .zhHans, "Expected .zhHans for preferred languages: \(langs)")
        }
    }

    func test_appLanguage_resolveEffectiveLanguage_systemWithNonChinese() {
        let nonChineseVariants = [
            ["en-US", "zh-Hans-CN"],
            ["en-GB"],
            ["ja-JP", "en-US"],
            ["fr-FR"],
            ["de-DE"],
            []
        ]

        for langs in nonChineseVariants {
            let resolved = AppLanguage.system.resolveEffectiveLanguage(preferredLanguages: langs)
            XCTAssertEqual(resolved, .en, "Expected .en for preferred languages: \(langs)")
        }
    }

    func test_appLanguage_resolveEffectiveLanguage_explicitOverrides() {
        // Regardless of system preferences, explicit overrides must stay as selected
        let zhSystem = ["zh-Hans-CN"]
        let enSystem = ["en-US"]

        XCTAssertEqual(AppLanguage.zhHans.resolveEffectiveLanguage(preferredLanguages: enSystem), .zhHans)
        XCTAssertEqual(AppLanguage.en.resolveEffectiveLanguage(preferredLanguages: zhSystem), .en)
    }

    func test_appLanguage_displayNames() {
        XCTAssertEqual(AppLanguage.system.displayName, "跟随系统 (System Default)")
        XCTAssertEqual(AppLanguage.zhHans.displayName, "简体中文 (Simplified Chinese)")
        XCTAssertEqual(AppLanguage.en.displayName, "English")
    }

    // MARK: - LocalizationManager Tests

    func test_localizationManager_initializesWithPreferencesAndSystemLanguage() {
        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        prefs.appLanguage = .system

        let manager = LocalizationManager(
            preferences: prefs,
            preferredLanguagesProvider: { ["zh-Hans-CN"] }
        )

        XCTAssertEqual(manager.currentLanguage, .system)
        XCTAssertEqual(manager.effectiveLanguage, .zhHans)
        XCTAssertEqual(manager.string(forKey: "menu.about"), "关于 简贴")
        XCTAssertEqual(manager.string(forKey: "menu.preferences"), "偏好设置...")
        XCTAssertEqual(manager.string(forKey: "menu.quit"), "退出 简贴")
    }

    func test_localizationManager_englishResolution() {
        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        prefs.appLanguage = .system

        let manager = LocalizationManager(
            preferences: prefs,
            preferredLanguagesProvider: { ["en-US"] }
        )

        XCTAssertEqual(manager.currentLanguage, .system)
        XCTAssertEqual(manager.effectiveLanguage, .en)
        XCTAssertEqual(manager.string(forKey: "menu.about"), "About JianTie")
        XCTAssertEqual(manager.string(forKey: "menu.preferences"), "Preferences...")
        XCTAssertEqual(manager.string(forKey: "menu.quit"), "Quit JianTie")
    }

    func test_localizationManager_switchingLanguage_postsNotificationAndUpdatesStrings() {
        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        let manager = LocalizationManager(
            preferences: prefs,
            preferredLanguagesProvider: { ["zh-Hans-CN"] }
        )

        var notificationCount = 0
        let expectation = expectation(description: "Notification received")
        expectation.expectedFulfillmentCount = 2

        let observer = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // Switch to English
        manager.setLanguage(.en)
        XCTAssertEqual(manager.currentLanguage, .en)
        XCTAssertEqual(manager.effectiveLanguage, .en)
        XCTAssertEqual(prefs.appLanguage, .en)
        XCTAssertEqual(manager.string(forKey: "preferences.window_title"), "Preferences")

        // Switch to Simplified Chinese
        manager.setLanguage(.zhHans)
        XCTAssertEqual(manager.currentLanguage, .zhHans)
        XCTAssertEqual(manager.effectiveLanguage, .zhHans)
        XCTAssertEqual(prefs.appLanguage, .zhHans)
        XCTAssertEqual(manager.string(forKey: "preferences.window_title"), "偏好设置")

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(notificationCount, 2)
    }

    func test_localizationManager_fallbackForMissingKey() {
        let prefs = UserDefaultsPreferences(userDefaults: testUserDefaults)
        let manager = LocalizationManager(preferences: prefs)

        let missingKey = "non_existent_key_12345"
        XCTAssertEqual(manager.string(forKey: missingKey), missingKey)
    }
}
