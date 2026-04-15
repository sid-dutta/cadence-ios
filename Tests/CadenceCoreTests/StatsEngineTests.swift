import XCTest
@testable import CadenceCore

final class StatsEngineTests: XCTestCase {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private let now = Date(timeIntervalSince1970: 1_788_350_400)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }

    private func workout(_ name: String, weightKg: Double, reps: Int, daysAgo: Int, completed: Bool = true) -> Workout {
        Workout(
            title: "W",
            startedAt: day(-daysAgo),
            endedAt: day(-daysAgo).addingTimeInterval(3600),
            exercises: [Exercise(name: name, muscleGroup: .chest, sets: [
                ExerciseSet(weightKg: weightKg, reps: reps, isCompleted: completed)
            ])]
        )
    }

    func testOneRepMaxSingleRepIsTheWeight() {
        XCTAssertEqual(StatsEngine.estimatedOneRepMax(weightKg: 100, reps: 1), 100)
    }

    func testOneRepMaxEpley() {
        XCTAssertEqual(StatsEngine.estimatedOneRepMax(weightKg: 100, reps: 10), 133.333, accuracy: 0.001)
    }

    func testOneRepMaxZeroInputs() {
        XCTAssertEqual(StatsEngine.estimatedOneRepMax(weightKg: 0, reps: 5), 0)
        XCTAssertEqual(StatsEngine.estimatedOneRepMax(weightKg: 100, reps: 0), 0)
    }

    func testPersonalRecordsPicksBestEstimatedOneRepMax() {
        let history = [
            workout("Bench Press", weightKg: 100, reps: 1, daysAgo: 10),   // 100
            workout("bench press", weightKg: 90, reps: 8, daysAgo: 5),     // 114
            workout("Bench Press", weightKg: 80, reps: 5, daysAgo: 2),     // 93.3
        ]
        let prs = StatsEngine.personalRecords(in: history)
        XCTAssertEqual(prs.count, 1, "case-insensitive names collapse to one PR")
        XCTAssertEqual(prs[0].weightKg, 90)
        XCTAssertEqual(prs[0].reps, 8)
    }

    func testPersonalRecordsIgnoresIncompleteSetsAndDeletedWorkouts() {
        var deleted = workout("Squat", weightKg: 200, reps: 1, daysAgo: 1)
        deleted.deletedAt = now
        let history = [
            deleted,
            workout("Squat", weightKg: 150, reps: 1, daysAgo: 3, completed: false),
            workout("Squat", weightKg: 100, reps: 1, daysAgo: 5),
        ]
        let prs = StatsEngine.personalRecords(in: history)
        XCTAssertEqual(prs.first?.weightKg, 100)
    }

    func testPersonalRecordTieGoesToEarlierDate() {
        let older = workout("Row", weightKg: 60, reps: 5, daysAgo: 20)
        let newer = workout("Row", weightKg: 60, reps: 5, daysAgo: 2)
        let prs = StatsEngine.personalRecords(in: [newer, older])
        XCTAssertEqual(prs.first?.workoutID, older.id)
    }

    func testIsPersonalRecordExcludesCurrentWorkout() {
        let past = workout("Bench Press", weightKg: 100, reps: 5, daysAgo: 7)
        let current = workout("Bench Press", weightKg: 120, reps: 5, daysAgo: 0)
        let candidate = ExerciseSet(weightKg: 105, reps: 5, isCompleted: true)

        XCTAssertTrue(StatsEngine.isPersonalRecord(candidate, exerciseName: "Bench Press", history: [past, current], excludingWorkoutID: current.id))
        XCTAssertFalse(StatsEngine.isPersonalRecord(candidate, exerciseName: "Bench Press", history: [past, current]))
    }

    func testRecordSetPicksEarliestOfEqualSetsInSession() {
        let past = workout("Bench Press", weightKg: 80, reps: 5, daysAgo: 7)
        let first = ExerciseSet(weightKg: 100, reps: 5, isCompleted: true)
        let repeat_ = ExerciseSet(weightKg: 100, reps: 5, isCompleted: true)
        let pending = ExerciseSet(weightKg: 120, reps: 5, isCompleted: false)
        let exercise = Exercise(name: "Bench Press", muscleGroup: .chest, sets: [first, repeat_, pending])

        XCTAssertEqual(StatsEngine.recordSet(in: exercise, history: [past])?.id, first.id)
        XCTAssertEqual(StatsEngine.bestOneRepMax(exerciseName: "bench press", in: [past]), 80 * (1 + 5.0 / 30), accuracy: 0.001)
        XCTAssertEqual(StatsEngine.bestOneRepMax(exerciseName: "Nope", in: [past]), 0)
    }

    func testRecordSetIsNilWhenNothingBeatsHistory() {
        let past = workout("Squat", weightKg: 150, reps: 5, daysAgo: 7)
        let exercise = Exercise(name: "Squat", muscleGroup: .legs, sets: [ExerciseSet(weightKg: 150, reps: 5, isCompleted: true)])
        XCTAssertNil(StatsEngine.recordSet(in: exercise, history: [past]))
    }

    func testIsPersonalRecordRequiresStrictImprovement() {
        let past = workout("Bench Press", weightKg: 100, reps: 5, daysAgo: 7)
        let equal = ExerciseSet(weightKg: 100, reps: 5, isCompleted: true)
        XCTAssertFalse(StatsEngine.isPersonalRecord(equal, exerciseName: "Bench Press", history: [past]))
    }

    func testWeeklySummariesZeroFillsAndSums() {
        let workouts = [
            workout("A", weightKg: 100, reps: 10, daysAgo: 0),   // this week, 1000 kg
            workout("A", weightKg: 50, reps: 10, daysAgo: 1),    // this week, 500 kg
            workout("A", weightKg: 100, reps: 10, daysAgo: 14),  // two weeks ago
        ]
        let runs = [Run(startedAt: day(-1), distanceMeters: 5000, durationSeconds: 1500)]

        let weeks = StatsEngine.weeklySummaries(workouts: workouts, runs: runs, weeks: 4, endingAt: now, calendar: calendar)

        XCTAssertEqual(weeks.count, 4)
        XCTAssertEqual(weeks.last?.workoutCount, 2)
        XCTAssertEqual(weeks.last?.volumeKg, 1500)
        XCTAssertEqual(weeks.last?.runDistanceMeters, 5000)
        XCTAssertEqual(weeks[2].workoutCount, 0, "last week had nothing")
        XCTAssertEqual(weeks[1].workoutCount, 1, "two weeks ago had one")
        XCTAssertTrue(weeks.map(\.weekStart) == weeks.map(\.weekStart).sorted(), "oldest first")
    }

    func testWeeklySummariesExcludesActiveWorkouts() {
        var active = workout("A", weightKg: 100, reps: 10, daysAgo: 0)
        active.endedAt = nil
        let weeks = StatsEngine.weeklySummaries(workouts: [active], runs: [], weeks: 1, endingAt: now, calendar: calendar)
        XCTAssertEqual(weeks.first?.workoutCount, 0)
    }

    func testStreakCountsConsecutiveWeeks() {
        let workouts = [0, 7, 14].map { workout("A", weightKg: 10, reps: 1, daysAgo: $0) }
        XCTAssertEqual(StatsEngine.currentStreak(workouts: workouts, runs: [], asOf: now, calendar: calendar), 3)
    }

    func testStreakBreaksOnGap() {
        let workouts = [0, 21].map { workout("A", weightKg: 10, reps: 1, daysAgo: $0) }
        XCTAssertEqual(StatsEngine.currentStreak(workouts: workouts, runs: [], asOf: now, calendar: calendar), 1)
    }

    func testStreakSurvivesEmptyCurrentWeek() {
        let runs = [7, 14].map { Run(startedAt: day(-$0), distanceMeters: 1000, durationSeconds: 300) }
        XCTAssertEqual(StatsEngine.currentStreak(workouts: [], runs: runs, asOf: now, calendar: calendar), 2)
    }

    func testStreakEmptyHistory() {
        XCTAssertEqual(StatsEngine.currentStreak(workouts: [], runs: [], asOf: now, calendar: calendar), 0)
    }

    func testExerciseHistoryIsChronologicalAndSkipsActive() {
        var active = workout("Squat", weightKg: 300, reps: 1, daysAgo: 0)
        active.endedAt = nil
        let history = [
            workout("Squat", weightKg: 100, reps: 5, daysAgo: 1),
            workout("Squat", weightKg: 90, reps: 5, daysAgo: 8),
            active,
        ]
        let points = StatsEngine.exerciseHistory(name: "squat", in: history)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points.map(\.topWeightKg), [90, 100])
    }

    func testFastestRunRespectsMinimumDistance() {
        let sprint = Run(distanceMeters: 400, durationSeconds: 60)     // 2:30/km
        let fiveK = Run(distanceMeters: 5000, durationSeconds: 1500)   // 5:00/km
        let tenK = Run(distanceMeters: 10000, durationSeconds: 3300)   // 5:30/km
        XCTAssertEqual(StatsEngine.fastestRun(in: [sprint, fiveK, tenK])?.id, fiveK.id)
        XCTAssertEqual(StatsEngine.longestRun(in: [sprint, fiveK, tenK])?.id, tenK.id)
    }

    func testRunPace() {
        let run = Run(distanceMeters: 5000, durationSeconds: 1500)
        XCTAssertEqual(run.paceSecondsPerKm ?? 0, 300, accuracy: 0.001)
        XCTAssertEqual(run.averageSpeedKmh, 12, accuracy: 0.001)
        XCTAssertNil(Run(distanceMeters: 0, durationSeconds: 100).paceSecondsPerKm)
    }
}
