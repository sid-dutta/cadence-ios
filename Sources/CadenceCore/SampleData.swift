import Foundation

/// Deterministic demo data: a few weeks of push/pull/legs sessions with
/// steady progressive overload, plus two runs a week that gradually speed up.
/// Seeded so previews, screenshots and tests all see the same history.
public enum SampleData {

    public static func snapshot(weeks: Int = 8, endingAt end: Date = Date(), seed: UInt64 = 42) -> DataSnapshot {
        var rng = SeededGenerator(seed: seed)
        let calendar = Calendar.current

        var workouts: [Workout] = []
        var runs: [Run] = []

        let templates: [(title: String, exercises: [(CatalogExercise, baseKg: Double, reps: Int)])] = [
            ("Push Day", [
                (.init("Bench Press", .chest), 60, 8),
                (.init("Overhead Press", .shoulders), 40, 8),
                (.init("Incline Bench Press", .chest), 45, 10),
                (.init("Lateral Raise", .shoulders), 8, 12),
                (.init("Tricep Pushdown", .arms), 25, 12),
            ]),
            ("Pull Day", [
                (.init("Deadlift", .back), 100, 5),
                (.init("Pull-Up", .back), 0, 8),
                (.init("Barbell Row", .back), 60, 8),
                (.init("Face Pull", .shoulders), 20, 15),
                (.init("Barbell Curl", .arms), 30, 10),
            ]),
            ("Leg Day", [
                (.init("Back Squat", .legs), 80, 6),
                (.init("Romanian Deadlift", .legs), 70, 8),
                (.init("Leg Press", .legs), 140, 10),
                (.init("Leg Curl", .legs), 40, 12),
                (.init("Calf Raise", .legs), 60, 15),
            ]),
        ]

        for weekOffset in stride(from: weeks - 1, through: 0, by: -1) {
            // ~2.5% overload per week, rounded to plate increments.
            let progress = 1 + Double(weeks - 1 - weekOffset) * 0.025

            for (dayIndex, template) in templates.enumerated() {
                let dayOfWeek = [1, 3, 5][dayIndex] // Mon / Wed / Fri offsets
                guard let start = date(weeksAgo: weekOffset, dayOffset: dayOfWeek, hour: 17, from: end, calendar: calendar),
                      start <= end else { continue }

                let skip = rng.nextDouble() < 0.1 // life happens
                if skip { continue }

                let exercises = template.exercises.map { catalog, baseKg, reps -> Exercise in
                    let working = roundToPlate(baseKg * progress)
                    let sets = (0..<3).map { setIndex -> ExerciseSet in
                        let fatigue = setIndex == 2 && rng.nextDouble() < 0.4 ? -1 : 0
                        return ExerciseSet(
                            id: rng.nextUUID(),
                            weightKg: working,
                            reps: max(1, reps + fatigue),
                            rpe: [7, 7.5, 8, 8.5][Int(rng.next() % 4)],
                            isCompleted: true
                        )
                    }
                    return Exercise(id: rng.nextUUID(), name: catalog.name, muscleGroup: catalog.muscleGroup, sets: sets)
                }

                let duration = TimeInterval(50 * 60 + Int(rng.next() % (20 * 60)))
                workouts.append(Workout(
                    id: rng.nextUUID(),
                    title: template.title,
                    startedAt: start,
                    endedAt: start.addingTimeInterval(duration),
                    notes: weekOffset == 0 && dayIndex == 0 ? "Felt strong today." : "",
                    exercises: exercises,
                    updatedAt: start.addingTimeInterval(duration)
                ))
            }

            // Two runs a week: an easy 5K-ish and a longer weekend run.
            let runSpecs: [(day: Int, km: Double, baseSecPerKm: Double)] = [(2, 5, 345), (6, 8, 365)]
            for spec in runSpecs {
                guard let start = date(weeksAgo: weekOffset, dayOffset: spec.day, hour: 7, from: end, calendar: calendar),
                      start <= end else { continue }
                if rng.nextDouble() < 0.15 { continue }

                let improvement = Double(weeks - 1 - weekOffset) * 2.5 // seconds/km faster per week
                let jitter = (rng.nextDouble() - 0.5) * 20
                let secPerKm = spec.baseSecPerKm - improvement + jitter
                let distance = spec.km * 1000 + (rng.nextDouble() - 0.5) * 400

                runs.append(Run(
                    id: rng.nextUUID(),
                    startedAt: start,
                    distanceMeters: distance.rounded(),
                    durationSeconds: (distance / 1000 * secPerKm).rounded(),
                    notes: "",
                    updatedAt: start
                ))
            }
        }

        return DataSnapshot(
            workouts: workouts.sorted { $0.startedAt > $1.startedAt },
            runs: runs.sorted { $0.startedAt > $1.startedAt }
        )
    }

    // MARK: Helpers

    private static func date(weeksAgo: Int, dayOffset: Int, hour: Int, from end: Date, calendar: Calendar) -> Date? {
        let weekStart = StatsEngine.startOfWeek(containing: end, calendar: calendar)
        guard let base = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: weekStart),
              let day = calendar.date(byAdding: .day, value: dayOffset, to: base) else { return nil }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
    }

    private static func roundToPlate(_ kg: Double) -> Double {
        (kg / 2.5).rounded() * 2.5
    }
}

/// SplitMix64 — tiny, fast, and reproducible across platforms.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// A random-looking but reproducible v4-style UUID.
    mutating func nextUUID() -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        let hi = next(), lo = next()
        for i in 0..<8 {
            bytes[i] = UInt8(truncatingIfNeeded: hi >> (8 * UInt64(i)))
            bytes[8 + i] = UInt8(truncatingIfNeeded: lo >> (8 * UInt64(i)))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40 // version 4
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
