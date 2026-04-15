import Foundation
import Observation
import CadenceCore

/// A workout or run, for lists that show both.
public enum ActivityItem: Identifiable, Hashable, Sendable {
    case workout(Workout)
    case run(Run)

    public var id: UUID {
        switch self {
        case .workout(let w): w.id
        case .run(let r): r.id
        }
    }

    public var date: Date {
        switch self {
        case .workout(let w): w.startedAt
        case .run(let r): r.startedAt
        }
    }
}

/// The single source of truth for the UI. Every mutation goes through here,
/// which is what makes the "persist after every change" rule easy to keep.
@MainActor
@Observable
public final class AppModel {

    public enum SyncStatus: Equatable, Sendable {
        case idle
        case syncing
        case succeeded(Date)
        case failed(String)
    }

    // MARK: State

    /// Includes tombstones; use `visibleWorkouts` for display.
    public private(set) var workouts: [Workout] = []
    /// Includes tombstones; use `visibleRuns` for display.
    public private(set) var runs: [Run] = []
    public private(set) var activeWorkout: Workout?
    public private(set) var lastSyncedAt: Date?
    public private(set) var syncStatus: SyncStatus = .idle
    public private(set) var storageError: String?

    public var settings: UserSettings {
        didSet { settingsStore.save(settings) }
    }

    public private(set) var isSignedIn: Bool

    private let repository: DataRepository
    private let settingsStore: SettingsStore
    private let tokenStore: TokenStore

    // MARK: Init

    public init(repository: DataRepository, settingsStore: SettingsStore, tokenStore: TokenStore) {
        self.repository = repository
        self.settingsStore = settingsStore
        self.tokenStore = tokenStore
        self.settings = settingsStore.load()
        self.isSignedIn = tokenStore.read() != nil

        do {
            let snapshot = try repository.load()
            workouts = snapshot.workouts
            runs = snapshot.runs
            activeWorkout = snapshot.activeWorkout
            lastSyncedAt = snapshot.lastSyncedAt
        } catch {
            storageError = "Couldn't read saved data: \(error.localizedDescription)"
        }
    }

    /// Production wiring: JSON file + UserDefaults + Keychain.
    public static func live() -> AppModel {
        let repository: DataRepository
        do {
            repository = JSONFileRepository(fileURL: try JSONFileRepository.defaultFileURL())
        } catch {
            repository = InMemoryRepository()
        }
        return AppModel(repository: repository, settingsStore: UserDefaultsSettingsStore(), tokenStore: KeychainTokenStore())
    }

    /// In-memory model pre-loaded with sample history, for previews and UI tests.
    public static func preview(weeks: Int = 8, signedIn: Bool = false) -> AppModel {
        AppModel(
            repository: InMemoryRepository(snapshot: SampleData.snapshot(weeks: weeks)),
            settingsStore: InMemorySettingsStore(settings: UserSettings(accountEmail: signedIn ? "demo@cadence.app" : nil)),
            tokenStore: InMemoryTokenStore(token: signedIn ? "preview-token" : nil)
        )
    }

    // MARK: Derived

    public var visibleWorkouts: [Workout] {
        SyncEngine.visible(workouts).filter { !$0.isActive }.sorted { $0.startedAt > $1.startedAt }
    }

    public var visibleRuns: [Run] {
        SyncEngine.visible(runs).sorted { $0.startedAt > $1.startedAt }
    }

    public var recentActivity: [ActivityItem] {
        (visibleWorkouts.map(ActivityItem.workout) + visibleRuns.map(ActivityItem.run))
            .sorted { $0.date > $1.date }
    }

    public var personalRecords: [PersonalRecord] {
        StatsEngine.personalRecords(in: workouts)
    }

    public var currentStreak: Int {
        StatsEngine.currentStreak(workouts: workouts, runs: runs)
    }

    public func weeklySummaries(weeks: Int) -> [WeeklySummary] {
        StatsEngine.weeklySummaries(workouts: workouts, runs: runs, weeks: weeks)
    }

