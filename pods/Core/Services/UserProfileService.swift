//
//  UserProfileService.swift
//  Pods
//
//  Created by Dimi Nunez on 7/10/25.
//

import Foundation

/// Service to manage user profile data and preferences for workout recommendations
/// Now uses server data as primary source with UserDefaults fallback for backward compatibility
class UserProfileService: ObservableObject {
    static let shared = UserProfileService()
    
    @Published var profileData: ProfileDataResponse?
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    
    // MARK: - Fitbod-Aligned Progressive Milestone Tracking
    
    /// Track workout milestones for progressive exercise unlocking
    private var workoutMilestones: [String: Int] {
        get {
            UserDefaults.standard.dictionary(forKey: "workout_milestones") as? [String: Int] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "workout_milestones")
        }
    }
    
    /// Get total completed workouts for milestone tracking
    var completedWorkouts: Int {
        workoutMilestones["total_workouts"] ?? 0
    }
    
    /// Check if user has earned intermediate level (20+ workouts)
    var hasEarnedIntermediate: Bool {
        completedWorkouts >= 20
    }
    
    /// Check if user has earned advanced level (50+ workouts)
    var hasEarnedAdvanced: Bool {
        completedWorkouts >= 50
    }
    
    /// Record workout completion for milestone tracking
    func recordWorkoutCompletion() {
        var milestones = workoutMilestones
        milestones["total_workouts"] = (milestones["total_workouts"] ?? 0) + 1
        workoutMilestones = milestones
        
        let totalWorkouts = milestones["total_workouts"] ?? 0
        print("🏃‍♂️ Workout #\(totalWorkouts) completed! Milestones: Intermediate(\(hasEarnedIntermediate)) Advanced(\(hasEarnedAdvanced))")
        
        // Suggest level progression if milestones reached
        if totalWorkouts == 20 && experienceLevel == .beginner {
            print("🎉 MILESTONE REACHED: 20 workouts completed! Consider upgrading to Intermediate level.")
        } else if totalWorkouts == 50 && experienceLevel == .intermediate {
            print("🚀 MILESTONE REACHED: 50 workouts completed! Consider upgrading to Advanced level.")
        }
    }
    
    private init() {
        // Try to load cached profile data on initialization
        loadCachedProfileData()
    }
    
    // MARK: - Server Data Integration
    
    /// Update profile data from server response
    func updateFromServer(serverData: [String: Any]) {
        print("📝 UserProfileService: Updating profile from server data")
        print("   └── Data keys: \(serverData.keys.joined(separator: ", "))")
        
        // Update DataLayer cache with server data
        Task {
            await DataLayer.shared.updateProfileData(serverData)
            print("✅ UserProfileService: Profile data updated in DataLayer")
        }
    }
    
    /// Load cached profile data from UserDefaults
    private func loadCachedProfileData() {
        if let data = UserDefaults.standard.data(forKey: "cachedProfileData"),
           let cached = try? JSONDecoder().decode(ProfileDataResponse.self, from: data) {
            self.profileData = cached
            
            // Check if cached data is from today
            if let timestamp = UserDefaults.standard.object(forKey: "profileDataTimestamp") as? Date,
               Calendar.current.isDateInToday(timestamp) {
                self.lastUpdated = timestamp
            }
        }
    }
    
    /// Cache profile data to UserDefaults
    private func cacheProfileData(_ data: ProfileDataResponse) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "cachedProfileData")
            UserDefaults.standard.set(Date(), forKey: "profileDataTimestamp")
        }
    }
    
    /// Check if we should refresh data from server
    var shouldRefreshFromServer: Bool {
        guard let lastUpdated = lastUpdated else { return true }
        return !Calendar.current.isDateInToday(lastUpdated)
    }

    // MARK: - User Profile Data (Server First, UserDefaults Fallback)
    
    // Basic Demographics
    var userAge: Int {
        get {
            // Try server data first
            if let profileData = profileData,
               let dobString = UserDefaults.standard.string(forKey: "dateOfBirth"),
               let dob = ISO8601DateFormatter().date(from: dobString) {
                return Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 25
            }
            
            // Fallback to UserDefaults
            if let dobString = UserDefaults.standard.string(forKey: "dateOfBirth"),
               let dob = ISO8601DateFormatter().date(from: dobString) {
                return Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 25
            }
            return 25 // Default age
        }
    }
    
    var userGender: String {
        get { UserDefaults.standard.string(forKey: "gender") ?? "male" }
        set { UserDefaults.standard.set(newValue, forKey: "gender") }
    }
    
    // Physical Measurements
    var userHeight: Double {
        get {
            // Try server data first
            if let profileData = profileData,
               let heightCm = profileData.heightCm {
                return heightCm
            }
            
            // Fallback to UserDefaults
            let heightCm = UserDefaults.standard.double(forKey: "heightCentimeters")
            return heightCm > 0 ? heightCm : 175.0 // Default 175cm
        }
    }
    
    var userWeight: Double {
        get {
            // Try server data first
            if let profileData = profileData,
               let weightKg = profileData.currentWeightKg {
                return weightKg
            }
            
            // Fallback to UserDefaults
            let weightKg = UserDefaults.standard.double(forKey: "weightKilograms")
            return weightKg > 0 ? weightKg : 70.0 // Default 70kg
        }
    }
    
    // Fitness Profile (Server First)
    var fitnessGoal: FitnessGoal {
        get {
            // Try server data first
            if let profileData = profileData,
               let workoutProfile = profileData.workoutProfile {
                return FitnessGoal.from(string: workoutProfile.fitnessGoal)
            }
            
            // Fallback to UserDefaults
            let goalString = UserDefaults.standard.string(forKey: "fitnessGoalType") ?? "strength"
            return FitnessGoal.from(string: goalString)
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "fitnessGoalType")
        }
    }
    
    var experienceLevel: ExperienceLevel {
        get {
            // Try server data first
            if let profileData = profileData,
               let workoutProfile = profileData.workoutProfile {
                let levelString = workoutProfile.fitnessLevel
                return ExperienceLevel(rawValue: levelString) ?? .beginner
            }
            
            // Fallback to UserDefaults
            let levelString = UserDefaults.standard.string(forKey: "experienceLevel") ?? "beginner"
            return ExperienceLevel(rawValue: levelString) ?? .beginner
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "experienceLevel")
        }
    }
    
    var gender: Gender {
        get {
            // Try server data first (if gender is added to server profile later)
            // For now, use existing userGender property
            let genderString = userGender.capitalized
            return Gender(rawValue: genderString) ?? .male
        }
        set {
            userGender = newValue.rawValue.lowercased()
        }
    }
    
    var workoutFrequency: WorkoutFrequency {
        get {
            // Try server data first
            if let profileData = profileData,
               let workoutProfile = profileData.workoutProfile {
                let freqString = workoutProfile.workoutFrequency
                return WorkoutFrequency.from(string: freqString)
            }
            
            // Fallback to UserDefaults
            let freqString = UserDefaults.standard.string(forKey: "workoutFrequency") ?? "3x per week"
            return WorkoutFrequency(rawValue: freqString) ?? .three
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "workoutFrequency")
        }
    }
    
    // Workout Preferences (Server First)
    var availableTime: Int {
        get {
            // Try server data first
            if let profileData = profileData,
               let workoutProfile = profileData.workoutProfile {
                return workoutProfile.preferredWorkoutDuration
            }
            
            // Fallback to UserDefaults
            return UserDefaults.standard.integer(forKey: "availableTime") != 0 ? UserDefaults.standard.integer(forKey: "availableTime") : 45
        }
        set { UserDefaults.standard.set(newValue, forKey: "availableTime") }
    }
    
    var workoutLocation: WorkoutLocation {
        get {
            // Try server data first
            if let profileData = profileData,
               let workoutProfile = profileData.workoutProfile {
                let locationString = workoutProfile.workoutLocation
                // Map Fitbod-style values to WorkoutLocation enum or use a string for display
                return WorkoutLocation(rawValue: locationString.capitalized) ?? .gym
            }
            // Fallback to UserDefaults
            let locationString = UserDefaults.standard.string(forKey: "workoutLocation") ?? "large_gym"
            return WorkoutLocation(rawValue: locationString.capitalized) ?? .gym
        }
        set {
            UserDefaults.standard.set(newValue.rawValue.lowercased(), forKey: "workoutLocation")
        }
    }
    // Optionally, add a computed property for display:
    var workoutLocationDisplay: String {
        if let profileData = profileData,
           let workoutProfile = profileData.workoutProfile {
            switch workoutProfile.workoutLocation {
            case "large_gym": return "Large Gym"
            case "small_gym": return "Small Gym"
            case "garage_gym": return "Garage Gym"
            case "home": return "At Home"
            case "bodyweight": return "Bodyweight Only"
            case "custom": return "Custom"
            default: return "Gym"
            }
        }
        return "Gym"
    }
    
    var availableEquipment: [Equipment] {
        get {
            // Try server data first
            if let profileData = profileData,
               let workoutProfile = profileData.workoutProfile {
                let equipmentStrings = workoutProfile.availableEquipment
                return equipmentStrings.compactMap { Equipment(rawValue: $0) }
            }
            
            // Fallback to UserDefaults
            let equipmentStrings = UserDefaults.standard.stringArray(forKey: "availableEquipment") ?? []
            return equipmentStrings.compactMap { Equipment(rawValue: $0) }
        }
        set {
            let equipmentStrings = newValue.map { $0.rawValue }
            UserDefaults.standard.set(equipmentStrings, forKey: "availableEquipment")
        }
    }
    
    var preferredExerciseTypes: [ExerciseType] {
        get {
            let typeStrings = UserDefaults.standard.stringArray(forKey: "preferredExerciseTypes") ?? []
            return typeStrings.compactMap { ExerciseType(rawValue: $0) }
        }
        set {
            let typeStrings = newValue.map { $0.rawValue }
            UserDefaults.standard.set(typeStrings, forKey: "preferredExerciseTypes")
        }
    }
    
    var avoidedExercises: [Int] {
        get { UserDefaults.standard.array(forKey: "avoidedExercises") as? [Int] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "avoidedExercises") }
    }

    // MARK: - Workout History & Progress
    
    func getWorkoutHistory() -> [WorkoutHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: "workoutHistory"),
              let history = try? JSONDecoder().decode([WorkoutHistoryEntry].self, from: data) else {
            return []
        }
        return history
    }
    
    func saveWorkoutHistory(_ history: [WorkoutHistoryEntry]) {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "workoutHistory")
        }
    }
    
    func addWorkoutToHistory(_ workout: WorkoutHistoryEntry) {
        var history = getWorkoutHistory()
        history.append(workout)
        
        // Keep only last 100 workouts
        if history.count > 100 {
            history = Array(history.suffix(100))
        }
        
        saveWorkoutHistory(history)
    }
    
    // MARK: - Exercise Performance Tracking
    
    func getExercisePerformance(exerciseId: Int) -> ExercisePerformance? {
        let key = "exercise_performance_\(exerciseId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let performance = try? JSONDecoder().decode(ExercisePerformance.self, from: data) else {
            return nil
        }
        return performance
    }
    
    func saveExercisePerformance(_ performance: ExercisePerformance) {
        let key = "exercise_performance_\(performance.exerciseId)"
        if let data = try? JSONEncoder().encode(performance) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func updateExercisePerformance(exerciseId: Int, sets: Int, reps: Int, weight: Double) {
        var performance = getExercisePerformance(exerciseId: exerciseId) ?? ExercisePerformance(exerciseId: exerciseId)
        
        let newRecord = PerformanceRecord(
            date: Date(),
            sets: sets,
            reps: reps,
            weight: weight,
            volume: Double(sets * reps) * weight
        )
        
        performance.addRecord(newRecord)
        saveExercisePerformance(performance)
    }
    
    // MARK: - Smart Recommendations
    
    func getRecommendedWeight(exerciseId: Int) -> Double? {
        guard let performance = getExercisePerformance(exerciseId: exerciseId) else {
            return nil
        }
        
        // Get the most recent successful weight
        let recentRecords = performance.recentRecords(limit: 3)
        if let lastWeight = recentRecords.first?.weight {
            // Progressive overload: increase by 2.5-5% based on experience
            let progressionRate = experienceLevel.workoutComplexity == 1 ? 0.025 : 0.05
            return lastWeight * (1 + progressionRate)
        }
        
        return nil
    }
    
    func getRecommendedReps(exerciseId: Int) -> Int? {
        guard let performance = getExercisePerformance(exerciseId: exerciseId) else {
            return nil
        }
        
        let recentRecords = performance.recentRecords(limit: 5)
        if let avgReps = recentRecords.map({ $0.reps }).average() {
            return Int(avgReps)
        }
        
        return nil
    }
    
    // MARK: - Equipment Filtering
    
    func hasEquipment(_ equipment: Equipment) -> Bool {
        return availableEquipment.contains(equipment)
    }
    
    func canPerformExercise(_ exercise: ExerciseData) -> Bool {
        let equipmentNeeded = mapExerciseToEquipment(exercise)
        
        // If no specific equipment needed, assume bodyweight
        if equipmentNeeded.isEmpty {
            return true
        }
        
        // Check if user has any of the required equipment
        return equipmentNeeded.contains { hasEquipment($0) }
    }
    
    private func mapExerciseToEquipment(_ exercise: ExerciseData) -> [Equipment] {
        let equipmentName = exercise.equipment.lowercased()
        
        switch equipmentName {
        case let name where name.contains("dumbbell"):
            return [.dumbbells]
        case let name where name.contains("barbell"):
            return [.barbells]
        case let name where name.contains("kettlebell"):
            return [.kettlebells]
        case let name where name.contains("cable"):
            return [.cable, .latPulldownCable]
        case let name where name.contains("smith"):
            return [.smithMachine]
        case let name where name.contains("leverage"):
            return [.hammerstrengthMachine]
        case let name where name.contains("band"):
            return [.resistanceBands]
        case let name where name.contains("stability ball"):
            return [.stabilityBall]
        case let name where name.contains("medicine ball"):
            return [.medicineBalls]
        case let name where name.contains("bosu"):
            return [.bosuBalanceTrainer]
        case let name where name.contains("ez"):
            return [.ezBar]
        case let name where name.contains("rope"):
            return [.battleRopes]
        case let name where name.contains("sled"):
            return [.sled]
        case "body weight":
            return [] // No equipment needed
        default:
            return [] // Assume bodyweight if unknown
        }
    }
    
    // MARK: - Default Equipment Setup
    
    func setupDefaultEquipment() {
        if availableEquipment.isEmpty {
            // Set default equipment based on workout location
            switch workoutLocation {
            case .gym:
                availableEquipment = [
                    .dumbbells, .barbells, .cable, .smithMachine, .hammerstrengthMachine,
                    .flatBench, .inclineBench, .pullupBar, .dipBar,
                    .legPress, .latPulldownCable, .rowMachine, .legExtensionMachine, .legCurlMachine
                ]
            case .home:
                availableEquipment = [
                    .dumbbells, .resistanceBands, .stabilityBall,
                    .pullupBar, .flatBench
                ]
            case .outdoor:
                availableEquipment = [
                    .pullupBar, .dipBar, .resistanceBands, .box
                ]
            case .hotel:
                availableEquipment = [
                    .resistanceBands, .stabilityBall
                ]
            }
        }
    }
}

