import Foundation

/// A preset exercise the user can pick from when building a workout.
public struct CatalogExercise: Identifiable, Hashable, Sendable {
    public let name: String
    public let muscleGroup: MuscleGroup

    public var id: String { name }

    public init(_ name: String, _ muscleGroup: MuscleGroup) {
        self.name = name
        self.muscleGroup = muscleGroup
    }

    public func makeExercise() -> Exercise {
        Exercise(name: name, muscleGroup: muscleGroup)
    }
}

public enum ExerciseCatalog {
    public static let all: [CatalogExercise] = [
        // Chest
        .init("Bench Press", .chest),
        .init("Incline Bench Press", .chest),
        .init("Dumbbell Bench Press", .chest),
        .init("Cable Fly", .chest),
        .init("Push-Up", .chest),
        .init("Dip", .chest),
        // Back
        .init("Deadlift", .back),
        .init("Barbell Row", .back),
        .init("Pull-Up", .back),
        .init("Lat Pulldown", .back),
        .init("Seated Cable Row", .back),
        .init("Dumbbell Row", .back),
        // Shoulders
        .init("Overhead Press", .shoulders),
        .init("Dumbbell Shoulder Press", .shoulders),
        .init("Lateral Raise", .shoulders),
        .init("Face Pull", .shoulders),
        .init("Rear Delt Fly", .shoulders),
        // Arms
        .init("Barbell Curl", .arms),
        .init("Dumbbell Curl", .arms),
        .init("Hammer Curl", .arms),
        .init("Tricep Pushdown", .arms),
        .init("Skull Crusher", .arms),
        .init("Overhead Tricep Extension", .arms),
        // Legs
        .init("Back Squat", .legs),
        .init("Front Squat", .legs),
        .init("Romanian Deadlift", .legs),
        .init("Leg Press", .legs),
        .init("Bulgarian Split Squat", .legs),
        .init("Leg Curl", .legs),
        .init("Leg Extension", .legs),
        .init("Calf Raise", .legs),
        .init("Hip Thrust", .legs),
        // Core
        .init("Plank", .core),
        .init("Hanging Leg Raise", .core),
        .init("Cable Crunch", .core),
        .init("Ab Wheel Rollout", .core),
        // Full body
        .init("Clean and Press", .fullBody),
        .init("Kettlebell Swing", .fullBody),
        .init("Farmer's Carry", .fullBody),
    ]

    public static var groupedByMuscle: [(group: MuscleGroup, exercises: [CatalogExercise])] {
        MuscleGroup.allCases.compactMap { group in
            let matches = all.filter { $0.muscleGroup == group }
            return matches.isEmpty ? nil : (group, matches)
        }
    }

    /// Case- and whitespace-insensitive prefix/substring search.
    public static func search(_ query: String) -> [CatalogExercise] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(needle) }
    }

    public static func lookup(name: String) -> CatalogExercise? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.first { $0.name.lowercased() == key }
    }
}
