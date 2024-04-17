
import Foundation

class HomeViewModel: ObservableObject {
    @Published var pods: [Pod] = []
    private var networkManager = NetworkManager()
    @Published var shouldUseDarkTheme: Bool = false
    @Published var isItemViewActive: Bool = false

    func fetchPodsForUser(email: String) {
        networkManager.fetchPodsForUser(email: email) { [weak self] success, pods, errorMessage in
            DispatchQueue.main.async {
                if success, let pods = pods {
                    self?.pods = pods
                } else {
                    print("Error fetching pods: \(errorMessage ?? "Unknown error")")
                }
                self?.pods = pods ?? []
            }
        }
    }
}
