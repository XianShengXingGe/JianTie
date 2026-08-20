import Foundation
import Combine

public extension Notification.Name {
    /// 界面语言变更通知，触发全应用组件实时热重载
    static let appLanguageDidChange = Notification.Name("jiantie.appLanguageDidChange")
}

/// 集中化多语言管理服务，管理当前生效语言并提供实时动态本地化字符串解析
public final class LocalizationManager: ObservableObject, @unchecked Sendable {
    public static let shared = LocalizationManager()

    @Published public private(set) var currentLanguage: AppLanguage
    @Published public private(set) var effectiveLanguage: AppLanguage

    private let preferences: PreferencesProviding
    private let baseBundle: Bundle
    private let preferredLanguagesProvider: @Sendable () -> [String]
    private let lock = NSLock()
    private var activeBundle: Bundle?

    public init(
        preferences: PreferencesProviding = UserDefaultsPreferences.shared,
        baseBundle: Bundle? = nil,
        preferredLanguagesProvider: @escaping @Sendable () -> [String] = { Locale.preferredLanguages }
    ) {
        let bundle = baseBundle ?? Self.resolveDefaultBaseBundle()
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
    @MainActor
    public func setLanguage(_ language: AppLanguage) {
        guard currentLanguage != language else { return }
        self.currentLanguage = language
        self.preferences.appLanguage = language

        let effective = language.resolveEffectiveLanguage(preferredLanguages: preferredLanguagesProvider())
        self.effectiveLanguage = effective
        
        lock.lock()
        self.activeBundle = Self.loadSubBundle(for: effective, in: baseBundle)
        lock.unlock()

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
        lock.lock()
        let currentSubBundle = activeBundle
        lock.unlock()

        // 1. 从当前激活语言的 SubBundle 加载
        if let bundle = currentSubBundle {
            let localized = bundle.localizedString(forKey: key, value: "###_NOT_FOUND_###", table: nil)
            if localized != "###_NOT_FOUND_###" {
                return localized
            }
        }

        // 2. 尝试从 Base Bundle 加载
        let baseLocalized = baseBundle.localizedString(forKey: key, value: "###_NOT_FOUND_###", table: nil)
        if baseLocalized != "###_NOT_FOUND_###" {
            return baseLocalized
        }

        // 3. 尝试从 Bundle.main 直接加载
        let main = Bundle.main
        if main != baseBundle {
            let mainLocalized = main.localizedString(forKey: key, value: "###_NOT_FOUND_###", table: nil)
            if mainLocalized != "###_NOT_FOUND_###" {
                return mainLocalized
            }
        }

        return key
    }

    /// 格式化带有动态参数的本地化文案
    public func localizedString(forKey key: String, _ arguments: CVarArg...) -> String {
        let format = string(forKey: key)
        return String(format: format, arguments: arguments)
    }

    /// 自动推断当前环境下的基准资源 Bundle
    public static func resolveDefaultBaseBundle() -> Bundle {
        let main = Bundle.main
        // 1. 尝试从 main.resourceURL 获取 JianTie_JianTieCore.bundle
        if let resURL = main.resourceURL {
            let coreBundleURL = resURL.appendingPathComponent("JianTie_JianTieCore.bundle")
            if let bundle = Bundle(url: coreBundleURL) {
                return bundle
            }
        }
        if let corePath = main.path(forResource: "JianTie_JianTieCore", ofType: "bundle"),
           let bundle = Bundle(path: corePath) {
            return bundle
        }
        // 2. 检查 main bundle 是否直接包含语言包
        if main.path(forResource: "zh-Hans", ofType: "lproj") != nil ||
           main.path(forResource: "zh-hans", ofType: "lproj") != nil ||
           main.path(forResource: "en", ofType: "lproj") != nil {
            return main
        }
        // 3. 回退到 SPM Bundle.module
        return Bundle.module
    }

    private static func loadSubBundle(for language: AppLanguage, in baseBundle: Bundle) -> Bundle? {
        let candidates: [String]
        switch language {
        case .zhHans:
            candidates = ["zh-Hans", "zh-hans", "zh_CN", "zh_cn", "zh-CN", "zh", "Base"]
        case .en:
            candidates = ["en", "en-US", "en_US", "en-GB", "Base"]
        case .system:
            candidates = ["zh-Hans", "zh-hans", "zh_CN", "en", "Base"]
        }

        // 1. 在 baseBundle 内部尝试所有候选语言标识
        for code in candidates {
            if let path = baseBundle.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
            if let url = baseBundle.url(forResource: code, withExtension: "lproj"),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }

        // 2. 在 Bundle.main 及其 resourceURL 中尝试所有候选语言标识
        let main = Bundle.main
        if main != baseBundle {
            for code in candidates {
                if let path = main.path(forResource: code, ofType: "lproj"),
                   let bundle = Bundle(path: path) {
                    return bundle
                }
                if let url = main.resourceURL?.appendingPathComponent("\(code).lproj"),
                   FileManager.default.fileExists(atPath: url.path),
                   let bundle = Bundle(url: url) {
                    return bundle
                }
            }
        }

        return nil
    }
}

/// 快速本地化访问门面
public enum L10n {
    public static func tr(_ key: String, _ args: CVarArg...) -> String {
        if args.isEmpty {
            return LocalizationManager.shared.string(forKey: key)
        } else {
            let format = LocalizationManager.shared.string(forKey: key)
            return String(format: format, arguments: args)
        }
    }
}