// MARK: - Extensions for Server Data Mapping

extension WorkoutFrequency {
    static func from(string: String) -> WorkoutFrequency {
        switch string.lowercased() {
        case "low":
            return .twice
        case "medium":
            return .three
        case "high":
            return .five
        default:
            return .three
        }
    }
}

// MARK: - Data Models

struct WorkoutHistoryEntry: Codable {
    let id: UUID
    let date: Date
    let exercises: [CompletedExercise]
    let duration: TimeInterval
    let notes: String?
    
    init(exercises: [CompletedExercise], duration: TimeInterval, notes: String? = nil) {
        self.id = UUID()
        self.date = Date()
        self.exercises = exercises
        self.duration = duration
        self.notes = notes
    }
}

struct CompletedExercise: Codable {
    let exerciseId: Int
    let exerciseName: String
    let sets: [CompletedSet]
}

struct CompletedSet: Codable {
    let reps: Int
    let weight: Double
    let restTime: TimeInterval?
    let completed: Bool
}

struct ExercisePerformance: Codable {
    let exerciseId: Int
    var records: [PerformanceRecord]
    
    init(exerciseId: Int) {
        self.exerciseId = exerciseId
        self.records = []
    }
    
    mutating func addRecord(_ record: PerformanceRecord) {
        records.append(record)
        
        // Keep only last 50 records
        if records.count > 50 {
            records = Array(records.suffix(50))
        }
        
        // Sort by date (newest first)
        records.sort { $0.date > $1.date }
    }
    
    func recentRecords(limit: Int = 10) -> [PerformanceRecord] {
        return Array(records.prefix(limit))
    }
    
    func personalBest() -> PerformanceRecord? {
        return records.max { $0.volume < $1.volume }
    }
}

struct PerformanceRecord: Codable {
    let date: Date
    let sets: Int
    let reps: Int
    let weight: Double
    let volume: Double
}

// MARK: - Array Extensions

extension Array where Element == Int {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        return Double(reduce(0, +)) / Double(count)
    }
}

extension Array where Element == Double {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
} 
