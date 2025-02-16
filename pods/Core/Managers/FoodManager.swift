//
//  FoodManager.swift
//  Pods
//
//  Created by Dimi Nunez on 2/13/25.
//

import Foundation

class FoodManager: ObservableObject {
    @Published var loggedFoods: [LoggedFood] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let networkManager: NetworkManager
    private var userEmail: String?
    
    init() {
        self.networkManager = NetworkManager()
    }
    
    func initialize(userEmail: String) {
        print("FoodManager: Initializing with email \(userEmail)")
        self.userEmail = userEmail
        loadCachedFoods()  // Load cached foods immediately
        loadLoggedFoods(email: userEmail)
    }
    
    // Load foods from UserDefaults cache
    private func loadCachedFoods() {
        guard let userEmail = userEmail else { return }
        if let cached = UserDefaults.standard.data(forKey: "logged_foods_\(userEmail)"),
           let decodedFoods = try? JSONDecoder().decode([LoggedFood].self, from: cached) {
            self.loggedFoods = decodedFoods
        }
    }
    
    // Cache foods to UserDefaults
    private func cacheFoods(for email: String) {
        if let encoded = try? JSONEncoder().encode(loggedFoods) {
            UserDefaults.standard.set(encoded, forKey: "logged_foods_\(email)")
        }
    }
    
    func loadLoggedFoods(email: String) {
        // guard !isLoading else { return }
        
        print("FoodManager: Loading food logs for \(email)")
        isLoading = true
        error = nil
        
        networkManager.getFoodLogs(userEmail: email) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let foodLogs):
                    print("FoodManager: Successfully loaded \(foodLogs.count) food logs")
                    self.loggedFoods = foodLogs
                    self.cacheFoods(for: email)
                case .failure(let error):
                    print("FoodManager: Error loading food logs: \(error)")
                    self.error = error
                }
            }
        }
    }
    
    // And in the LogFood view, we'll call it like this:
       func refreshLoggedFoods(email: String) {
           loadLoggedFoods(email: email)
       }
    // Your existing logFood function
    func logFood(
        email: String,
        food: Food,
        meal: String,
        servings: Int,
        date: Date,
        notes: String? = nil,
        completion: @escaping (Result<LoggedFood, Error>) -> Void
    ) {
        isLoading = true
        
        networkManager.logFood(
            userEmail: email,
            food: food,
            meal: meal,
            servings: servings,
            date: date,
            notes: notes
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let loggedFood):
                    self.loggedFoods.insert(loggedFood, at: 0)  // Add new food to the start
                    self.cacheFoods(for: email)  // Cache the updated list
                    completion(.success(loggedFood))
                case .failure(let error):
                    self.error = error
                    completion(.failure(error))
                }
            }
        }
    }
}