    public var thisWeek: WeeklySummary? {
        weeklySummaries(weeks: 1).first
    }

    public func workout(id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }

    public func run(id: UUID) -> Run? {
        runs.first { $0.id == id }
    }

    // MARK: Active workout

    public func startWorkout(title: String? = nil) {
        guard activeWorkout == nil else { return }
        activeWorkout = Workout(title: title ?? Self.defaultTitle(for: Date()))
        persist()
    }

    public func renameActiveWorkout(_ title: String) {
        mutateActive { $0.title = title }
    }

    public func setActiveWorkoutNotes(_ notes: String) {
        mutateActive { $0.notes = notes }
    }

    public func addExercise(_ exercise: Exercise) {
        mutateActive { workout in
            var exercise = exercise
            if exercise.sets.isEmpty {
                exercise.sets = [ExerciseSet()]
            }
            workout.exercises.append(exercise)
        }
    }

    public func removeExercise(id: UUID) {
        mutateActive { $0.exercises.removeAll { $0.id == id } }
    }

    /// New set pre-filled from the previous one so the common case is a tap.
    public func addSet(toExercise exerciseID: UUID) {
        mutateActive { workout in
            guard let index = workout.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
            let last = workout.exercises[index].sets.last
            workout.exercises[index].sets.append(
                ExerciseSet(weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 0, rpe: last?.rpe)
            )
        }
    }

    public func updateSet(_ set: ExerciseSet, inExercise exerciseID: UUID) {
        mutateActive { workout in
            guard let e = workout.exercises.firstIndex(where: { $0.id == exerciseID }),
                  let s = workout.exercises[e].sets.firstIndex(where: { $0.id == set.id }) else { return }
            workout.exercises[e].sets[s] = set
        }
    }

    public func removeSet(id setID: UUID, fromExercise exerciseID: UUID) {
        mutateActive { workout in
            guard let e = workout.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
            workout.exercises[e].sets.removeAll { $0.id == setID }
        }
    }

    /// Flips completion and reports whether completing this set just set a
    /// new personal record, so the UI can celebrate.
    @discardableResult
    public func toggleSetCompletion(setID: UUID, inExercise exerciseID: UUID) -> PersonalRecord? {
        guard let workout = activeWorkout,
              let e = workout.exercises.firstIndex(where: { $0.id == exerciseID }),
              let s = workout.exercises[e].sets.firstIndex(where: { $0.id == setID }) else { return nil }

        var set = workout.exercises[e].sets[s]
        set.isCompleted.toggle()
        let exercise = workout.exercises[e]

        // A PR must beat all prior history *and* every other set already
        // completed in this session — repeating a record isn't a new one.
        let sessionBest = exercise.completedSets
            .filter { $0.id != set.id }
            .map(\.estimatedOneRepMaxKg)
            .max() ?? 0

        var record: PersonalRecord?
        if set.isCompleted,
           set.estimatedOneRepMaxKg > sessionBest,
           StatsEngine.isPersonalRecord(set, exerciseName: exercise.name, history: workouts, excludingWorkoutID: workout.id) {
            record = PersonalRecord(
                exerciseName: exercise.name,
                muscleGroup: exercise.muscleGroup,
                weightKg: set.weightKg,
                reps: set.reps,
                estimatedOneRepMaxKg: set.estimatedOneRepMaxKg,
                achievedAt: Date(),
                workoutID: workout.id
            )
        }

        updateSet(set, inExercise: exerciseID)
        return record
    }

    public func finishActiveWorkout() {
        guard var workout = activeWorkout else { return }
        let now = Date()
        workout.endedAt = now
        workout.updatedAt = now
        // Drop sets that were never filled in.
        workout.exercises = workout.exercises.compactMap { exercise in
            var exercise = exercise
            exercise.sets.removeAll { !$0.isCompleted && $0.reps == 0 && $0.weightKg == 0 }
            return exercise.sets.isEmpty ? nil : exercise
        }
        workouts.append(workout)
        activeWorkout = nil
        persist()
    }

