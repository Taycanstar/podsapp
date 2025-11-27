import Foundation
import SwiftUI
import HealthKit
import Combine

@MainActor
final class HealthKitViewModel: ObservableObject {
    static let shared = HealthKitViewModel()
    private let wearableBackfillKey = "lastWearableBackfillDate"
    private var isBackfilling = false
    // Published properties for UI binding
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showPermissionAlert = false
    
    @Published var stepCount: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var basalEnergy: Double = 0
    @Published var waterIntake: Double = 0
    @Published var distance: Double = 0
    @Published var recentWorkouts: [HKWorkout] = []
    @Published var nutritionData: [HKQuantityTypeIdentifier: Double] = [:]
    @Published var restingHeartRate: Double = 0
    @Published var heartRateVariability: Double = 0
    @Published var walkingHeartRateAverage: Double = 0
    
    // Height and weight properties
    @Published var height: Double = 0 // Height in cm
    @Published var weight: Double = 0 // Weight in kg
    
    // Sleep data properties
    @Published var sleepHours: Double = 0 // Total sleep time in hours
    @Published var sleepMinutes: Int = 0  // Remaining minutes after hours
    @Published var respiratoryRate: Double?
    @Published var bodyTemperature: Double?
    @Published var recommendedSleepHours: Double = 8.0 // Default recommended amount
    
    // Track the currently displayed date
    @Published var currentDate: Date = Date()
    
    private let healthKitManager = HealthKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let metricsUploader = AgentMetricsUploader.shared
    private var latestSleepSummary: SleepSummary?
    private var sleepSummaryCache: [Date: SleepSummary] = [:]

    private let payloadDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    // Computed property for sleep progress
    var sleepProgress: Double {
        return min(sleepHours / recommendedSleepHours, 1.0)
    }
    
    // Computed property for total energy burned
    var totalEnergyBurned: Double {
        return activeEnergy + basalEnergy
    }
    
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current
    
    // MARK: - Initialization
    
    private func assertMainActor(_ context: String, file: StaticString = #fileID, line: UInt = #line) {
        MainActorDiagnostics.assertIsolated("HealthKitViewModel.\(context)", file: file, line: line)
    }
    
    init() {
        // Check if HealthKit is authorized when the ViewModel is created
        self.isAuthorized = UserDefaults.standard.bool(forKey: "healthKitEnabled")
        
        // Watch for changes to the healthKitEnabled flag
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.checkAuthorization()
            }
            .store(in: &cancellables)
        
        // Watch for HealthKit permission changes
        NotificationCenter.default.publisher(for: NSNotification.Name("HealthKitPermissionsChanged"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.checkAuthorization()
                self.reloadHealthData(for: self.currentDate)
            }
            .store(in: &cancellables)
            
        // Only check current authorization status - never automatically request permissions
        checkAuthorization()
    }
    
    // MARK: - Authorization methods
    
    // Check if HealthKit is available and authorized
    func checkAuthorization() {
        assertMainActor("checkAuthorization")
        isAuthorized = UserDefaults.standard.bool(forKey: "healthKitEnabled")
    }
    
