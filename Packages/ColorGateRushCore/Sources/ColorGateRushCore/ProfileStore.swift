import Foundation

/// Minimal key/value persistence so the store can be backed by UserDefaults in the app
/// and by memory in tests.
protocol KeyValueStore: AnyObject {
    func loadData(forKey key: String) -> Data?
    func saveData(_ data: Data?, forKey key: String)
}

extension UserDefaults: KeyValueStore {
    func loadData(forKey key: String) -> Data? {
        data(forKey: key)
    }

    func saveData(_ data: Data?, forKey key: String) {
        if let data {
            set(data, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}

final class InMemoryStore: KeyValueStore {
    private var storage: [String: Data] = [:]

    func loadData(forKey key: String) -> Data? {
        storage[key]
    }

    func saveData(_ data: Data?, forKey key: String) {
        storage[key] = data
    }
}

/// Loads and saves the player profile as JSON. Unreadable data is preserved under a
/// backup key instead of being silently destroyed, and a fresh profile is returned.
struct ProfileStore {
    static let profileKey = "colorgaterush.profile"
    static let corruptBackupKey = "colorgaterush.profile.corrupt"

    let store: KeyValueStore

    func load() -> PlayerProfile {
        guard let data = store.loadData(forKey: Self.profileKey) else { return PlayerProfile() }
        do {
            var profile = try JSONDecoder().decode(PlayerProfile.self, from: data)
            profile.sanitize()
            return profile
        } catch {
            store.saveData(data, forKey: Self.corruptBackupKey)
            return PlayerProfile()
        }
    }

    @discardableResult
    func save(_ profile: PlayerProfile) -> Bool {
        do {
            let data = try JSONEncoder().encode(profile)
            store.saveData(data, forKey: Self.profileKey)
            return true
        } catch {
            return false
        }
    }

    func reset() {
        store.saveData(nil, forKey: Self.profileKey)
    }
}
