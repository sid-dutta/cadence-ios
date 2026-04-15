import XCTest
@testable import CadenceCore

final class HealthTests: XCTestCase {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private let now = Date(timeIntervalSince1970: 1_788_350_400)

    private func day(_ offset: Int, steps: Int? = nil, kcal: Double? = nil, mass: Double? = nil, hr: Double? = nil) -> HealthDay {
        let date = calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: now)!)
        return HealthDay(date: date, steps: steps, activeEnergyKcal: kcal, restingHeartRate: hr, bodyMassKg: mass)
    }

    func testSeriesZeroFillsAndOrdersOldestFirst() {
        let days = [day(0, steps: 100), day(-2, steps: 300)]
        let series = HealthStats.series(days, lastDays: 4, endingAt: now, calendar: calendar)
        XCTAssertEqual(series.count, 4)
        XCTAssertEqual(series.map { $0.steps ?? -1 }, [-1, 300, -1, 100])
        XCTAssertTrue(series.map(\.date) == series.map(\.date).sorted())
    }

    func testTotalsAndAveragesIgnoreMissingDays() {
        let days = [day(0, steps: 1000, kcal: 200), day(-1), day(-2, steps: 3000, kcal: 400)]
        XCTAssertEqual(HealthStats.totalSteps(days), 4000)
        XCTAssertEqual(HealthStats.averageSteps(days), 2000, "days without step data don't drag the average down")
        XCTAssertEqual(HealthStats.totalActiveEnergy(days), 600)
        XCTAssertEqual(HealthStats.averageSteps([]), 0)
    }

    func testLatestBodyMassAndRestingHeartRate() {
        let days = [day(-5, mass: 75, hr: 60), day(-1, mass: 74.2, hr: 56), day(0, hr: 58)]
        XCTAssertEqual(HealthStats.latestBodyMassKg(days), 74.2)
        XCTAssertEqual(HealthStats.averageRestingHeartRate(days) ?? 0, 58, accuracy: 0.001)
        XCTAssertNil(HealthStats.latestBodyMassKg([day(0)]))
        XCTAssertNil(HealthStats.averageRestingHeartRate([]))
    }

    func testDayLookupMatchesCalendarDay() {
        let days = [day(0, steps: 42)]
        XCTAssertEqual(HealthStats.day(now.addingTimeInterval(3600), in: days, calendar: calendar)?.steps, 42)
        XCTAssertNil(HealthStats.day(now.addingTimeInterval(-86_400 * 3), in: days, calendar: calendar))
    }

    private func run(hk: UUID?, deleted: Bool = false) -> Run {
        Run(startedAt: now, distanceMeters: 5000, durationSeconds: 1500, deletedAt: deleted ? now : nil, healthKitID: hk)
    }

    func testMergeSkipsKnownAndUnlinkedRuns() {
        let known = UUID(), fresh = UUID()
        let existing = [run(hk: known), run(hk: nil)]
        let imported = [run(hk: known), run(hk: fresh), run(hk: nil)]

        let result = HealthImport.merge(imported: imported, into: existing)

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.runs.count, 3)
        XCTAssertEqual(result.runs.compactMap(\.healthKitID).filter { $0 == fresh }.count, 1)
    }

    func testMergeDoesNotResurrectDeletedImports() {
        let id = UUID()
        let result = HealthImport.merge(imported: [run(hk: id)], into: [run(hk: id, deleted: true)])
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.runs.count, 1)
        XCTAssertNotNil(result.runs[0].deletedAt)
    }

    func testMergeDaysReplacesSameDayAndKeepsOthers() {
        let existing = [day(-3, steps: 1), day(-1, steps: 2)]
        let fetched = [day(-1, steps: 20), day(0, steps: 30)]
        let merged = HealthImport.mergeDays(fetched: fetched, into: existing, calendar: calendar)
        XCTAssertEqual(merged.map { $0.steps ?? 0 }, [1, 20, 30])
    }

    func testSchemaOneSnapshotDecodesWithHealthDefaults() throws {
        let legacy = #"{"schema_version":1,"workouts":[],"runs":[{"id":"11111111-2222-3333-4444-555555555555","started_at":"2026-09-01T07:00:00Z","distance_meters":5000,"duration_seconds":1500,"notes":"","updated_at":"2026-09-01T07:30:00Z","deleted_at":null}],"active_workout":null,"last_synced_at":null}"#
        let snapshot = try JSONCoding.decode(DataSnapshot.self, from: Data(legacy.utf8))
        XCTAssertEqual(snapshot.runs.count, 1)
        XCTAssertNil(snapshot.runs[0].healthKitID)
        XCTAssertTrue(snapshot.healthDays.isEmpty)
        XCTAssertNil(snapshot.lastHealthImportAt)
    }

    func testHealthKitIDRoundTripsAsSnakeCase() throws {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let json = String(decoding: try JSONCoding.encode(run(hk: id)), as: UTF8.self)
        XCTAssertTrue(json.contains("\"health_kit_id\":\"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE\""), json)
        let decoded = try JSONCoding.decode(Run.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.healthKitID, id)
    }
}
