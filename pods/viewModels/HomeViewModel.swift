
import Foundation

class HomeViewModel: ObservableObject {
    @Published var pods: [Pod] = []
    @Published var workspaces: [Workspace] = []
    private var networkManager = NetworkManager()
    @Published var shouldUseDarkTheme: Bool = false
    @Published var isItemViewActive: Bool = false
    @Published var isLoading = false
    @Published var recentlyVisitedPodIds: [Int] = []
    @Published var totalPods: Int = 0
    @Published var teams: [Team] = []
    
    func fetchPodsForUser(email: String, workspaceId: Int? = nil, showFavorites: Bool = false, showRecentlyVisited: Bool = false, completion: @escaping () -> Void) {
        isLoading = true
        
        networkManager.fetchPodsForUser(email: email, workspaceId: workspaceId, showFavorites: showFavorites, showRecentlyVisited: showRecentlyVisited) { [weak self] success, newPods, errorMessage in
            DispatchQueue.main.async {
                if success, let newPods = newPods {
                    self?.pods = newPods
                    self?.totalPods = newPods.count
                    self?.objectWillChange.send()
                } else {
                    print("Error fetching pods: \(errorMessage ?? "Unknown error")")
                }
                self?.isLoading = false
                completion()
            }
        }
    }
    
    func refreshPods(email: String, workspaceId: Int? = nil, showFavorites: Bool = false, showRecentlyVisited: Bool = false, completion: @escaping () -> Void) {
        self.pods = []  // Clear existing pods
        fetchPodsForUser(email: email, workspaceId: workspaceId, showFavorites: showFavorites, showRecentlyVisited: showRecentlyVisited, completion: completion)
    }
    
    func fetchWorkspacesForUser(email: String) {
        networkManager.fetchWorkspacesForUser(email: email) { [weak self] success, workspaces, errorMessage in
            DispatchQueue.main.async {
                if success, let workspaces = workspaces {
                    self?.workspaces = workspaces
                 
                } else {
                    print("Error fetching workspaces: \(errorMessage ?? "Unknown error")")
                }
            }
        }
    }
    
    func fetchTeamsForUser(email: String) {
        networkManager.fetchTeamsForUser(email: email) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let teams):
                    self?.teams = teams
                case .failure(let error):
                    print("Error fetching teams: \(error)")
                }
            }
        }
    }

    func appendNewPod(_ pod: Pod) {
        DispatchQueue.main.async {
            self.pods.append(pod)
        }
    }
    
    func updatePodFavoriteStatus(podId: Int, isFavorite: Bool) {
         if let index = pods.firstIndex(where: { $0.id == podId }) {
             pods[index].isFavorite = isFavorite
             objectWillChange.send()
         }
     }

    func updatePodLastVisited(podId: Int) {
        NetworkManager().updatePodLastVisited(podId: podId) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    if let index = self?.pods.firstIndex(where: { $0.id == podId }) {
                        self?.pods[index].lastVisited = Date()
                        self?.updateRecentlyVisitedPods(podId: podId)
                    }
                }
            case .failure(let error):
                print("Failed to update last visited: \(error)")
            }
        }
    }

    var recentlyVisitedPods: [Pod] {
        return pods.filter { $0.lastVisited != nil }.sorted { $0.lastVisited! > $1.lastVisited! }
    }
    
    private func updateRecentlyVisitedPods(podId: Int) {
        if let index = recentlyVisitedPodIds.firstIndex(of: podId) {
            recentlyVisitedPodIds.remove(at: index)
        }
        recentlyVisitedPodIds.insert(podId, at: 0)
        if recentlyVisitedPodIds.count > 8 {
            recentlyVisitedPodIds.removeLast()
        }
        saveRecentlyVisitedPods()
    }
    
    private func saveRecentlyVisitedPods() {
        UserDefaults.standard.set(recentlyVisitedPodIds, forKey: "RecentlyVisitedPodIds")
    }
    
    private func loadRecentlyVisitedPods() {
        if let savedIds = UserDefaults.standard.array(forKey: "RecentlyVisitedPodIds") as? [Int] {
            recentlyVisitedPodIds = savedIds
        }
    }
}
