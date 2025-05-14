import Foundation
import SwiftUI
import HealthKit
import Combine

class HealthKitViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var error: Error?
    
    @Published var stepCount: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var waterIntake: Double = 0
    @Published var distance: Double = 0
    @Published var recentWorkouts: [HKWorkout] = []
    @Published var nutritionData: [HKQuantityTypeIdentifier: Double] = [:]
    
    private let healthKitManager = HealthKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Check if HealthKit is authorized when the ViewModel is created
        self.isAuthorized = UserDefaults.standard.bool(forKey: "healthKitEnabled")
        
        // Watch for changes to the healthKitEnabled flag
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.checkAuthorization()
            }
            .store(in: &cancellables)
    }
    
    // Check if HealthKit is available and authorized
    func checkAuthorization() {
        isAuthorized = UserDefaults.standard.bool(forKey: "healthKitEnabled")
    }
    
    // Reload all health data
    func reloadHealthData() {
        guard healthKitManager.isHealthDataAvailable && isAuthorized else {
            return
        }
        
        isLoading = true
        error = nil
        
        // Create a dispatch group to track when all data is loaded
        let group = DispatchGroup()
        
        // Fetch steps
        group.enter()
        healthKitManager.fetchStepCount(for: Date()) { [weak self] steps, error in
            DispatchQueue.main.async {
                if let steps = steps {
                    self?.stepCount = steps
                }
                if let error = error {
                    self?.error = error
                }
                group.leave()
            }
        }
        
        // Fetch active energy
        group.enter()
        healthKitManager.fetchActiveEnergy(for: Date()) { [weak self] calories, error in
            DispatchQueue.main.async {
                if let calories = calories {
                    self?.activeEnergy = calories
                }
                if let error = error {
                    self?.error = error
                }
                group.leave()
            }
        }
        
        // Fetch water intake
        group.enter()
        healthKitManager.fetchWaterIntake(for: Date()) { [weak self] water, error in
            DispatchQueue.main.async {
                if let water = water {
                    self?.waterIntake = water
                }
                if let error = error {
                    self?.error = error
                }
                group.leave()
            }
        }
        
        // Fetch walking and running distance
        group.enter()
        healthKitManager.fetchDistance(for: Date()) { [weak self] distance, error in
            DispatchQueue.main.async {
                if let distance = distance {
                    self?.distance = distance
                }
                if let error = error {
                    self?.error = error
                }
                group.leave()
            }
        }
        
        // Fetch nutrition data
        group.enter()
        healthKitManager.fetchNutrientData(for: Date()) { [weak self] nutrients, error in
            DispatchQueue.main.async {
                if !nutrients.isEmpty {
                    self?.nutritionData = nutrients
                }
                if let error = error {
                    self?.error = error
                }
                group.leave()
            }
        }
        
        // Fetch recent workouts from the past week
        group.enter()
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        healthKitManager.fetchWorkouts(from: startDate, to: Date()) { [weak self] workouts, error in
            DispatchQueue.main.async {
                if let workouts = workouts {
                    self?.recentWorkouts = workouts
                }
                if let error = error {
                    self?.error = error
                }
                group.leave()
            }
        }
        
        // When all data is loaded, update the loading state
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
        }
    }
} 
