import Foundation
import CadenceCore

public protocol HealthService: Sendable {
    var isAvailable: Bool { get }

    func requestAuthorization() async throws

    func fetchRuns(since: Date?) async throws -> [Run]

    func fetchDailyMetrics(days: Int) async throws -> [HealthDay]

    func saveWorkout(_ workout: Workout) async throws -> UUID

    func saveRun(_ run: Run) async throws -> UUID
}

public enum HealthServiceError: Error, LocalizedError, Sendable {
    case unavailable
    case notAuthorized
    case invalidWorkout

    public var errorDescription: String? {
        switch self {
        case .unavailable: "Apple Health isn't available on this device."
        case .notAuthorized: "Cadence doesn't have permission to write to Apple Health. You can change that in Settings → Health → Data Access & Devices."
        case .invalidWorkout: "This workout can't be saved to Health because it has no end time."
        }
    }
}

public struct PreviewHealthService: HealthService {
    public var isAvailable: Bool = true

    public init() {}

    public func requestAuthorization() async throws {}

    public func fetchRuns(since: Date?) async throws -> [Run] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return [3, 6].compactMap { daysAgo in
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                  let start = calendar.date(bySettingHour: 7, minute: 15, second: 0, of: day) else { return nil }
            return Run(
                startedAt: start,
                distanceMeters: daysAgo == 3 ? 5_120 : 8_300,
                durationSeconds: daysAgo == 3 ? 1_612 : 2_790,
                notes: "\(Run.healthNotePrefix)Apple Watch",
                updatedAt: start,
                healthKitID: UUID(uuidString: "A0000000-0000-0000-0000-00000000000\(daysAgo)")
            )
        }
    }

    public func fetchDailyMetrics(days: Int) async throws -> [HealthDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pattern: [(steps: Int, kcal: Double, minutes: Double)] = [
            (8_240, 512, 41), (11_930, 688, 63), (6_105, 402, 22), (9_870, 590, 48),
            (12_410, 731, 70), (4_320, 280, 12), (10_150, 615, 55),
        ]
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let p = pattern[offset % pattern.count]
            return HealthDay(
                date: date,
                steps: p.steps,
                activeEnergyKcal: p.kcal,
                exerciseMinutes: p.minutes,
                distanceMeters: Double(p.steps) * 0.78,
                restingHeartRate: 54 + Double(offset % 3),
                bodyMassKg: offset == 0 || offset == 4 ? 74.2 - Double(offset) * 0.05 : nil
            )
        }
    }

    public func saveWorkout(_ workout: Workout) async throws -> UUID { UUID() }
    public func saveRun(_ run: Run) async throws -> UUID { UUID() }
}

public struct UnavailableHealthService: HealthService {
    public var isAvailable: Bool { false }
    public init() {}
    public func requestAuthorization() async throws { throw HealthServiceError.unavailable }
    public func fetchRuns(since: Date?) async throws -> [Run] { [] }
    public func fetchDailyMetrics(days: Int) async throws -> [HealthDay] { [] }
    public func saveWorkout(_ workout: Workout) async throws -> UUID { throw HealthServiceError.unavailable }
    public func saveRun(_ run: Run) async throws -> UUID { throw HealthServiceError.unavailable }
}
