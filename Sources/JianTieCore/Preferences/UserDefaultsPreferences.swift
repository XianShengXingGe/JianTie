//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Foundation

/// 基于 UserDefaults 的应用偏好持久化实现
public final class UserDefaultsPreferences: PreferencesProviding, @unchecked Sendable {
    public static let shared = UserDefaultsPreferences()

    public enum Keys {
        public static let launchAtLogin = "jiantie.general.launchAtLogin"
        public static let hasConfiguredLaunchAtLogin = "jiantie.general.hasConfiguredLaunchAtLogin"
        public static let hotKeyTrigger = "jiantie.hotkey.trigger"
        public static let shelfEdge = "jiantie.shelf.edge"
        public static let shelfVerticalPercent = "jiantie.shelf.verticalPercent"
        public static let clipboardCapacityLimit = "jiantie.clipboard.capacityLimit"
        public static let clipboardRetentionPeriod = "jiantie.clipboard.retentionPeriod"
        public static let appLanguage = "jiantie.general.appLanguage"
    }

    private let userDefaults: UserDefaults
    private let lock = NSLock()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var launchAtLogin: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard userDefaults.object(forKey: Keys.launchAtLogin) != nil else {
                return true
            }
            return userDefaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }

    public var hasConfiguredLaunchAtLogin: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return userDefaults.bool(forKey: Keys.hasConfiguredLaunchAtLogin)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue, forKey: Keys.hasConfiguredLaunchAtLogin)
        }
    }

    public var hotKeyTrigger: HotKeyTrigger {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let data = userDefaults.data(forKey: Keys.hotKeyTrigger) else {
                return .default
            }
            do {
                return try JSONDecoder().decode(HotKeyTrigger.self, from: data)
            } catch {
                return .default
            }
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: Keys.hotKeyTrigger)
            }
        }
    }

    public var shelfEdge: ShelfEdge {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let rawValue = userDefaults.string(forKey: Keys.shelfEdge),
                  let edge = ShelfEdge(rawValue: rawValue) else {
                return .left
            }
            return edge
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue.rawValue, forKey: Keys.shelfEdge)
        }
    }

    public var shelfVerticalPercent: Double {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard userDefaults.object(forKey: Keys.shelfVerticalPercent) != nil else {
                return 0.5
            }
            return userDefaults.double(forKey: Keys.shelfVerticalPercent)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue, forKey: Keys.shelfVerticalPercent)
        }
    }

    public var clipboardCapacityLimit: ClipboardCapacityLimit {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard userDefaults.object(forKey: Keys.clipboardCapacityLimit) != nil else {
                return .count1000
            }
            let rawValue = userDefaults.integer(forKey: Keys.clipboardCapacityLimit)
            return ClipboardCapacityLimit(rawValue: rawValue) ?? .count1000
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue.rawValue, forKey: Keys.clipboardCapacityLimit)
        }
    }

    public var clipboardRetentionPeriod: ClipboardRetentionPeriod {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard userDefaults.object(forKey: Keys.clipboardRetentionPeriod) != nil else {
                return .unlimited
            }
            let rawValue = userDefaults.integer(forKey: Keys.clipboardRetentionPeriod)
            return ClipboardRetentionPeriod(rawValue: rawValue) ?? .unlimited
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue.rawValue, forKey: Keys.clipboardRetentionPeriod)
        }
    }

    public var appLanguage: AppLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let rawValue = userDefaults.string(forKey: Keys.appLanguage),
                  let language = AppLanguage(rawValue: rawValue) else {
                return .system
            }
            return language
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue.rawValue, forKey: Keys.appLanguage)
        }
    }
}