    // Check permissions and request them if needed
    func checkAndRequestPermissionsIfNeeded() {
        assertMainActor("checkAndRequestPermissionsIfNeeded.entry")
        // Only try to request permissions if HealthKit is available
        guard healthKitManager.isHealthDataAvailable else { return }
        
        // Check current status
        let currentStatus = healthKitManager.isAuthorized
        
        if !currentStatus {
            // If permissions aren't authorized, request them
            healthKitManager.checkAndRequestHealthPermissions { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isAuthorized = granted

                    // If permissions granted, reload the data
                    if granted {
                        self.reloadHealthData(for: self.currentDate)
                        self.ensureWearableSync(force: true)
                    }
                }
            }
        }
    }
    
    // Method to request permissions (can be called from UI)
    func requestHealthKitPermissions() {
        assertMainActor("requestHealthKitPermissions.entry")
        healthKitManager.checkAndRequestHealthPermissions { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAuthorized = granted
                if granted {
                    // Refresh data immediately when permissions are granted
                    self.reloadHealthData(for: self.currentDate)
                    self.ensureWearableSync(force: true)
                    // Post notification that health data is now available
                    NotificationCenter.default.post(name: NSNotification.Name("HealthDataAvailableNotification"), object: nil)
                }
                // Hide the alert after permission flow completes
                self.showPermissionAlert = false
            }
        }
    }
    
    // Manual method to enable health data tracking (called from settings or connect buttons)
    func enableHealthDataTracking() {
        assertMainActor("enableHealthDataTracking.entry")
        print("User requested to enable health data tracking")
        
        guard healthKitManager.isHealthDataAvailable else {
            print("HealthKit not available on this device")
            return
        }
        
        // Request permissions
        healthKitManager.checkAndRequestHealthPermissions { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAuthorized = granted
                UserDefaults.standard.set(granted, forKey: "healthKitEnabled")

                if granted {
                    print("Health permissions granted - loading data")
                    // Refresh data immediately when permissions are granted
                    self.reloadHealthData(for: self.currentDate)

                    // Post notification that health data is now available
                    NotificationCenter.default.post(name: NSNotification.Name("HealthDataAvailableNotification"), object: nil)
                } else {
                    print("Health permissions denied")
                }
            }
        }
    }
    
    // MARK: - Data loading methods
    
    // Reload health data for the specified date
    func reloadHealthData(for date: Date) {
        assertMainActor("reloadHealthData")
        // Only proceed if HealthKit is available AND we already have authorization
        // Never trigger new permission requests from this method
        guard healthKitManager.isHealthDataAvailable else {
            print("HealthKit not available on this device")
            return
        }
        
        guard isAuthorized else {
            print("HealthKit not authorized - skipping data reload. Use enableHealthDataTracking() to request permissions.")
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
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let steps = steps {
                    self.stepCount = steps
                }
                if let error = error {
                    self.error = error
                }
            }
        }
        
        // Fetch active energy for the specified date
        group.enter()
        healthKitManager.fetchActiveEnergy(for: date) { [weak self] calories, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let calories = calories {
                    self.activeEnergy = calories
                }
                if let error = error {
                    self.error = error
                }
            }
        }
        
        // Fetch basal energy for the specified date
        group.enter()
        healthKitManager.fetchBasalEnergy(for: date) { [weak self] calories, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let calories = calories {
                    self.basalEnergy = calories
                }
                if let error = error {
                    self.error = error
                }
            }
        }
        
        // Fetch water intake for the specified date
        group.enter()
        healthKitManager.fetchWaterIntake(for: date) { [weak self] water, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let water = water {
                    self.waterIntake = water
                }
                if let error = error {
                    self.error = error
                }
            }
        }
        
        // Fetch height
        group.enter()
        healthKitManager.fetchHeight { [weak self] height, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let height = height {
                    self.height = height
                }
                if let error = error {
                    self.error = error
                }
            }
        }
        
        // Fetch weight
        group.enter()
        healthKitManager.fetchBodyWeight { [weak self] weight, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let weight = weight {
                    self.weight = weight
                }
                if let error = error {
                    self.error = error
                }
            }
        }
        
        // Fetch walking and running distance for the specified date
        group.enter()
        healthKitManager.fetchDistance(for: date) { [weak self] distance, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let distance = distance {
                    self.distance = distance
                }
                if let error = error {
                    self.error = error
                }
            }
        }
        
        // Fetch nutrition data for the specified date
        group.enter()
        healthKitManager.fetchNutrientData(for: date) { [weak self] nutrients, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if !nutrients.isEmpty {
                    self.nutritionData = nutrients
                }
                if let error = error {
                    self.error = error
                }
            }
        }
        
        // Fetch sleep data for the specified date
        group.enter()
        healthKitManager.fetchSleepSummary(for: date) { [weak self] summary, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let summary = summary {
                    self.latestSleepSummary = summary
                    let dayKey = self.calendar.startOfDay(for: date)
                    self.sleepSummaryCache[dayKey] = summary
                    let totalHours = summary.totalSleepMinutes / 60.0
                    self.sleepHours = floor(totalHours)
                    self.sleepMinutes = Int((totalHours - self.sleepHours) * 60.0)
                }
                if let error = error {
                    self.error = error
                }
            }
        }

        group.enter()
        healthKitManager.fetchRestingHeartRate(for: date) { [weak self] value, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let value = value {
                    self.restingHeartRate = value
                } else {
                    self.restingHeartRate = 0
                }
                if let error = error {
                    self.error = error
                }
            }
        }

        group.enter()
        healthKitManager.fetchHeartRateVariability(for: date) { [weak self] value, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let value = value {
                    self.heartRateVariability = value
                } else {
                    self.heartRateVariability = 0
                }
                if let error = error {
                    self.error = error
                }
            }
        }

        group.enter()
        healthKitManager.fetchWalkingHeartRateAverage(for: date) { [weak self] value, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let value = value {
                    self.walkingHeartRateAverage = value
                } else {
                    self.walkingHeartRateAverage = 0
                }
                if let error = error {
                    self.error = error
                }
            }
        }

        group.enter()
        healthKitManager.fetchRespiratoryRate(for: date) { [weak self] value, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                self.respiratoryRate = value
                if let error = error {
                    self.error = error
                }
            }
        }

        group.enter()
        healthKitManager.fetchBodyTemperature(for: date) { [weak self] value, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                self.bodyTemperature = value
                if let error = error {
                    self.error = error
                }
            }
        }
        
        // Fetch recent workouts - Use a date range from the week before the selected date
        group.enter()
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -7, to: date)!
        let endDate = calendar.date(byAdding: .day, value: 1, to: date)!
        
        healthKitManager.fetchWorkouts(from: startDate, to: endDate) { [weak self] workouts, error in
            Task { @MainActor [weak self] in
                defer { group.leave() }
                guard let self else { return }

                if let workouts = workouts {
                    self.recentWorkouts = workouts
                }
                if let error = error {
                    self.error = error
                }
            }
        }
        
        // When all data is loaded, update the loading state
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.isLoading = false
            self.metricsUploader.uploadSnapshot(from: self, date: date)
            self.ensureWearableSync()
        }
    }
    
    // MARK: - Helper methods
    
    // Format sleep duration as a string (e.g., "7hr 32min")
    var formattedSleepDuration: String {
        return "\(Int(sleepHours))hr \(sleepMinutes)min"
    }
    
    // Backward compatibility method - calls reloadHealthData with the current date
    func reloadHealthData() {
        reloadHealthData(for: currentDate)
    }
    
    // MARK: - Activity Log Conversion
    
    /// Convert HKWorkout objects to ActivitySummary for display in logs
    func getActivityLogs(for date: Date) -> [ActivitySummary] {
        let calendar = Calendar.current
        let targetWorkouts = recentWorkouts.filter { workout in
            calendar.isDate(workout.startDate, inSameDayAs: date)
        }
        
        return targetWorkouts.map { workout in
            ActivitySummary(
                id: workout.uuid.uuidString,
                workoutActivityType: workoutTypeToString(workout.workoutActivityType),
                displayName: workoutDisplayName(workout.workoutActivityType),
                duration: workout.duration,
                totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                totalDistance: workout.totalDistance?.doubleValue(for: .meter()),
                startDate: workout.startDate,
                endDate: workout.endDate
            )
        }
    }
    
    private func workoutTypeToString(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .swimming:
            return "Swimming"
        case .hiking:
            return "Hiking"
        case .yoga:
            return "Yoga"
        case .functionalStrengthTraining:
            return "FunctionalStrengthTraining"
        case .traditionalStrengthTraining:
            return "StrengthTraining"
        case .tennis:
            return "Tennis"
        case .basketball:
            return "Basketball"
        case .soccer:
            return "Soccer"
        case .rowing:
            return "Rowing"
        case .elliptical:
            return "Elliptical"
        case .stairClimbing:
            return "StairClimbing"
        default:
            return "Other"
        }
    }
    
    private func workoutDisplayName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .swimming:
            return "Swimming"
        case .hiking:
            return "Hiking"
        case .yoga:
            return "Yoga"
        case .functionalStrengthTraining:
            return "Strength Training"
        case .traditionalStrengthTraining:
            return "Weight Training"
        case .tennis:
            return "Tennis"
        case .basketball:
            return "Basketball"
        case .soccer:
            return "Soccer"
        case .rowing:
            return "Rowing"
        case .elliptical:
            return "Elliptical"
        case .stairClimbing:
            return "Stair Climbing"
        default:
            return "Workout"
        }
    }
}

