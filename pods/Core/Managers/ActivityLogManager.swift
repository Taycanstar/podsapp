

import Foundation

class ActivityLogManager: ObservableObject {
    @Published var logs: [PodItemActivityLog] = []
    @Published var isLoading = false
    @Published var hasMore = true
    private var currentPage = 1
    private var podId: Int?
        private var userEmail: String?
    
    private let networkManager: NetworkManager
    

    init() {
           self.networkManager = NetworkManager()
       }
    func initialize(podId: Int, userEmail: String) {
            self.podId = podId
            self.userEmail = userEmail
            loadMoreLogs(refresh: true)
        }
    
    private func resetAndFetchLogs() {
        currentPage = 1
        hasMore = true
        loadCachedLogs() // Load cached logs before fetching new ones
        loadMoreLogs(refresh: true)
    }

    func updateUserEmail(_ email: String) {
        print("ActivityLogManager: Updating userEmail to \(email).")
        self.userEmail = email
        // The didSet will trigger resetAndFetchLogs
    }
    
    func loadCachedLogs() {
        if podId == 0 {
            print("ActivityLogManager: podId is 0. Skipping loading cached logs.")
            return
        }
        if let cached = UserDefaults.standard.data(forKey: "logs_\(podId)"),
           let decodedJSON = try? JSONDecoder().decode([PodItemActivityLogJSON].self, from: cached) {
            self.logs = decodedJSON.compactMap { jsonLog in
                do {
                    let log = try PodItemActivityLog(from: jsonLog)
                    return log
                } catch {
                    print("ActivityLogManager: Failed to decode log with id \(jsonLog.id): \(error)")
                    return nil
                }
            }
            print("ActivityLogManager: Loaded \(self.logs.count) cached logs for podId \(podId).")
        } else {
            print("ActivityLogManager: No cached logs found for podId \(podId).")
        }
    }
    
    func cacheLogs() {
        guard podId != 0 else {
            print("ActivityLogManager: podId is 0. Skipping caching logs.")
            return
        }
        // Convert PodItemActivityLog back to JSON format for caching
        let jsonLogs: [PodItemActivityLogJSON] = logs.map { log in
            PodItemActivityLogJSON(
                id: log.id,
                itemId: log.itemId,
                itemLabel: log.itemLabel,
                userEmail: log.userEmail,
                loggedAt: ISO8601DateFormatter().string(from: log.loggedAt),
                columnValues: log.columnValues,
                notes: log.notes,
                userName: log.userName
            )
        }
        
        if let encoded = try? JSONEncoder().encode(jsonLogs) {
            UserDefaults.standard.set(encoded, forKey: "logs_\(podId)")
            print("ActivityLogManager: Successfully cached \(jsonLogs.count) logs for podId \(podId).")
        } else {
            print("ActivityLogManager: Failed to encode logs for podId \(podId).")
        }
    }
    
    func loadMoreLogs(refresh: Bool = false) {
          guard let podId = podId, let userEmail = userEmail else {
              print("ActivityLogManager: Can't load logs - not initialized")
              return
          }
          
          guard !isLoading, (refresh || hasMore) else { return }
          print("starting activities load... ")
          isLoading = true
          let pageToLoad = refresh ? 1 : currentPage
        
        networkManager.fetchUserActivityLogs(podId: podId, userEmail: userEmail, page: pageToLoad) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let (newLogs, hasMore)):
                    if refresh {
                        self.logs = newLogs
                        self.currentPage = 2
                        print("ActivityLogManager: Refreshed logs with \(newLogs.count) new logs.")
                    } else {
                        self.logs.append(contentsOf: newLogs)
                        self.currentPage += 1
                        print("ActivityLogManager: Appended \(newLogs.count) new logs.")
                    }
                    self.hasMore = hasMore
                    self.cacheLogs()
                    print("ActivityLogManager: Logs loaded. hasMore=\(hasMore).")
                case .failure(let error):
                    print("ActivityLogManager: Failed to load logs: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func deleteLog(_ log: PodItemActivityLog) {
        print("ActivityLogManager: Deleting log with id \(log.id).")
        networkManager.deleteActivityLog(logId: log.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.logs.removeAll { $0.id == log.id }
                    self.cacheLogs()
                    print("ActivityLogManager: Successfully deleted log with id \(log.id).")
                case .failure(let error):
                    print("ActivityLogManager: Failed to delete log with id \(log.id): \(error.localizedDescription)")
                }
            }
        }
    }
    
    func updateLog(at index: Int, with updatedLog: PodItemActivityLog) {
        guard index < logs.count else {
            print("ActivityLogManager: updateLog failed. Index \(index) out of bounds.")
            return
        }
        logs[index] = updatedLog
        cacheLogs()
        print("ActivityLogManager: Updated log at index \(index) with id \(updatedLog.id).")
    }
    
    func updateLogInState(_ updatedLog: PodItemActivityLog) {
        if let index = logs.firstIndex(where: { $0.id == updatedLog.id }) {
            logs[index] = updatedLog
            cacheLogs()
            print("ActivityLogManager: Updated existing log with id \(updatedLog.id) at index \(index).")
            
            // Force a reload periodically to ensure sync
            if logs.count > 0 && logs[index].id % 10 == 0 { // Every 10 updates
                loadMoreLogs(refresh: true)
                print("ActivityLogManager: Triggered reload due to log id \(updatedLog.id).")
            }
        } else {
            // If log doesn't exist, append it
            logs.append(updatedLog)
            cacheLogs()
            print("ActivityLogManager: Appended new log with id \(updatedLog.id).")
        }
    }
}
