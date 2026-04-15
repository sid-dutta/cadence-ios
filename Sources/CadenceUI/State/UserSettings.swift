import Foundation
import CadenceCore

/// Non-synced preferences. Stored in `UserDefaults`; the auth token
/// deliberately lives elsewhere (see `TokenStore`).
public struct UserSettings: Codable, Equatable, Sendable {
    public var weightUnit: WeightUnit
    public var distanceUnit: DistanceUnit
    public var serverURLString: String
    public var accountEmail: String?

    public init(
        weightUnit: WeightUnit = .lb,
        distanceUnit: DistanceUnit = .mi,
        serverURLString: String = "http://localhost:8000",
        accountEmail: String? = nil
    ) {
        self.weightUnit = weightUnit
        self.distanceUnit = distanceUnit
        self.serverURLString = serverURLString
        self.accountEmail = accountEmail
    }

    public var serverURL: URL? {
        var trimmed = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.hasSuffix("/") { trimmed += "/" }
        return URL(string: trimmed)
    }
}

public protocol SettingsStore: Sendable {
    func load() -> UserSettings
    func save(_ settings: UserSettings)
}

/// `UserDefaults` is documented thread-safe but not marked `Sendable`.
public struct UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    private let key = "cadence.settings"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> UserSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONCoding.decode(UserSettings.self, from: data) else {
            return UserSettings()
        }
        return settings
    }

    public func save(_ settings: UserSettings) {
        if let data = try? JSONCoding.encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}

public final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var settings: UserSettings

    public init(settings: UserSettings = UserSettings()) {
        self.settings = settings
    }

    public func load() -> UserSettings { lock.withLock { settings } }
    public func save(_ settings: UserSettings) { lock.withLock { self.settings = settings } }
}
