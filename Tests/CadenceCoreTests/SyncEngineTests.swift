import XCTest
@testable import CadenceCore

final class SyncEngineTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func run(_ id: UUID, updatedAt: TimeInterval, deleted: Bool = false) -> Run {
        Run(
            id: id,
            startedAt: t0,
            distanceMeters: 1000,
            durationSeconds: 300,
            notes: "t=\(updatedAt)",
            updatedAt: t0.addingTimeInterval(updatedAt),
            deletedAt: deleted ? t0.addingTimeInterval(updatedAt) : nil
        )
    }

    func testMergeNewerRemoteWins() {
        let id = UUID()
        let merged = SyncEngine.merge(local: [run(id, updatedAt: 1)], remote: [run(id, updatedAt: 2)])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].notes, "t=2.0")
    }

    func testMergeNewerLocalWins() {
        let id = UUID()
        let merged = SyncEngine.merge(local: [run(id, updatedAt: 5)], remote: [run(id, updatedAt: 2)])
        XCTAssertEqual(merged[0].notes, "t=5.0")
    }

    func testMergeTieKeepsLocal() {
        let id = UUID()
        var local = run(id, updatedAt: 3)
        local.notes = "local"
        let merged = SyncEngine.merge(local: [local], remote: [run(id, updatedAt: 3)])
        XCTAssertEqual(merged[0].notes, "local")
    }

    func testMergeIsUnionAndKeepsTombstones() {
        let a = run(UUID(), updatedAt: 1)
        let b = run(UUID(), updatedAt: 2, deleted: true)
        let merged = SyncEngine.merge(local: [a], remote: [b])
        XCTAssertEqual(Set(merged.map(\.id)), [a.id, b.id])
        XCTAssertEqual(SyncEngine.visible(merged).map(\.id), [a.id])
    }

    func testMergeSortsNewestFirst() {
        let merged = SyncEngine.merge(local: [run(UUID(), updatedAt: 1)], remote: [run(UUID(), updatedAt: 9)])
        XCTAssertEqual(merged.map(\.notes), ["t=9.0", "t=1.0"])
    }

    func testChangesSince() {
        let items = [run(UUID(), updatedAt: 1), run(UUID(), updatedAt: 10)]
        XCTAssertEqual(SyncEngine.changes(in: items, since: nil).count, 2)
        XCTAssertEqual(SyncEngine.changes(in: items, since: t0.addingTimeInterval(5)).count, 1)
        XCTAssertEqual(SyncEngine.changes(in: items, since: t0.addingTimeInterval(10)).count, 0, "boundary is exclusive")
    }

    func testCompactDropsOldTombstonesOnly() {
        let live = run(UUID(), updatedAt: 0)
        let freshTombstone = run(UUID(), updatedAt: 0, deleted: true)
        let staleTombstone = run(UUID(), updatedAt: -1_000_000, deleted: true)
        let compacted = SyncEngine.compact([live, freshTombstone, staleTombstone], retention: 100, now: t0.addingTimeInterval(50))
        XCTAssertEqual(Set(compacted.map(\.id)), [live.id, freshTombstone.id])
    }
}