    public func discardActiveWorkout() {
        activeWorkout = nil
        persist()
    }

    // MARK: History

    public func updateWorkout(_ workout: Workout) {
        guard let index = workouts.firstIndex(where: { $0.id == workout.id }) else { return }
        var workout = workout
        workout.updatedAt = Date()
        workouts[index] = workout
        persist()
    }

    public func deleteWorkout(id: UUID) {
        guard let index = workouts.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        workouts[index].deletedAt = now
        workouts[index].updatedAt = now
        persist()
    }

    public func logRun(_ run: Run) {
        var run = run
        run.updatedAt = Date()
        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index] = run
        } else {
            runs.append(run)
        }
        persist()
    }

    public func deleteRun(id: UUID) {
        guard let index = runs.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        runs[index].deletedAt = now
        runs[index].updatedAt = now
        persist()
    }

    // MARK: Account & sync

    public func signIn(email: String, password: String, createAccount: Bool) async throws {
        let client = try makeClient()
        let credentials = AuthCredentials(email: email.trimmingCharacters(in: .whitespaces).lowercased(), password: password)
        let token = createAccount ? try await client.register(credentials) : try await client.login(credentials)
        tokenStore.write(token.accessToken)
        settings.accountEmail = credentials.email
        isSignedIn = true
        await sync()
    }

    public func signOut() {
        tokenStore.write(nil)
        settings.accountEmail = nil
        isSignedIn = false
        lastSyncedAt = nil
        syncStatus = .idle
        persist()
    }

    /// Push local changes since the last sync, pull the server's, and merge
    /// with last-write-wins. Safe to call repeatedly.
    public func sync() async {
        guard isSignedIn, syncStatus != .syncing else { return }
        syncStatus = .syncing

        do {
            let client = try makeClient()
            let request = SyncRequest(
                since: lastSyncedAt,
                workouts: SyncEngine.changes(in: workouts, since: lastSyncedAt),
                runs: SyncEngine.changes(in: runs, since: lastSyncedAt)
            )
            let response = try await client.sync(request)

            workouts = SyncEngine.compact(SyncEngine.merge(local: workouts, remote: response.workouts))
            runs = SyncEngine.compact(SyncEngine.merge(local: runs, remote: response.runs))
            lastSyncedAt = response.serverTime
            syncStatus = .succeeded(response.serverTime)
            persist()
        } catch APIError.unauthorized {
            signOut()
            syncStatus = .failed(APIError.unauthorized.localizedDescription)
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }

    private func makeClient() throws -> CadenceAPIClient {
        guard let url = settings.serverURL else { throw APIError.invalidURL }
        return CadenceAPIClient(baseURL: url, token: tokenStore.read())
    }

    // MARK: Data management

    public func loadSampleData() {
        let sample = SampleData.snapshot()
        workouts = SyncEngine.merge(local: workouts, remote: sample.workouts)
        runs = SyncEngine.merge(local: runs, remote: sample.runs)
        persist()
    }

    public func eraseAllData() {
        workouts = []
        runs = []
        activeWorkout = nil
        lastSyncedAt = nil
        persist()
    }

    /// Writes a pretty-printed export to a temp file for `ShareLink`.
    public func exportFileURL() throws -> URL {
        let data = try JSONCoding.encode(snapshot, prettyPrinted: true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cadence-export.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Persistence

    private var snapshot: DataSnapshot {
        DataSnapshot(workouts: workouts, runs: runs, activeWorkout: activeWorkout, lastSyncedAt: lastSyncedAt)
    }

    private func persist() {
        do {
            try repository.save(snapshot)
            storageError = nil
        } catch {
            storageError = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func mutateActive(_ change: (inout Workout) -> Void) {
        guard var workout = activeWorkout else { return }
        change(&workout)
        workout.updatedAt = Date()
        activeWorkout = workout
        persist()
    }

    static func defaultTitle(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Morning Workout"
        case 12..<17: return "Afternoon Workout"
        default: return "Evening Workout"
        }
    }
}
