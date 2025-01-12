import Foundation

class SingleItemActivityManager: ObservableObject {
    @Published var items: [ActivityItem] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var error: Error?
    
    private var currentPage = 1
    private var podId: Int?
    private var userEmail: String?
    private let pageSize = 50
    
    private let networkManager: NetworkManager
    
    init() {
        self.networkManager = NetworkManager()
    }
    
    func initialize(podId: Int, userEmail: String) {
        self.podId = podId
        self.userEmail = userEmail
        resetAndFetchItems()
    }
    
    private func resetAndFetchItems() {
        currentPage = 1
        hasMore = true
        items.removeAll()
        loadCachedItems()
        loadMoreItems(refresh: true)
    }
    
    private func loadCachedItems() {
        guard let podId = podId else { return }
        if let cached = UserDefaults.standard.data(forKey: "activity_items_\(podId)_page_1"),
           let decodedResponse = try? JSONDecoder().decode(ActivityItemsResponse.self, from: cached) {
            self.items = decodedResponse.items
            self.hasMore = decodedResponse.hasMore
        }
    }
    
    private func cacheItems(_ response: ActivityItemsResponse, forPage page: Int) {
        guard let podId = podId else { return }
        if let encoded = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encoded, forKey: "activity_items_\(podId)_page_\(page)")
        }
    }
    
    func loadMoreItems(refresh: Bool = false) {
        guard let podId = podId, let userEmail = userEmail else { return }
        guard !isLoading else { return }
        
        let pageToLoad = refresh ? 1 : currentPage
        isLoading = true
        
        networkManager.fetchUserActivityItems(podId: podId, userEmail: userEmail, page: pageToLoad) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let (newItems, hasMore)):
                    if refresh {
                        self.items = newItems
                        self.currentPage = 2
                    } else {
                        // Filter out any duplicates before appending
                        let uniqueNewItems = newItems.filter { newItem in
                            !self.items.contains { $0.id == newItem.id }
                        }
                        self.items.append(contentsOf: uniqueNewItems)
                        self.currentPage += 1
                    }
                    self.hasMore = hasMore
                    
                    // Cache the current page
                    let response = ActivityItemsResponse(
                        items: newItems,
                        hasMore: hasMore,
                        totalPages: (self.items.count + self.pageSize - 1) / self.pageSize,
                        currentPage: pageToLoad
                    )
                    self.cacheItems(response, forPage: pageToLoad)
                    
                case .failure(let error):
                    self.error = error
                    self.hasMore = false
                }
            }
        }
    }
    
    func deleteItem(_ item: ActivityItem) {
        networkManager.deleteActivity(activityId: item.activityId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.items.removeAll { $0.id == item.id }
                    
                    // Update cache for first page
                    let firstPageItems = Array(self.items.prefix(self.pageSize))
                    let response = ActivityItemsResponse(
                        items: firstPageItems,
                        hasMore: self.items.count > self.pageSize,
                        totalPages: (self.items.count + self.pageSize - 1) / self.pageSize,
                        currentPage: 1
                    )
                    self.cacheItems(response, forPage: 1)
                    
                case .failure(let error):
                    self.error = error
                }
            }
        }
    }
}
