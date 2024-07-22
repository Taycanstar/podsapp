//
//import Foundation
//
//class HomeViewModel: ObservableObject {
//    @Published var pods: [Pod] = []
//    private var networkManager = NetworkManager()
//    @Published var shouldUseDarkTheme: Bool = false
//    @Published var isItemViewActive: Bool = false
//    private var currentPage = 0
//      private var isLoading = false
//
//    func fetchPodsForUser(email: String) {
//        networkManager.fetchPodsForUser(email: email) { [weak self] success, pods, errorMessage in
//            DispatchQueue.main.async {
//                if success, let pods = pods {
//                    self?.pods = pods
//                } else {
//                    print("Error fetching pods: \(errorMessage ?? "Unknown error")")
//                }
//                self?.pods = pods ?? []
//            }
//        }
//    }
//}

import Foundation

class HomeViewModel: ObservableObject {
    @Published var pods: [Pod] = []
    private var networkManager = NetworkManager()
    @Published var shouldUseDarkTheme: Bool = false
    @Published var isItemViewActive: Bool = false
    var currentPage = 0
    var totalPages = 1
    var totalPods = 0
    var isLoading = false

    func fetchPodsForUser(email: String, page: Int, completion: @escaping () -> Void) {
        guard page <= totalPages else {
            completion()
            return
        }
        
        isLoading = true
        
        networkManager.fetchPodsForUser(email: email, page: page) { [weak self] success, newPods, totalPods, errorMessage in
            DispatchQueue.main.async {
                if success, let newPods = newPods {
                    if page == 1 {
                        self?.pods = newPods
                    } else {
                        self?.pods.append(contentsOf: newPods)
                    }
                    self?.currentPage = page
                    self?.totalPods = totalPods
                    self?.totalPages = (totalPods / 10) + (totalPods % 10 > 0 ? 1 : 0)
                } else {
                    print("Error fetching pods: \(errorMessage ?? "Unknown error")")
                }
                self?.isLoading = false
                completion()
            }
        }
    }
    
    func refreshPods(email: String, completion: @escaping () -> Void) {
        self.pods = []  // Clear existing pods
        self.currentPage = 0
        self.totalPages = 1
        self.totalPods = 0
        
        fetchPodsForUser(email: email, page: 1) {
            completion()
        }
    }
    

}

