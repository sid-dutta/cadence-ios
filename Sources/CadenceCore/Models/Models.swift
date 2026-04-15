import Foundation

public protocol Syncable: Identifiable, Sendable where ID == UUID {
    var updatedAt: Date { get }
    var deletedAt: Date? { get }
}

public extension Syncable {
    var isDeleted: Bool { deletedAt != nil }
}

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

public struct ExerciseSet: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var weightKg: Double
    public var reps: Int
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

    public var bestSet: ExerciseSet? {
        completedSets.max { $0.estimatedOneRepMaxKg < $1.estimatedOneRepMaxKg }
    }
}

public struct Workout: Identifiable, Codable, Hashable, Sendable, Syncable {
    public var id: UUID
    public var title: String
    public var startedAt: Date
    public var endedAt: Date?
    public var notes: String
    public var exercises: [Exercise]
    public var updatedAt: Date
    public var deletedAt: Date?
    // Set once exported to Health, so it is never written twice.
    public var healthKitID: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        notes: String = "",
        exercises: [Exercise] = [],
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        healthKitID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.exercises = exercises
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.healthKitID = healthKitID
    }

    enum CodingKeys: String, CodingKey {
        case id, title, startedAt, endedAt, notes, exercises, updatedAt, deletedAt
        case healthKitID = "healthKitId"
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

    public var muscleGroups: [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        return exercises.compactMap { seen.insert($0.muscleGroup).inserted ? $0.muscleGroup : nil }
    }
}

public struct Run: Identifiable, Codable, Hashable, Sendable, Syncable {
    public var id: UUID
    public var startedAt: Date
    public var distanceMeters: Double
    public var durationSeconds: TimeInterval
    public var notes: String
    public var updatedAt: Date
    public var deletedAt: Date?
    public var healthKitID: UUID?

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        notes: String = "",
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        healthKitID: UUID? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.healthKitID = healthKitID
    }

    enum CodingKeys: String, CodingKey {
        case id, startedAt, distanceMeters, durationSeconds, notes, updatedAt, deletedAt
        case healthKitID = "healthKitId"
    }

    public var isFromHealth: Bool { healthKitID != nil && notes.hasPrefix(Run.healthNotePrefix) }

    public static let healthNotePrefix = "From "

    public var paceSecondsPerKm: Double? {
        guard distanceMeters > 0 else { return nil }
        return durationSeconds / (distanceMeters / 1000)
    }

    public var averageSpeedKmh: Double {
        guard durationSeconds > 0 else { return 0 }
        return (distanceMeters / 1000) / (durationSeconds / 3600)
    }
}

public struct DataSnapshot: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var workouts: [Workout]
    public var runs: [Run]
    public var activeWorkout: Workout?
    public var lastSyncedAt: Date?
    public var healthDays: [HealthDay]
    public var lastHealthImportAt: Date?

    public static let currentSchemaVersion = 2

    public init(
        schemaVersion: Int = DataSnapshot.currentSchemaVersion,
        workouts: [Workout] = [],
        runs: [Run] = [],
        activeWorkout: Workout? = nil,
        lastSyncedAt: Date? = nil,
        healthDays: [HealthDay] = [],
        lastHealthImportAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.workouts = workouts
        self.runs = runs
        self.activeWorkout = activeWorkout
        self.lastSyncedAt = lastSyncedAt
        self.healthDays = healthDays
        self.lastHealthImportAt = lastHealthImportAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        workouts = try c.decodeIfPresent([Workout].self, forKey: .workouts) ?? []
        runs = try c.decodeIfPresent([Run].self, forKey: .runs) ?? []
        activeWorkout = try c.decodeIfPresent(Workout.self, forKey: .activeWorkout)
        lastSyncedAt = try c.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        healthDays = try c.decodeIfPresent([HealthDay].self, forKey: .healthDays) ?? []
        lastHealthImportAt = try c.decodeIfPresent(Date.self, forKey: .lastHealthImportAt)
    }

    public static let empty = DataSnapshot()
}
