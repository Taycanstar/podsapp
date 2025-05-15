import Foundation
import SwiftUI
import HealthKit
import Combine

class HealthKitViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showPermissionAlert = false
    
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
        
        // Watch for HealthKit permission changes
        NotificationCenter.default.publisher(for: NSNotification.Name("HealthKitPermissionsChanged"))
            .sink { [weak self] _ in
                self?.checkAuthorization()
                self?.reloadHealthData()
            }
            .store(in: &cancellables)
            
        // Check permissions on startup
        checkAndRequestPermissionsIfNeeded()
    }
    
    // Check if HealthKit is available and authorized
    func checkAuthorization() {
        isAuthorized = UserDefaults.standard.bool(forKey: "healthKitEnabled")
    }
    
    // Check permissions and request them if needed
    func checkAndRequestPermissionsIfNeeded() {
        // Only try to request permissions if HealthKit is available
        guard healthKitManager.isHealthDataAvailable else { return }
        
        // Check current status
        let currentStatus = healthKitManager.isAuthorized
        
        if !currentStatus {
            // If permissions aren't authorized, request them
            healthKitManager.checkAndRequestHealthPermissions { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    
                    // If permissions granted, reload the data
                    if granted {
                        self?.reloadHealthData()
                    }
                }
            }
        }
    }
    
    // Method to request permissions (can be called from UI)
    func requestHealthKitPermissions() {
        healthKitManager.checkAndRequestHealthPermissions { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    // Refresh data immediately when permissions are granted
                    self?.reloadHealthData()
                    
                    // Post notification that health data is now available
                    NotificationCenter.default.post(name: NSNotification.Name("HealthDataAvailableNotification"), object: nil)
                }
                // Hide the alert after permission flow completes
                self?.showPermissionAlert = false
            }
        }
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
