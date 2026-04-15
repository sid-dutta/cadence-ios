import Foundation

public protocol DataRepository: Sendable {
    func load() throws -> DataSnapshot
    func save(_ snapshot: DataSnapshot) throws
}

public struct JSONFileRepository: DataRepository {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

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