extension HealthKitViewModel {
    func ensureWearableSync(force: Bool = false, days: Int = 7) {
        print("[HealthKitVM] ensureWearableSync invoked force=\(force)")
        syncRecentMetricsIfNeeded(force: force, days: days)
    }

    private func syncRecentMetricsIfNeeded(force: Bool, days: Int) {
        guard isAuthorized else {
            print("[HealthKitVM] wearable sync skipped – not authorized")
            return
        }
        let lastSyncDate = UserDefaults.standard.object(forKey: wearableBackfillKey) as? Date
        let startOfToday = calendar.startOfDay(for: Date())
        if !force, let lastSyncDate = lastSyncDate, calendar.isDate(lastSyncDate, inSameDayAs: startOfToday) {
            print("[HealthKitVM] wearable sync already ran for today")
            return
        }
        guard !isBackfilling else {
            print("[HealthKitVM] wearable sync already in progress")
            return
        }
        isBackfilling = true
        Task { [weak self] in
            await self?.syncRecentMetrics(days: days)
        }
    }

    @MainActor
    private func syncRecentMetrics(days: Int) async {
        defer { isBackfilling = false }
        guard isAuthorized else { return }
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail"), !userEmail.isEmpty else { return }

        let startOfToday = calendar.startOfDay(for: Date())
        var uploadedAny = false

        print("[HealthKitVM] wearable sync started for user \(userEmail), days=\(days)")

        for offset in 0..<days {
            guard let targetDate = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { continue }
            if let payload = await buildPayload(for: targetDate, userEmail: userEmail) {
                await uploadPayload(payload)
                uploadedAny = true
            }
        }

        if uploadedAny {
            UserDefaults.standard.set(startOfToday, forKey: wearableBackfillKey)
        }
    }

