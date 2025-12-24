import Foundation

/// Lightweight cache entry carrying the stored value plus freshness metadata.
struct CachedEntry<Value: Codable>: Codable {
    var value: Value
    var updatedAt: Date

    /// Indicates whether the entry is still considered fresh for the provided TTL window.
    func isFresh(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(updatedAt) < ttl
    }
}

/// Centralised per-user cache used by repositories to persist the last known server snapshot.
/// Persists small payloads in `UserDefaults` (namespaced by user e-mail) to guarantee immediate reads
/// during cold start, while `DataLayer`/SwiftData continue to manage heavier artefacts.
@MainActor
final class UserContextStore {
    static let shared = UserContextStore()

    private let defaults: UserDefaults
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    func load<Value: Codable>(_ type: Value.Type, for key: UserScopedKey) -> CachedEntry<Value>? {
        guard let data = defaults.data(forKey: key.storageKey) else { return nil }
        return try? jsonDecoder.decode(CachedEntry<Value>.self, from: data)
    }

    func save<Value: Codable>(_ entry: CachedEntry<Value>, for key: UserScopedKey) {
        guard let data = try? jsonEncoder.encode(entry) else { return }
        defaults.set(data, forKey: key.storageKey)
    }

    func clear(for key: UserScopedKey) {
        defaults.removeObject(forKey: key.storageKey)
    }

    func clearAll(for email: String) {
        let prefix = "pods.usercontext.\(email)."
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Wrapper used to build namespaced keys for a given user and domain.
struct UserScopedKey: Hashable {
    let email: String
    let domain: Domain

    enum Domain: String {
        case profile
        case subscription
        case foodFeed
        case dayLogs
        case health
        case startupState
        case combinedLogs
        case meals
        case recipes
        case savedMeals
        case savedFoods
        case savedRecipes
        case userFoods
        case recentFoodLogs
        case workoutContext
    }

    var storageKey: String { "pods.usercontext.\(email).\(domain.rawValue)" }
}
