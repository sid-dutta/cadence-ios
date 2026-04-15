import Foundation

public struct HealthDay: Identifiable, Codable, Hashable, Sendable {
    public var date: Date
    public var steps: Int?
    public var activeEnergyKcal: Double?
    public var exerciseMinutes: Double?
    public var distanceMeters: Double?
    public var restingHeartRate: Double?
    public var bodyMassKg: Double?

    public var id: Date { date }

    public init(
        date: Date,
        steps: Int? = nil,
        activeEnergyKcal: Double? = nil,
        exerciseMinutes: Double? = nil,
        distanceMeters: Double? = nil,
        restingHeartRate: Double? = nil,
        bodyMassKg: Double? = nil
    ) {
        self.date = date
        self.steps = steps
        self.activeEnergyKcal = activeEnergyKcal
        self.exerciseMinutes = exerciseMinutes
        self.distanceMeters = distanceMeters
        self.restingHeartRate = restingHeartRate
        self.bodyMassKg = bodyMassKg
    }

    public var isEmpty: Bool {
        steps == nil && activeEnergyKcal == nil && exerciseMinutes == nil
            && distanceMeters == nil && restingHeartRate == nil && bodyMassKg == nil
    }
}

public enum HealthStats {

    public static func day(_ date: Date, in days: [HealthDay], calendar: Calendar = .current) -> HealthDay? {
        let start = calendar.startOfDay(for: date)
        return days.first { calendar.isDate($0.date, inSameDayAs: start) }
    }

    public static func series(
        _ days: [HealthDay],
        lastDays count: Int,
        endingAt end: Date = Date(),
        calendar: Calendar = .current
    ) -> [HealthDay] {
        guard count > 0 else { return [] }
        let today = calendar.startOfDay(for: end)
        let byDay = Dictionary(days.map { (calendar.startOfDay(for: $0.date), $0) }, uniquingKeysWith: { _, new in new })
        return (0..<count).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return byDay[date] ?? HealthDay(date: date)
        }
    }

    public static func totalSteps(_ days: [HealthDay]) -> Int {
        days.reduce(0) { $0 + ($1.steps ?? 0) }
    }

    public static func averageSteps(_ days: [HealthDay]) -> Int {
        let withData = days.filter { $0.steps != nil }
        guard !withData.isEmpty else { return 0 }
        return totalSteps(withData) / withData.count
    }

    public static func totalActiveEnergy(_ days: [HealthDay]) -> Double {
        days.reduce(0) { $0 + ($1.activeEnergyKcal ?? 0) }
    }

    public static func totalExerciseMinutes(_ days: [HealthDay]) -> Double {
        days.reduce(0) { $0 + ($1.exerciseMinutes ?? 0) }
    }

    public static func latestBodyMassKg(_ days: [HealthDay]) -> Double? {
        days.sorted { $0.date > $1.date }.first { $0.bodyMassKg != nil }?.bodyMassKg
    }

    public static func averageRestingHeartRate(_ days: [HealthDay]) -> Double? {
        let values = days.compactMap(\.restingHeartRate)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

public enum HealthImport {

    public static func merge(imported: [Run], into existing: [Run]) -> (runs: [Run], added: Int) {
        let known = Set(existing.compactMap(\.healthKitID))
        let fresh = imported.filter { run in
            guard let id = run.healthKitID else { return false }
            return !known.contains(id)
        }
        return (existing + fresh, fresh.count)
    }

    public static func mergeDays(fetched: [HealthDay], into existing: [HealthDay], calendar: Calendar = .current) -> [HealthDay] {
        var byDay = Dictionary(existing.map { (calendar.startOfDay(for: $0.date), $0) }, uniquingKeysWith: { _, new in new })
        for day in fetched {
            byDay[calendar.startOfDay(for: day.date)] = day
        }
        return byDay.values.sorted { $0.date < $1.date }
    }
}
