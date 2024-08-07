import Foundation

class HomeViewModel: ObservableObject {
    @Published var pods: [Pod] = []
    @Published var workspaces: [Workspace] = []
    private var networkManager = NetworkManager()
    @Published var shouldUseDarkTheme: Bool = false
    @Published var isItemViewActive: Bool = false
    var currentPage = 0
    var totalPages = 1
    var totalPods = 0
    var isLoading = false
    @Published var recentlyVisitedPodIds: [Int] = []
    
    init() {
            loadRecentlyVisitedPods()
        }
        

    func fetchPodsForUser(email: String, workspaceId: Int? = nil, showFavorites: Bool = false, page: Int, completion: @escaping () -> Void) {
        guard page <= totalPages else {
            completion()
            return
        }
        
        isLoading = true
        
        networkManager.fetchPodsForUser(email: email, workspaceId: workspaceId, showFavorites: showFavorites, page: page) { [weak self] success, newPods, totalPods, errorMessage in
            DispatchQueue.main.async {
                if success, let newPods = newPods {
                    if page == 1 {
                        self?.pods = newPods
                    } else {
                        self?.pods.append(contentsOf: newPods)
                    }
                    self?.currentPage = page
                    self?.totalPods = totalPods
                    self?.totalPages = (totalPods / 7) + (totalPods % 7 > 0 ? 1 : 0)
       
                                    self?.recentlyVisitedPodIds = self?.recentlyVisitedPodIds.filter { podId in
                                        newPods.contains { $0.id == podId }
                                    } ?? []
                                    self?.objectWillChange.send()
                } else {
                    print("Error fetching pods: \(errorMessage ?? "Unknown error")")
                }
                self?.isLoading = false
                completion()
            }
        }
    }
    
    func refreshPods(email: String, workspaceId: Int? = nil, showFavorites: Bool = false, completion: @escaping () -> Void) {
        self.pods = []  // Clear existing pods
        self.currentPage = 0
        self.totalPages = 1
        self.totalPods = 0
        
        fetchPodsForUser(email: email, workspaceId: workspaceId, showFavorites: showFavorites, page: 1) {
            completion()
        }
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

    func appendNewPod(_ pod: Pod) {
        DispatchQueue.main.async {
            self.pods.append(pod)
            self.totalPods += 1
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
        return recentlyVisitedPodIds.compactMap { podId in
            pods.first { $0.id == podId }
        }
    }
    
    private func updateRecentlyVisitedPods(podId: Int) {
        if let index = recentlyVisitedPodIds.firstIndex(of: podId) {
            recentlyVisitedPodIds.remove(at: index)
        }
        recentlyVisitedPodIds.insert(podId, at: 0)
        if recentlyVisitedPodIds.count > 5 {
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