    private func buildPayload(for date: Date, userEmail: String) async -> AgentDailyMetricsPayload? {
        print("[HealthKitVM] building wearable payload for \(date)")
        let stepCountValue = await fetchDouble(for: date, using: healthKitManager.fetchStepCount)
        let sleepSummary = await fetchSleepSummary(for: date)
        let dayKey = calendar.startOfDay(for: date)
        if let summary = sleepSummary {
            sleepSummaryCache[dayKey] = summary
        }
        var effectiveSleepSummary = sleepSummaryCache[dayKey]
        if effectiveSleepSummary == nil,
           dayKey == calendar.startOfDay(for: currentDate),
           let latest = latestSleepSummary {
            sleepSummaryCache[dayKey] = latest
            effectiveSleepSummary = latest
        }
        let activeEnergy = await fetchDouble(for: date, using: healthKitManager.fetchActiveEnergy)
        let basalEnergy = await fetchDouble(for: date, using: healthKitManager.fetchBasalEnergy)
        let waterLiters = await fetchDouble(for: date, using: healthKitManager.fetchWaterIntake)
        let restingHR = await fetchDouble(for: date, using: healthKitManager.fetchRestingHeartRate)
        let hrvScore = await fetchDouble(for: date, using: healthKitManager.fetchHeartRateVariability)
        let walkingHR = await fetchDouble(for: date, using: healthKitManager.fetchWalkingHeartRateAverage)
        let respiratoryRate = await fetchDouble(for: date, using: healthKitManager.fetchRespiratoryRate)
        let bodyTemperature = await fetchDouble(for: date, using: healthKitManager.fetchBodyTemperature)

        let sleepHours = effectiveSleepSummary.map { $0.totalSleepMinutes / 60.0 }
        let hydrationOz = waterLiters.map { $0 * 33.814 }

        let caloriesBurned: Double?
        if let activeEnergy = activeEnergy, let basalEnergy = basalEnergy {
            caloriesBurned = activeEnergy + basalEnergy
        } else if let activeEnergy = activeEnergy {
            caloriesBurned = activeEnergy
        } else if let basalEnergy = basalEnergy {
            caloriesBurned = basalEnergy
        } else {
            caloriesBurned = nil
        }

        let stepCountInt = stepCountValue.map { Int($0.rounded()) }

        let hasSignal = [
            stepCountInt != nil,
            sleepHours != nil,
            hydrationOz != nil,
            caloriesBurned != nil,
            restingHR != nil,
            hrvScore != nil,
            walkingHR != nil,
            respiratoryRate != nil,
            bodyTemperature != nil,
            sleepSummary != nil
        ].contains(true)

        guard hasSignal else {
            print("[HealthKitVM] skipping wearable payload for \(payloadDateTimeFormatter.string(from: date)) - no HealthKit signals")
            return nil
        }

        let sleepMetricsDict = effectiveSleepSummary?.dictionaryRepresentation(formatter: payloadDateTimeFormatter)

        if let dict = sleepMetricsDict {
            print("[HealthKitVM] uploading sleep metrics for \(payloadDateTimeFormatter.string(from: date)):", dict)
        } else {
            print("[HealthKitVM] no sleep metrics for \(payloadDateTimeFormatter.string(from: date))")
        }

        return AgentDailyMetricsPayload(
            userEmail: userEmail,
            date: date,
            stepCount: stepCountInt,
            sleepHours: sleepHours,
            sleepScore: nil,
            restingHeartRate: restingHR,
            hrvScore: hrvScore,
            recoveryScore: nil,
            fatigueLevel: nil,
            sorenessLevel: nil,
            sorenessNotes: nil,
            painFlags: nil,
            hydrationOz: hydrationOz,
            caloriesBurned: caloriesBurned,
            caloriesConsumed: nil,
            macroTargets: nil,
            macroActuals: nil,
            calendarConstraints: nil,
            equipmentAvailable: nil,
            readinessNotes: nil,
            walkingHeartRateAverage: walkingHR,
            sleepMetrics: sleepMetricsDict,
            respiratoryRate: respiratoryRate,
            skinTemperatureC: bodyTemperature
        )
    }

