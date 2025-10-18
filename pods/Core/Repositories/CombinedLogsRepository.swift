import Foundation
import Combine

struct CombinedLogsSnapshot: Codable {
    var logs: [CombinedLog]
    var nextPage: Int
    var hasMore: Bool

    static let empty = CombinedLogsSnapshot(logs: [], nextPage: 1, hasMore: true)
}

@MainActor
final class CombinedLogsRepository: ObservableObject {
    static let shared = CombinedLogsRepository()
    private static let cacheVersion = 2
    private static let cacheVersionKeyPrefix = "pods.combinedLogs.cacheVersion."

    @Published private(set) var snapshot: CombinedLogsSnapshot = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingNextPage = false

    private var currentEmail: String?
    private let network = NetworkManager()
    private let workoutsNetwork = NetworkManagerTwo.shared
    private let store = UserContextStore.shared
    private var workoutCountFetchInFlight: Set<Int> = []

    private init() {}

    func configure(email: String) {
        guard currentEmail != email else { return }
        currentEmail = email

        invalidateCacheIfNeeded(for: email)

        if let cached: CachedEntry<CombinedLogsSnapshot> = store.load(CombinedLogsSnapshot.self,
                                                                     for: key(for: email)) {
            snapshot = cached.value
        } else {
            snapshot = .empty
        }
    }

    @discardableResult
    func refresh(force: Bool = false) async -> Bool {
        guard let email = currentEmail else { return false }

        if !force,
           let cached: CachedEntry<CombinedLogsSnapshot> = store.load(CombinedLogsSnapshot.self,
                                                                     for: key(for: email)),
           cached.isFresh(ttl: RepositoryTTL.combinedLogs) {
            snapshot = cached.value
            return true
        }

        if isRefreshing { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let response = try await fetchPage(for: email, page: 1)
            snapshot = CombinedLogsSnapshot(
                logs: response.logs,
                nextPage: response.hasMore ? 2 : 1,
                hasMore: response.hasMore
            )
            persist()
            ensureWorkoutCounts(for: response.logs, email: email)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func loadNextPage() async -> Bool {
        guard let email = currentEmail, snapshot.hasMore else { return false }
        if isLoadingNextPage { return false }
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        let page = snapshot.nextPage
        do {
            let response = try await fetchPage(for: email, page: page)
            snapshot = CombinedLogsSnapshot(
                logs: merge(existing: snapshot.logs, with: response.logs),
                nextPage: response.hasMore ? page + 1 : page,
                hasMore: response.hasMore
            )
            persist()
            ensureWorkoutCounts(for: response.logs, email: email)
            return true
        } catch {
            return false
        }
    }

    func clear() {
        snapshot = .empty
        if let email = currentEmail {
            store.clear(for: key(for: email))
        }

        if let email = currentEmail {
            let defaults = UserDefaults.standard
            defaults.set(Self.cacheVersion, forKey: Self.cacheVersionKeyPrefix + email)
        }
    }

    private func merge(existing: [CombinedLog], with newLogs: [CombinedLog]) -> [CombinedLog] {
        var combined = existing
        var indexById: [String: Int] = [:]
        for (index, log) in combined.enumerated() {
            indexById[log.id] = index
        }

        for log in newLogs {
            if log.type == .workout || log.type == .activity {
                print(
                    "🆕 merged log",
                    log.id,
                    "type:",
                    String(describing: log.type),
                    "incoming exercises:",
                    log.workout?.exercisesCount as Any,
                    "message:",
                    log.message
                )
            }
            if let index = indexById[log.id] {
                combined[index] = log
            } else {
                indexById[log.id] = combined.count
                combined.append(log)
            }
        }
        return combined
    }

    private func ensureWorkoutCounts(for logs: [CombinedLog], email: String) {
        let missingIds = Set(
            logs.compactMap { log -> Int? in
                guard let workout = log.workout, workout.exercisesCount <= 0 else { return nil }
                return workout.id
            }
        )

        guard !missingIds.isEmpty else { return }

        let idsToFetch = missingIds.subtracting(workoutCountFetchInFlight)
        guard !idsToFetch.isEmpty else { return }

        workoutCountFetchInFlight.formUnion(idsToFetch)
        fetchAndApplyWorkoutCounts(email: email, workoutIds: idsToFetch)
    }

    private func fetchAndApplyWorkoutCounts(email: String, workoutIds: Set<Int>) {
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let pageSize = max(50, min(300, workoutIds.count * 2))
                let response = try await self.workoutsNetwork.fetchServerWorkouts(
                    userEmail: email,
                    pageSize: pageSize,
                    isTemplateOnly: false,
                    daysBack: 120
                )

                let counts = response.workouts.reduce(into: [Int: Int]()) { partialResult, workout in
                    guard workoutIds.contains(workout.id) else { return }
                    let completed = (workout.status ?? "").lowercased() == "completed"
                    guard completed else { return }
                    let count = workout.exercises.count
                    guard count > 0 else { return }
                    partialResult[workout.id] = count
                }

                await MainActor.run {
                    self.workoutCountFetchInFlight.subtract(workoutIds)
                    self.applyWorkoutCounts(counts)
                }
            } catch {
                await MainActor.run {
                    self.workoutCountFetchInFlight.subtract(workoutIds)
                    print("⚠️ CombinedLogsRepository failed to sync workout counts:", error.localizedDescription)
                }
            }
        }
    }

    private func applyWorkoutCounts(_ counts: [Int: Int]) {
        guard !counts.isEmpty else { return }

        var updatedLogs = snapshot.logs
        var changed = false

        for index in updatedLogs.indices {
            guard let workout = updatedLogs[index].workout,
                  let newCount = counts[workout.id],
                  newCount > 0,
                  workout.exercisesCount != newCount else { continue }

            updatedLogs[index].workout = workout.withExercisesCount(newCount)
            changed = true
        }

        guard changed else { return }

        snapshot = CombinedLogsSnapshot(
            logs: updatedLogs,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    private func fetchPage(for email: String, page: Int) async throws -> CombinedLogsResponse {
        try await withCheckedThrowingContinuation { continuation in
            network.getCombinedLogs(userEmail: email, page: page) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func persist() {
        guard let email = currentEmail else { return }
        store.save(CachedEntry(value: snapshot, updatedAt: Date()),
                   for: key(for: email))
    }

    private func invalidateCacheIfNeeded(for email: String) {
        let defaults = UserDefaults.standard
        let versionKey = Self.cacheVersionKeyPrefix + email
        let storedVersion = defaults.integer(forKey: versionKey)
        guard storedVersion < Self.cacheVersion else { return }

        store.clear(for: key(for: email))
        defaults.set(Self.cacheVersion, forKey: versionKey)
    }

    private func key(for email: String) -> UserScopedKey {
        UserScopedKey(email: email, domain: .combinedLogs)
    }
}
