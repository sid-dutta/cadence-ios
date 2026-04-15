import Foundation
import CadenceCore

/// Non-synced preferences. Stored in `UserDefaults`; the auth token
/// deliberately lives elsewhere (see `TokenStore`).
public struct UserSettings: Codable, Equatable, Sendable {
    public var weightUnit: WeightUnit
    public var distanceUnit: DistanceUnit
    public var serverURLString: String
    public var accountEmail: String?
    /// The user has gone through the Health permission sheet at least once.
    public var healthConnected: Bool
    /// Write finished workouts and logged runs back to Apple Health.
    public var healthExportEnabled: Bool

    public init(
        weightUnit: WeightUnit = .lb,
        distanceUnit: DistanceUnit = .mi,
        serverURLString: String = "http://localhost:8000",
        accountEmail: String? = nil,
        healthConnected: Bool = false,
        healthExportEnabled: Bool = true
    ) {
        self.weightUnit = weightUnit
        self.distanceUnit = distanceUnit
        self.serverURLString = serverURLString
        self.accountEmail = accountEmail
        self.healthConnected = healthConnected
        self.healthExportEnabled = healthExportEnabled
    }

    // Older saved settings lack the health keys.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weightUnit = try c.decodeIfPresent(WeightUnit.self, forKey: .weightUnit) ?? .lb
        distanceUnit = try c.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnit) ?? .mi
        serverURLString = try c.decodeIfPresent(String.self, forKey: .serverURLString) ?? "http://localhost:8000"
        accountEmail = try c.decodeIfPresent(String.self, forKey: .accountEmail)
        healthConnected = try c.decodeIfPresent(Bool.self, forKey: .healthConnected) ?? false
        healthExportEnabled = try c.decodeIfPresent(Bool.self, forKey: .healthExportEnabled) ?? true
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
