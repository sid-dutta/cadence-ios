import Foundation

public struct PersonalRecord: Identifiable, Hashable, Sendable {
    public let exerciseName: String
    public let muscleGroup: MuscleGroup
    public let weightKg: Double
    public let reps: Int
    public let estimatedOneRepMaxKg: Double
    public let achievedAt: Date
    public let workoutID: UUID

    public init(
        exerciseName: String,
        muscleGroup: MuscleGroup,
        weightKg: Double,
        reps: Int,
        estimatedOneRepMaxKg: Double,
        achievedAt: Date,
        workoutID: UUID
    ) {
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.weightKg = weightKg
        self.reps = reps
        self.estimatedOneRepMaxKg = estimatedOneRepMaxKg
        self.achievedAt = achievedAt
        self.workoutID = workoutID
    }

    public var id: String { StatsEngine.normalize(exerciseName) }
}

public struct WeeklySummary: Identifiable, Hashable, Sendable {
    public let weekStart: Date
    public let workoutCount: Int
    public let volumeKg: Double
    public let runCount: Int
    public let runDistanceMeters: Double
    public let runDurationSeconds: TimeInterval

    public var id: Date { weekStart }

    public var hasActivity: Bool { workoutCount > 0 || runCount > 0 }

    public var averagePaceSecondsPerKm: Double? {
        guard runDistanceMeters > 0 else { return nil }
        return runDurationSeconds / (runDistanceMeters / 1000)
    }
}

public struct ExerciseDataPoint: Identifiable, Hashable, Sendable {
    public let date: Date
    public let bestOneRepMaxKg: Double
    public let topWeightKg: Double
    public let volumeKg: Double
    public let workoutID: UUID

    public var id: UUID { workoutID }
}

public enum StatsEngine {

    // Epley: w * (1 + r/30). One rep is by definition the 1RM.
    public static func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double {
        guard weightKg > 0, reps > 0 else { return 0 }
        guard reps > 1 else { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }

    public static func personalRecords(in workouts: [Workout]) -> [PersonalRecord] {
        var best: [String: PersonalRecord] = [:]

        for workout in workouts where !workout.isDeleted {
            for exercise in workout.exercises {
                for set in exercise.completedSets where set.weightKg > 0 && set.reps > 0 {
                    let key = normalize(exercise.name)
                    let candidate = PersonalRecord(
                        exerciseName: exercise.name,
                        muscleGroup: exercise.muscleGroup,
                        weightKg: set.weightKg,
                        reps: set.reps,
                        estimatedOneRepMaxKg: set.estimatedOneRepMaxKg,
                        achievedAt: workout.startedAt,
                        workoutID: workout.id
                    )
                    if let existing = best[key] {
                        let isBetter = candidate.estimatedOneRepMaxKg > existing.estimatedOneRepMaxKg
                            || (candidate.estimatedOneRepMaxKg == existing.estimatedOneRepMaxKg
                                && candidate.achievedAt < existing.achievedAt)
                        if isBetter { best[key] = candidate }
                    } else {
                        best[key] = candidate
                    }
                }
            }
        }

        return best.values.sorted { $0.estimatedOneRepMaxKg > $1.estimatedOneRepMaxKg }
    }

    public static func isPersonalRecord(
        _ set: ExerciseSet,
        exerciseName: String,
        history: [Workout],
        excludingWorkoutID: UUID? = nil
    ) -> Bool {
        guard set.weightKg > 0, set.reps > 0 else { return false }
        let priorBest = bestOneRepMax(exerciseName: exerciseName, in: history, excludingWorkoutID: excludingWorkoutID)
        return set.estimatedOneRepMaxKg > priorBest
    }

    public static func bestOneRepMax(
        exerciseName: String,
        in history: [Workout],
        excludingWorkoutID: UUID? = nil
    ) -> Double {
        let key = normalize(exerciseName)
        return history
            .filter { !$0.isDeleted && $0.id != excludingWorkoutID }
            .flatMap(\.exercises)
            .filter { normalize($0.name) == key }
            .flatMap(\.completedSets)
            .map(\.estimatedOneRepMaxKg)
            .max() ?? 0
    }

    public static func recordSet(in exercise: Exercise, history: [Workout], excludingWorkoutID: UUID? = nil) -> ExerciseSet? {
        let priorBest = bestOneRepMax(exerciseName: exercise.name, in: history, excludingWorkoutID: excludingWorkoutID)
        return exercise.completedSets
            .filter { $0.weightKg > 0 && $0.reps > 0 && $0.estimatedOneRepMaxKg > priorBest }
            .max { $0.estimatedOneRepMaxKg < $1.estimatedOneRepMaxKg }
    }

    public static func exerciseHistory(name: String, in workouts: [Workout]) -> [ExerciseDataPoint] {
        let key = normalize(name)
        return workouts
            .filter { !$0.isDeleted && !$0.isActive }
            .compactMap { workout -> ExerciseDataPoint? in
                let sets = workout.exercises
                    .filter { normalize($0.name) == key }
                    .flatMap(\.completedSets)
                    .filter { $0.weightKg > 0 && $0.reps > 0 }
                guard let best = sets.max(by: { $0.estimatedOneRepMaxKg < $1.estimatedOneRepMaxKg }) else {
                    return nil
                }
                return ExerciseDataPoint(
                    date: workout.startedAt,
                    bestOneRepMaxKg: best.estimatedOneRepMaxKg,
                    topWeightKg: sets.map(\.weightKg).max() ?? 0,
                    volumeKg: sets.reduce(0) { $0 + $1.volumeKg },
                    workoutID: workout.id
                )
            }
            .sorted { $0.date < $1.date }
    }

    public static func trackedExerciseNames(in workouts: [Workout]) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for workout in workouts.filter({ !$0.isDeleted }).sorted(by: { $0.startedAt > $1.startedAt }) {
            for exercise in workout.exercises where !exercise.completedSets.isEmpty {
                if seen.insert(normalize(exercise.name)).inserted {
                    names.append(exercise.name)
                }
            }
        }
        return names
    }

