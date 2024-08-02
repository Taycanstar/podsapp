
//import Foundation
//
//class HomeViewModel: ObservableObject {
//    @Published var pods: [Pod] = []
//    private var networkManager = NetworkManager()
//    @Published var shouldUseDarkTheme: Bool = false
//    @Published var isItemViewActive: Bool = false
//    var currentPage = 0
//    var totalPages = 1
//    var totalPods = 0
//    var isLoading = false
//
//    func fetchPodsForUser(email: String, page: Int, completion: @escaping () -> Void) {
//        guard page <= totalPages else {
//            completion()
//            return
//        }
//        
//        isLoading = true
//        
//        networkManager.fetchPodsForUser(email: email, page: page) { [weak self] success, newPods, totalPods, errorMessage in
//            DispatchQueue.main.async {
//                if success, let newPods = newPods {
//                    if page == 1 {
//                        self?.pods = newPods
//                    } else {
//                        self?.pods.append(contentsOf: newPods)
//                    }
//                    self?.currentPage = page
//                    self?.totalPods = totalPods
//                    self?.totalPages = (totalPods / 7) + (totalPods % 7 > 0 ? 1 : 0)
//                   
//                } else {
//                    print("Error fetching pods: \(errorMessage ?? "Unknown error")")
//                }
//                self?.isLoading = false
//                completion()
//            }
//        }
//    }
//    
//    func refreshPods(email: String, completion: @escaping () -> Void) {
//        self.pods = []  // Clear existing pods
//        self.currentPage = 0
//        self.totalPages = 1
//        self.totalPods = 0
//        
//        fetchPodsForUser(email: email, page: 1) {
//            completion()
//        }
//    }
//    
//    func appendNewPod(_ pod: Pod) {
//           DispatchQueue.main.async {
//               self.pods.append(pod)
//               self.totalPods += 1
//           }
//       }
//    

//}
//

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
}
