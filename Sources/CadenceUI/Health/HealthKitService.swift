import Foundation
import CadenceCore

#if canImport(HealthKit)
import HealthKit

public final class HealthKitService: HealthService, @unchecked Sendable {
    private let store = HKHealthStore()
    private let calendar = Calendar.current

    public init() {}

    public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var stepCount: HKQuantityType { HKQuantityType(.stepCount) }
    private var activeEnergy: HKQuantityType { HKQuantityType(.activeEnergyBurned) }
    private var exerciseTime: HKQuantityType { HKQuantityType(.appleExerciseTime) }
    private var walkRunDistance: HKQuantityType { HKQuantityType(.distanceWalkingRunning) }
    private var restingHR: HKQuantityType { HKQuantityType(.restingHeartRate) }
    private var bodyMass: HKQuantityType { HKQuantityType(.bodyMass) }

    private var readTypes: Set<HKObjectType> {
        [stepCount, activeEnergy, exerciseTime, walkRunDistance, restingHR, bodyMass, HKObjectType.workoutType()]
    }

    private var writeTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), walkRunDistance, activeEnergy]
    }

    public func requestAuthorization() async throws {
        guard isAvailable else { throw HealthServiceError.unavailable }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    public func fetchRuns(since: Date?) async throws -> [Run] {
        guard isAvailable else { return [] }
        let type = HKObjectType.workoutType()
        var predicates = [HKQuery.predicateForWorkouts(with: .running)]
        if let since {
            predicates.append(HKQuery.predicateForSamples(withStart: since, end: nil))
        }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 500, sortDescriptors: [sort]) { _, samples, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: samples ?? []) }
            }
            store.execute(query)
        }

        return samples.compactMap { sample -> Run? in
            guard let workout = sample as? HKWorkout else { return nil }
            let meters = workout.statistics(for: walkRunDistance)?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            guard meters > 0 else { return nil }
            let source = workout.sourceRevision.source.name
            return Run(
                startedAt: workout.startDate,
                distanceMeters: meters,
                durationSeconds: workout.duration,
                notes: "\(Run.healthNotePrefix)\(source)",
                updatedAt: workout.endDate,
                healthKitID: workout.uuid
            )
        }
    }

    public func fetchDailyMetrics(days: Int) async throws -> [HealthDay] {
        guard isAvailable, days > 0 else { return [] }
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        async let steps = dailySums(stepCount, unit: .count(), from: start)
        async let energy = dailySums(activeEnergy, unit: .kilocalorie(), from: start)
        async let exercise = dailySums(exerciseTime, unit: .minute(), from: start)
        async let distance = dailySums(walkRunDistance, unit: .meter(), from: start)
        async let resting = dailyAverages(restingHR, unit: HKUnit.count().unitDivided(by: .minute()), from: start)
        async let mass = dailyLatest(bodyMass, unit: .gramUnit(with: .kilo), from: start)

        let (s, e, x, d, r, m) = try await (steps, energy, exercise, distance, resting, mass)

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return HealthDay(
                date: date,
                steps: s[date].map { Int($0.rounded()) },
                activeEnergyKcal: e[date],
                exerciseMinutes: x[date],
                distanceMeters: d[date],
                restingHeartRate: r[date],
                bodyMassKg: m[date]
            )
        }
    }

    private func dailySums(_ type: HKQuantityType, unit: HKUnit, from start: Date) async throws -> [Date: Double] {
        try await dailyStatistics(type, options: .cumulativeSum, from: start) { $0.sumQuantity()?.doubleValue(for: unit) }
    }

    private func dailyAverages(_ type: HKQuantityType, unit: HKUnit, from start: Date) async throws -> [Date: Double] {
        try await dailyStatistics(type, options: .discreteAverage, from: start) { $0.averageQuantity()?.doubleValue(for: unit) }
    }

    private func dailyStatistics(
        _ type: HKQuantityType,
        options: HKStatisticsOptions,
        from start: Date,
        value: @escaping @Sendable (HKStatistics) -> Double?
    ) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        let collection: HKStatisticsCollection? = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: start,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: collection) }
            }
            store.execute(query)
        }

        var result: [Date: Double] = [:]
        collection?.enumerateStatistics(from: start, to: Date()) { stats, _ in
            if let v = value(stats) {
                result[self.calendar.startOfDay(for: stats.startDate)] = v
            }
        }
        return result
    }

    private func dailyLatest(_ type: HKQuantityType, unit: HKUnit, from start: Date) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: samples ?? []) }
            }
            store.execute(query)
        }
        var result: [Date: Double] = [:]
        for case let sample as HKQuantitySample in samples {
            result[calendar.startOfDay(for: sample.startDate)] = sample.quantity.doubleValue(for: unit)
        }
        return result
    }

    public func saveWorkout(_ workout: Workout) async throws -> UUID {
        guard let end = workout.endedAt else { throw HealthServiceError.invalidWorkout }
        try ensureCanWrite(HKObjectType.workoutType())
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        return try await build(configuration: configuration, start: workout.startedAt, end: end, samples: [])
    }

    public func saveRun(_ run: Run) async throws -> UUID {
        try ensureCanWrite(HKObjectType.workoutType())
        let end = run.startedAt.addingTimeInterval(run.durationSeconds)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        var samples: [HKSample] = []
        if run.distanceMeters > 0, store.authorizationStatus(for: walkRunDistance) == .sharingAuthorized {
            samples.append(HKQuantitySample(
                type: walkRunDistance,
                quantity: HKQuantity(unit: .meter(), doubleValue: run.distanceMeters),
                start: run.startedAt,
                end: end
            ))
        }
        return try await build(configuration: configuration, start: run.startedAt, end: end, samples: samples)
    }

    private func ensureCanWrite(_ type: HKSampleType) throws {
        guard isAvailable else { throw HealthServiceError.unavailable }
        guard store.authorizationStatus(for: type) == .sharingAuthorized else { throw HealthServiceError.notAuthorized }
    }

    private func build(configuration: HKWorkoutConfiguration, start: Date, end: Date, samples: [HKSample]) async throws -> UUID {
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)
        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }
        try await builder.endCollection(at: end)
        guard let workout = try await builder.finishWorkout() else { throw HealthServiceError.invalidWorkout }
        return workout.uuid
    }
}
#endif