    public static func weeklySummaries(
        workouts: [Workout],
        runs: [Run],
        weeks: Int,
        endingAt: Date = Date(),
        calendar: Calendar = .current
    ) -> [WeeklySummary] {
        guard weeks > 0 else { return [] }
        let currentWeekStart = startOfWeek(containing: endingAt, calendar: calendar)
        let weekStarts: [Date] = (0..<weeks).reversed().compactMap {
            calendar.date(byAdding: .weekOfYear, value: -$0, to: currentWeekStart)
        }

        return weekStarts.map { weekStart in
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
            let range = weekStart..<weekEnd

            let weekWorkouts = workouts.filter { !$0.isDeleted && !$0.isActive && range.contains($0.startedAt) }
            let weekRuns = runs.filter { !$0.isDeleted && range.contains($0.startedAt) }

            return WeeklySummary(
                weekStart: weekStart,
                workoutCount: weekWorkouts.count,
                volumeKg: weekWorkouts.reduce(0) { $0 + $1.totalVolumeKg },
                runCount: weekRuns.count,
                runDistanceMeters: weekRuns.reduce(0) { $0 + $1.distanceMeters },
                runDurationSeconds: weekRuns.reduce(0) { $0 + $1.durationSeconds }
            )
        }
    }

    public static func currentStreak(
        workouts: [Workout],
        runs: [Run],
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let activeWeeks = Set(
            workouts.filter { !$0.isDeleted && !$0.isActive }.map { startOfWeek(containing: $0.startedAt, calendar: calendar) }
            + runs.filter { !$0.isDeleted }.map { startOfWeek(containing: $0.startedAt, calendar: calendar) }
        )
        guard !activeWeeks.isEmpty else { return 0 }

        var cursor = startOfWeek(containing: asOf, calendar: calendar)
        if !activeWeeks.contains(cursor) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }

        var streak = 0
        while activeWeeks.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    public static func fastestRun(in runs: [Run], minimumDistanceMeters: Double = 1000) -> Run? {
        runs.filter { !$0.isDeleted && $0.distanceMeters >= minimumDistanceMeters }
            .min { ($0.paceSecondsPerKm ?? .infinity) < ($1.paceSecondsPerKm ?? .infinity) }
    }

    public static func longestRun(in runs: [Run]) -> Run? {
        runs.filter { !$0.isDeleted }.max { $0.distanceMeters < $1.distanceMeters }
    }

    public static func totalDistanceMeters(in runs: [Run]) -> Double {
        runs.filter { !$0.isDeleted }.reduce(0) { $0 + $1.distanceMeters }
    }

    public static func startOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
