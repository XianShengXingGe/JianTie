import Foundation
import Combine

public extension Notification.Name {
    /// 界面语言变更通知，触发全应用组件实时热重载
    static let appLanguageDidChange = Notification.Name("jiantie.appLanguageDidChange")
}

/// 集中化多语言管理服务，管理当前生效语言并提供实时动态本地化字符串解析
@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    @Published public private(set) var currentLanguage: AppLanguage
    @Published public private(set) var effectiveLanguage: AppLanguage

    private let preferences: PreferencesProviding
    private let baseBundle: Bundle
    private let preferredLanguagesProvider: () -> [String]
    private var activeBundle: Bundle?

    public init(
        preferences: PreferencesProviding = UserDefaultsPreferences.shared,
        baseBundle: Bundle? = nil,
        preferredLanguagesProvider: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        let bundle = baseBundle ?? Bundle.module
        self.preferences = preferences
        self.baseBundle = bundle
        self.preferredLanguagesProvider = preferredLanguagesProvider

        let initialLanguage = preferences.appLanguage
        self.currentLanguage = initialLanguage
        let effective = initialLanguage.resolveEffectiveLanguage(preferredLanguages: preferredLanguagesProvider())
        self.effectiveLanguage = effective
        self.activeBundle = Self.loadSubBundle(for: effective, in: bundle)
    }

    /// 切换应用界面语言，并即时同步到偏好持久化与广播通知
    public func setLanguage(_ language: AppLanguage) {
        guard currentLanguage != language else { return }
        self.currentLanguage = language
        self.preferences.appLanguage = language

        let effective = language.resolveEffectiveLanguage(preferredLanguages: preferredLanguagesProvider())
        self.effectiveLanguage = effective
        self.activeBundle = Self.loadSubBundle(for: effective, in: baseBundle)

        NotificationCenter.default.post(
            name: .appLanguageDidChange,
            object: self,
            userInfo: [
                "language": language,
                "effectiveLanguage": effective
            ]
        )
    }

    /// 获取指定 Key 的本地化文案，支持未命中时回退到默认语言及原始 Key
    public func string(forKey key: String, comment: String = "") -> String {
        if let bundle = activeBundle {
            let localized = bundle.localizedString(forKey: key, value: "###_NOT_FOUND_###", table: nil)
            if localized != "###_NOT_FOUND_###" {
                return localized
            }
        }

        // 尝试从 Base Bundle 加载
        let baseLocalized = baseBundle.localizedString(forKey: key, value: "###_NOT_FOUND_###", table: nil)
        if baseLocalized != "###_NOT_FOUND_###" {
            return baseLocalized
        }

        return key
    }

    /// 格式化带有动态参数的本地化文案
    public func localizedString(forKey key: String, _ arguments: CVarArg...) -> String {
        let format = string(forKey: key)
        return String(format: format, arguments: arguments)
    }

    private static func loadSubBundle(for language: AppLanguage, in baseBundle: Bundle) -> Bundle? {
        let langCode = language == .zhHans ? "zh-Hans" : "en"
        if let path = baseBundle.path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return nil
    }
}

/// 快速本地化访问门面
public enum L10n {
    @MainActor
    public static func tr(_ key: String, _ args: CVarArg...) -> String {
        if args.isEmpty {
            return LocalizationManager.shared.string(forKey: key)
        } else {
            let format = LocalizationManager.shared.string(forKey: key)
            return String(format: format, arguments: args)
        }
    }
}
