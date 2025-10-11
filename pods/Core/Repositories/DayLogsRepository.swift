import Foundation
import Combine

struct DayLogsSnapshot: Codable {
    var date: Date
    var combined: [CombinedLog]
    var water: [WaterLogResponse]
    var userData: UserData?
    var goals: NutritionGoals?
    var scheduled: [ScheduledLogPreview] = []
}

@MainActor
final class DayLogsRepository: ObservableObject {
    static let shared = DayLogsRepository()

    @Published private(set) var snapshots: [Date: DayLogsSnapshot] = [:]

    private var currentEmail: String?
    private let network = LogRepository()
    private let store = UserContextStore.shared
    private let calendar = Calendar.current
    private var lastFetchTimestamps: [Date: Date] = [:]
    private var inflightDates: Set<Date> = []

    private init() {}

    func configure(email: String) {
        guard currentEmail != email else { return }
        currentEmail = email
        snapshots.removeAll()
        lastFetchTimestamps.removeAll()

        if let cached: CachedEntry<[DayLogsSnapshot]> = store.load([DayLogsSnapshot].self,
                                                                   for: UserScopedKey(email: email, domain: .dayLogs)) {
            for snapshot in cached.value {
                let key = calendar.startOfDay(for: snapshot.date)
                snapshots[key] = snapshot
                lastFetchTimestamps[key] = cached.updatedAt
            }
        }
    }

    func snapshot(for date: Date) -> DayLogsSnapshot? {
        snapshots[calendar.startOfDay(for: date)]
    }

    func refresh(date: Date, force: Bool = false) async {
        guard let email = currentEmail else { return }
        let key = calendar.startOfDay(for: date)

        if !force,
           let lastFetch = lastFetchTimestamps[key],
           Date().timeIntervalSince(lastFetch) < RepositoryTTL.dayLogs {
            return
        }

        if inflightDates.contains(key) { return }
        inflightDates.insert(key)

        await withCheckedContinuation { continuation in
            network.fetchLogs(email: email, for: key) { [weak self] result in
                guard let self else {
                    continuation.resume()
                    return
                }
                DispatchQueue.main.async {
                    self.inflightDates.remove(key)
                    defer { continuation.resume() }
                    switch result {
                    case .success(let response):
                        let snapshot = DayLogsSnapshot(
                            date: key,
                            combined: response.logs,
                            water: response.waterLogs,
                            userData: response.userData,
                            goals: response.goals,
                            scheduled: response.scheduledLogs
                        )
                        self.snapshots[key] = snapshot
                        self.lastFetchTimestamps[key] = Date()
                        self.persistSnapshots()
                    case .failure:
                        break
                    }
                }
            }
        }
    }

    private func persistSnapshots() {
        guard let email = currentEmail else { return }
        let values = Array(snapshots.values)
        store.save(CachedEntry(value: values, updatedAt: Date()),
                   for: UserScopedKey(email: email, domain: .dayLogs))
    }
}