    private func uploadPayload(_ payload: AgentDailyMetricsPayload) async {
        await withCheckedContinuation { continuation in
            AgentService.shared.syncDailyMetrics(payload: payload) { result in
                if case let .failure(error) = result {
                    print("⚠️ Failed to sync daily metrics for \(payload.date): \(error.localizedDescription)")
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func fetchSleepSummary(for date: Date) async -> SleepSummary? {
        await withCheckedContinuation { continuation in
            healthKitManager.fetchSleepSummary(for: date) { summary, error in
                if let error = error {
                    print("⚠️ HealthKit sleep fetch error: \(error.localizedDescription)")
                }
                if let summary {
                    print("[HealthKitVM] fetched sleep summary for \(date): total=\(summary.totalSleepMinutes) inBed=\(summary.inBedMinutes)")
                } else {
                    print("[HealthKitVM] no sleep summary from HealthKit for \(date)")
                }
                continuation.resume(returning: summary)
            }
        }
    }

    private func fetchDouble(
        for date: Date,
        using fetcher: @escaping (Date, @escaping (Double?, Error?) -> Void) -> Void
    ) async -> Double? {
        await withCheckedContinuation { continuation in
            fetcher(date) { value, error in
                if let error = error {
                    print("⚠️ HealthKit fetch error: \(error.localizedDescription)")
                }
                continuation.resume(returning: value)
            }
        }
    }
}
 
