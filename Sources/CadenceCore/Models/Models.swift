import Foundation

// MARK: - Syncable

/// Anything that can round-trip through the Cadence API. Records are never
/// hard-deleted on the client; they get a `deletedAt` tombstone so the
/// deletion can propagate to other devices during sync.
public protocol Syncable: Identifiable, Sendable where ID == UUID {
    var updatedAt: Date { get }
    var deletedAt: Date? { get }
}

public extension Syncable {
    var isDeleted: Bool { deletedAt != nil }
}

// MARK: - MuscleGroup

public enum MuscleGroup: String, Codable, CaseIterable, Sendable, Identifiable {
    case chest
    case back
    case shoulders
    case arms
    case legs
    case core
    case fullBody = "full_body"
    case cardio

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fullBody: "Full Body"
        default: rawValue.capitalized
        }
    }

    /// SF Symbol used wherever the group is shown as a chip or icon.
    public var symbolName: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rower"
        case .shoulders: "figure.arms.open"
        case .arms: "dumbbell"
        case .legs: "figure.walk"
        case .core: "figure.core.training"
        case .fullBody: "figure.mixed.cardio"
        case .cardio: "figure.run"
        }
    }
}

// MARK: - ExerciseSet

public struct ExerciseSet: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// Weight is always stored in kilograms; the UI converts for display.
    public var weightKg: Double
    public var reps: Int
    /// Rate of perceived exertion, 1–10. Optional because most people skip it.
    public var rpe: Double?
    public var isCompleted: Bool

    public init(
        id: UUID = UUID(),
        weightKg: Double = 0,
        reps: Int = 0,
        rpe: Double? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.isCompleted = isCompleted
    }

    public var volumeKg: Double { weightKg * Double(reps) }

    public var estimatedOneRepMaxKg: Double {
        StatsEngine.estimatedOneRepMax(weightKg: weightKg, reps: reps)
    }
}

// MARK: - Exercise

public struct Exercise: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var muscleGroup: MuscleGroup
    public var sets: [ExerciseSet]

    public init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: MuscleGroup,
        sets: [ExerciseSet] = []
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.sets = sets
    }

    public var completedSets: [ExerciseSet] { sets.filter(\.isCompleted) }

    public var volumeKg: Double {
        completedSets.reduce(0) { $0 + $1.volumeKg }
    }

    /// The completed set with the highest estimated 1RM.
    public var bestSet: ExerciseSet? {
        completedSets.max { $0.estimatedOneRepMaxKg < $1.estimatedOneRepMaxKg }
    }
}

// MARK: - Workout

public struct Workout: Identifiable, Codable, Hashable, Sendable, Syncable {
    public var id: UUID
    public var title: String
    public var startedAt: Date
    /// `nil` while the workout is still in progress.
    public var endedAt: Date?
    public var notes: String
    public var exercises: [Exercise]
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        notes: String = "",
        exercises: [Exercise] = [],
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.exercises = exercises
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    public var isActive: Bool { endedAt == nil }

    public var duration: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }

    public var totalVolumeKg: Double {
        exercises.reduce(0) { $0 + $1.volumeKg }
    }

    public var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.completedSets.count }
    }

    /// Unique muscle groups in the order they first appear.
    public var muscleGroups: [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        return exercises.compactMap { seen.insert($0.muscleGroup).inserted ? $0.muscleGroup : nil }
    }
}

// MARK: - Run

public struct Run: Identifiable, Codable, Hashable, Sendable, Syncable {
    public var id: UUID
    public var startedAt: Date
    /// Distance is always stored in meters; the UI converts for display.
    public var distanceMeters: Double
    public var durationSeconds: TimeInterval
    public var notes: String
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        notes: String = "",
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// Seconds per kilometer. `nil` for a zero-distance run.
    public var paceSecondsPerKm: Double? {
        guard distanceMeters > 0 else { return nil }
        return durationSeconds / (distanceMeters / 1000)
    }

    public var averageSpeedKmh: Double {
        guard durationSeconds > 0 else { return 0 }
        return (distanceMeters / 1000) / (durationSeconds / 3600)
    }
}

// MARK: - DataSnapshot

/// Everything the app persists locally, in one Codable value. Keeping the
/// whole state in a single struct makes atomic saves trivial and gives sync a
/// clear boundary.
public struct DataSnapshot: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var workouts: [Workout]
    public var runs: [Run]
    public var activeWorkout: Workout?
    public var lastSyncedAt: Date?

    public static let currentSchemaVersion = 1

    public init(
        schemaVersion: Int = DataSnapshot.currentSchemaVersion,
        workouts: [Workout] = [],
        runs: [Run] = [],
        activeWorkout: Workout? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.workouts = workouts
        self.runs = runs
        self.activeWorkout = activeWorkout
        self.lastSyncedAt = lastSyncedAt
    }

    public static let empty = DataSnapshot()
}
