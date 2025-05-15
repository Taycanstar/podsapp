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
    
    // Track the currently displayed date
    @Published var currentDate: Date = Date()
    
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
                self?.reloadHealthData(for: self?.currentDate ?? Date())
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
                        self?.reloadHealthData(for: self?.currentDate ?? Date())
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
                    self?.reloadHealthData(for: self?.currentDate ?? Date())
                    
                    // Post notification that health data is now available
                    NotificationCenter.default.post(name: NSNotification.Name("HealthDataAvailableNotification"), object: nil)
                }
                // Hide the alert after permission flow completes
                self?.showPermissionAlert = false
            }
        }
    }
    
    // Reload health data for the specified date
    func reloadHealthData(for date: Date) {
        guard healthKitManager.isHealthDataAvailable && isAuthorized else {
            return
        }
        
        // Update the current date
        self.currentDate = date
        
        isLoading = true
        error = nil
        
        // Create a dispatch group to track when all data is loaded
        let group = DispatchGroup()
        
        // Fetch steps for the specified date
        group.enter()
        healthKitManager.fetchStepCount(for: date) { [weak self] steps, error in
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
        
        // Fetch active energy for the specified date
        group.enter()
        healthKitManager.fetchActiveEnergy(for: date) { [weak self] calories, error in
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
        
        // Fetch water intake for the specified date
        group.enter()
        healthKitManager.fetchWaterIntake(for: date) { [weak self] water, error in
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
        
        // Fetch walking and running distance for the specified date
        group.enter()
        healthKitManager.fetchDistance(for: date) { [weak self] distance, error in
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
        
        // Fetch nutrition data for the specified date
        group.enter()
        healthKitManager.fetchNutrientData(for: date) { [weak self] nutrients, error in
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
        
        // Fetch recent workouts - Use a date range from the week before the selected date
        group.enter()
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -7, to: date)!
        let endDate = calendar.date(byAdding: .day, value: 1, to: date)!
        
        healthKitManager.fetchWorkouts(from: startDate, to: endDate) { [weak self] workouts, error in
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
    
    // Backward compatibility method - calls reloadHealthData with the current date
    func reloadHealthData() {
        reloadHealthData(for: currentDate)
    }
} 
