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
        self.userEmail = userEmail
        loadCachedFoods()
    }
    
    private func loadCachedFoods() {
        guard let userEmail = userEmail else { return }
        if let cached = UserDefaults.standard.data(forKey: "logged_foods_\(userEmail)"),
           let decodedFoods = try? JSONDecoder().decode([LoggedFood].self, from: cached) {
            self.loggedFoods = decodedFoods
        }
    }
    
    private func cacheFoods(for email: String) {
        if let encoded = try? JSONEncoder().encode(loggedFoods) {
            UserDefaults.standard.set(encoded, forKey: "logged_foods_\(email)")
        }
    }
    
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
                    self.loggedFoods.insert(loggedFood, at: 0)
                    self.cacheFoods(for: email)
                    completion(.success(loggedFood))
                case .failure(let error):
                    self.error = error
                    completion(.failure(error))
                }
            }
        }
    }
}