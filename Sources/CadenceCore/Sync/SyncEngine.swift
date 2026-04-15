import Foundation

public enum SyncEngine {

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

    public static func changes<T: Syncable>(in items: [T], since: Date?) -> [T] {
        guard let since else { return items }
        return items.filter { $0.updatedAt > since }
    }

    public static func visible<T: Syncable>(_ items: [T]) -> [T] {
        items.filter { !$0.isDeleted }
    }

    public static func compact<T: Syncable>(_ items: [T], retention: TimeInterval = 60 * 60 * 24 * 90, now: Date = Date()) -> [T] {
        items.filter { item in
            guard let deletedAt = item.deletedAt else { return true }
            return now.timeIntervalSince(deletedAt) < retention
        }
    }
}
