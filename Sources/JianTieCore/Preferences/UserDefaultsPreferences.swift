import Foundation

/// 基于 UserDefaults 的应用偏好持久化实现
public final class UserDefaultsPreferences: PreferencesProviding, @unchecked Sendable {
    public static let shared = UserDefaultsPreferences()

    public enum Keys {
        public static let shelfEdge = "jiantie.shelf.edge"
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
}
