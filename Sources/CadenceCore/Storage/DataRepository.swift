import Foundation

/// Abstracts *where* a `DataSnapshot` lives so the app model can be driven by
/// a real file in production and an in-memory store in tests and previews.
public protocol DataRepository: Sendable {
    func load() throws -> DataSnapshot
    func save(_ snapshot: DataSnapshot) throws
}

// MARK: - JSONFileRepository

/// Persists the snapshot as a single JSON document. Writes are atomic
/// (`Data.write(options: .atomic)`) so a crash mid-save can't corrupt the
/// store.
public struct JSONFileRepository: DataRepository {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `~/Library/Application Support/Cadence/data.json` on every Apple platform.
    public static func defaultFileURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("Cadence", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("data.json")
    }

    public func load() throws -> DataSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONCoding.decode(DataSnapshot.self, from: data)
    }

    public func save(_ snapshot: DataSnapshot) throws {
        let data = try JSONCoding.encode(snapshot, prettyPrinted: true)
        try data.write(to: fileURL, options: [.atomic])
    }
}

// MARK: - InMemoryRepository

/// Thread-safe in-memory store for tests and SwiftUI previews.
public final class InMemoryRepository: DataRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: DataSnapshot

    public init(snapshot: DataSnapshot = .empty) {
        self.snapshot = snapshot
    }

    public func load() throws -> DataSnapshot {
        lock.withLock { snapshot }
    }

    public func save(_ snapshot: DataSnapshot) throws {
        lock.withLock { self.snapshot = snapshot }
    }
}
