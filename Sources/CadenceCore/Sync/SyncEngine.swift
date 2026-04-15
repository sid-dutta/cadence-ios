import Foundation

/// Last-write-wins merge with tombstones. Both the client and the server run
/// the same rule, so the outcome of a sync doesn't depend on which side
/// happened to go first.
public enum SyncEngine {

    /// Union of `local` and `remote` keyed by `id`. When both sides have a
    /// record, the one with the later `updatedAt` wins; a tie keeps the local
    /// copy. Tombstoned records are kept (not dropped) so the deletion can
    /// still be pushed to a device that hasn't seen it yet.
    public static func merge<T: Syncable>(local: [T], remote: [T]) -> [T] {
        var byID: [UUID: T] = [:]
        byID.reserveCapacity(local.count + remote.count)

        for item in local {
            byID[item.id] = item
        }
        for item in remote {
            if let existing = byID[item.id] {
                if item.updatedAt > existing.updatedAt {
                    byID[item.id] = item
                }
            } else {
                byID[item.id] = item
            }
        }

        return byID.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Records touched after `since`. With `since == nil` everything is a
    /// change (first sync).
    public static func changes<T: Syncable>(in items: [T], since: Date?) -> [T] {
        guard let since else { return items }
        return items.filter { $0.updatedAt > since }
    }

    /// Filters out tombstones for display.
    public static func visible<T: Syncable>(_ items: [T]) -> [T] {
        items.filter { !$0.isDeleted }
    }

    /// Drops tombstones older than `retention` — they've had plenty of time to
    /// propagate, and keeping them forever would bloat the local file.
    public static func compact<T: Syncable>(_ items: [T], retention: TimeInterval = 60 * 60 * 24 * 90, now: Date = Date()) -> [T] {
        items.filter { item in
            guard let deletedAt = item.deletedAt else { return true }
            return now.timeIntervalSince(deletedAt) < retention
        }
    }
}
