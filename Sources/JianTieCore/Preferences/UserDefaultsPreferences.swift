import Foundation

/// 基于 UserDefaults 的应用偏好持久化实现
public final class UserDefaultsPreferences: PreferencesProviding, @unchecked Sendable {
    public static let shared = UserDefaultsPreferences()

    public enum Keys {
        public static let shelfEdge = "jiantie.shelf.edge"
        public static let clipboardCapacityLimit = "jiantie.clipboard.capacityLimit"
        public static let clipboardRetentionPeriod = "jiantie.clipboard.retentionPeriod"
    }

    private let userDefaults: UserDefaults
    private let lock = NSLock()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
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
}
