import XCTest
@testable import CadenceCore

final class StorageTests: XCTestCase {

    func testSnapshotRoundTripsThroughJSON() throws {
        let original = SampleData.snapshot(weeks: 2, endingAt: Date(timeIntervalSince1970: 1_788_350_400))
        let data = try JSONCoding.encode(original)
        let decoded = try JSONCoding.decode(DataSnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testJSONUsesSnakeCaseKeysAndISODates() throws {
        let run = Run(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            distanceMeters: 5000,
            durationSeconds: 1500,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let json = String(decoding: try JSONCoding.encode(run), as: UTF8.self)
        XCTAssertTrue(json.contains("\"distance_meters\":5000"))
        XCTAssertTrue(json.contains("\"duration_seconds\":1500"))
        XCTAssertTrue(json.contains("\"started_at\":\"2023-11-14T22:13:20.000Z\""))
        XCTAssertTrue(json.contains("\"deleted_at\":null") || !json.contains("deleted_at"))
    }

    func testDecodesDatesWithAndWithoutFractionalSeconds() throws {
        let fractional = #"{"id":"11111111-2222-3333-4444-555555555555","started_at":"2023-11-14T22:13:20.123Z","distance_meters":1,"duration_seconds":1,"notes":"","updated_at":"2023-11-14T22:13:20Z"}"#
        let run = try JSONCoding.decode(Run.self, from: Data(fractional.utf8))
        XCTAssertEqual(run.startedAt.timeIntervalSince1970, 1_700_000_000.123, accuracy: 0.001)
        XCTAssertEqual(run.updatedAt.timeIntervalSince1970, 1_700_000_000, accuracy: 0.001)
    }

    func testFileRepositoryRoundTripAndMissingFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = JSONFileRepository(fileURL: directory.appendingPathComponent("data.json"))
        XCTAssertEqual(try repository.load(), .empty, "missing file reads as empty")

        let snapshot = SampleData.snapshot(weeks: 1)
        try repository.save(snapshot)
        XCTAssertEqual(try repository.load(), snapshot)
    }

    func testInMemoryRepository() throws {
        let repository = InMemoryRepository()
        XCTAssertEqual(try repository.load(), .empty)
        let snapshot = DataSnapshot(runs: [Run(distanceMeters: 1, durationSeconds: 1)])
        try repository.save(snapshot)
        XCTAssertEqual(try repository.load(), snapshot)
    }

    func testSampleDataIsDeterministicAndComplete() {
        let end = Date(timeIntervalSince1970: 1_788_350_400)
        let a = SampleData.snapshot(weeks: 6, endingAt: end, seed: 7)
        let b = SampleData.snapshot(weeks: 6, endingAt: end, seed: 7)
        let c = SampleData.snapshot(weeks: 6, endingAt: end, seed: 8)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertFalse(a.workouts.isEmpty)
        XCTAssertFalse(a.runs.isEmpty)
        XCTAssertTrue(a.workouts.allSatisfy { !$0.isActive })
        XCTAssertTrue(a.workouts.flatMap(\.exercises).flatMap(\.sets).allSatisfy(\.isCompleted))
        XCTAssertTrue(a.workouts.allSatisfy { $0.startedAt <= end })
    }

    func testExerciseCatalogSearch() {
        XCTAssertEqual(ExerciseCatalog.search("  bench ").map(\.name), ["Bench Press", "Incline Bench Press", "Dumbbell Bench Press"])
        XCTAssertEqual(ExerciseCatalog.search("").count, ExerciseCatalog.all.count)
        XCTAssertEqual(ExerciseCatalog.lookup(name: "deadlift")?.muscleGroup, .back)
        XCTAssertNil(ExerciseCatalog.lookup(name: "Nope"))
    }
}
