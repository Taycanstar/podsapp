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

    private let muscleRecoveryOverridesKey = "muscleRecoveryOverrides"
    
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
    
    // Fitness Profile (Prefer local override for immediate UI, server fallback)
    var fitnessGoal: FitnessGoal {
        get {
            // Prefer local override (immediate UI feedback)
            if let stored = UserDefaults.standard.string(forKey: "fitnessGoalType"), !stored.isEmpty {
                return FitnessGoal.from(string: stored)
            }

            // Server fallback
            if let profileData = profileData,
               let workoutProfile = profileData.workoutProfile {
                return FitnessGoal.from(string: workoutProfile.fitnessGoal)
            }

            // Default
            return .strength
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "fitnessGoalType")
            publishChange()
        }
    }
    
    var experienceLevel: ExperienceLevel {
        get {
            // Prefer local override
            if let stored = UserDefaults.standard.string(forKey: "experienceLevel"),
               let level = ExperienceLevel(rawValue: stored) {
                return level
            }

            // Server fallback
            if let profileData = profileData,
               let workoutProfile = profileData.workoutProfile {
                let levelString = workoutProfile.fitnessLevel
                return ExperienceLevel(rawValue: levelString) ?? .beginner
            }

            // Default
            return .beginner
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "experienceLevel")
            publishChange()
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
    
    // Workout Preferences (Prefer local override for immediate UI)
    var availableTime: Int {
        get {
            // Prefer local override
            let local = UserDefaults.standard.integer(forKey: "availableTime")
            if local > 0 { return local }

            // Server fallback
            if let profileData = profileData,
               let workoutProfile = profileData.workoutProfile {
                return workoutProfile.preferredWorkoutDuration
            }

            // Default
            return 45
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "availableTime")
            publishChange()
        }
    }

    // MARK: - Advanced Workout Defaults (client-first with server-ready keys)
    // Backward-compatible: stored in UserDefaults; safe if backend lacks fields

    // Global gate: enable auto grouping (circuits/supersets)
    var circuitsAndSupersetsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "circuitsAndSupersetsEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "circuitsAndSupersetsEnabled")
            publishChange()
        }
    }

    // Alias used by generation services
    var autoGroupingEnabled: Bool { circuitsAndSupersetsEnabled }

    // Timed intervals finisher/blocks gate
    var timedIntervalsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "timedIntervalsEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "timedIntervalsEnabled")
            publishChange()
        }
    }

    // Warm-up sets toggle (maps to server's enable_warmup_sets). Default ON if unset.
    var warmupSetsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "warmupSetsEnabled") == nil {
                return true // align with server default_warmup_enabled=True
            }
            return UserDefaults.standard.bool(forKey: "warmupSetsEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "warmupSetsEnabled")
            publishChange()
        }
    }

    // Exercise variability preference (consistency vs. variety)
    var exerciseVariability: ExerciseVariabilityPreference {
        get {
            let raw = UserDefaults.standard.string(forKey: "exerciseVariability") ?? ExerciseVariabilityPreference.balanced.rawValue
            return ExerciseVariabilityPreference(rawValue: raw) ?? .balanced
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "exerciseVariability")
            publishChange()
        }
    }

    // Training split preference
    var trainingSplit: TrainingSplitPreference {
        get {
            let raw = UserDefaults.standard.string(forKey: "trainingSplit") ?? TrainingSplitPreference.fresh.rawValue
            return TrainingSplitPreference(rawValue: raw) ?? .fresh
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "trainingSplit")
            publishChange()
        }
    }

    // Muscle recovery target percentage (future; display-only for now)
    var muscleRecoveryTargetPercent: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "muscleRecoveryTargetPercent")
            return val == 0 ? 70 : val // default 70%
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "muscleRecoveryTargetPercent")
            publishChange()
        }
    }

    var muscleRecoveryOverrides: [String: Double] {
        get {
            guard let data = UserDefaults.standard.data(forKey: muscleRecoveryOverridesKey),
                  let overrides = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return overrides
        }
        set {
            if newValue.isEmpty {
                UserDefaults.standard.removeObject(forKey: muscleRecoveryOverridesKey)
            } else if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: muscleRecoveryOverridesKey)
            }
            publishChange()
        }
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

    // MARK: - Exercise Recommendation Preferences (More/Less Often)
    // Persist lightweight per-exercise bias to nudge selection probability
    // Storage format: ["<exerciseId>": bias], where bias > 0 = more often, bias < 0 = less often
    private let preferenceBiasesKey = "exercisePreferenceBiases"

    private var rawPreferenceBiases: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: preferenceBiasesKey) as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: preferenceBiasesKey) }
    }

    func getExercisePreferenceBias(exerciseId: Int) -> Int {
        rawPreferenceBiases[String(exerciseId)] ?? 0
    }

    func setExercisePreferenceMoreOften(exerciseId: Int) {
        // +3 bias to meaningfully bump ranking without overpowering other factors
        var map = rawPreferenceBiases
        map[String(exerciseId)] = 3
        rawPreferenceBiases = map
        // Ensure not avoided
        removeFromAvoided(exerciseId)
        publishChange()
    }

    func setExercisePreferenceLessOften(exerciseId: Int) {
        // -2 bias to gently reduce frequency
        var map = rawPreferenceBiases
        map[String(exerciseId)] = -2
        rawPreferenceBiases = map
        // Ensure not avoided
        removeFromAvoided(exerciseId)
        publishChange()
    }

    func clearExercisePreference(exerciseId: Int) {
        var map = rawPreferenceBiases
        map.removeValue(forKey: String(exerciseId))
        rawPreferenceBiases = map
        publishChange()
    }

    func addToAvoided(_ exerciseId: Int) {
        var avoided = avoidedExercises
        if !avoided.contains(exerciseId) {
            avoided.append(exerciseId)
            avoidedExercises = avoided
        }
        // Clear bias if now fully avoided
        clearExercisePreference(exerciseId: exerciseId)
        publishChange()
    }

    func removeFromAvoided(_ exerciseId: Int) {
        var avoided = avoidedExercises
        if let idx = avoided.firstIndex(of: exerciseId) {
            avoided.remove(at: idx)
            avoidedExercises = avoided
        }
        publishChange()
    }

    // MARK: - Publishing helpers
    private func publishChange() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
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
        // Phase 2: RIR-based learning layered on recent performance
        guard let performance = getExercisePerformance(exerciseId: exerciseId) else {
            return nil
        }
        let recent = performance.recentRecords(limit: 3)
        guard let lastWeight = recent.first?.weight, lastWeight > 0 else {
            return nil
        }

        // Pull recent RIR history (last 3 entries)
        let rirs = getRIRHistory(exerciseId: exerciseId)
        guard !rirs.isEmpty else {
            // Default small progression if no RIR data
            return lastWeight * 1.025
        }

        // Auto-deload trigger: 3 consecutive tough sessions
        if rirs.count >= 3 && rirs.prefix(3).allSatisfy({ $0 <= 1.0 }) {
            return lastWeight * 0.90 // -10%
        }

        let avg = rirs.reduce(0, +) / Double(rirs.count)
        var adj: Double
        if avg <= 1.0 {        // too heavy
            adj = -0.07
        } else if avg <= 2.0 { // just right
            adj = 0.025
        } else {               // too light
            adj = 0.07
        }

        // Safety: require 2+ readings for larger moves
        if rirs.count < 2 {
            if adj > 0 { adj = min(adj, 0.025) } else { adj = max(adj, -0.05) }
        }

        // Cap single-session increases by experience
        let cap: Double = {
            switch experienceLevel {
            case .beginner: return 0.10
            case .intermediate: return 0.12
            case .advanced: return 0.15
            }
        }()
        if adj > 0 { adj = min(adj, cap) }

        let rec = max(5.0, lastWeight * (1 + adj))
        return rec
    }

    // MARK: - RIR History (lightweight persistence)
    private var rirHistoryKey: String { "exerciseRIRHistory" }
    private var rirHistory: [String: [Double]] {
        get { (UserDefaults.standard.dictionary(forKey: rirHistoryKey) as? [String: [Double]]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: rirHistoryKey) }
    }

    func appendRIRValue(exerciseId: Int, rir: Double) {
        guard rir >= 0 else { return }
        var hist = rirHistory
        var arr = hist[String(exerciseId)] ?? []
        arr.insert(rir, at: 0) // most recent first
        if arr.count > 3 { arr = Array(arr.prefix(3)) }
        hist[String(exerciseId)] = arr
        rirHistory = hist
    }

    func getRIRHistory(exerciseId: Int) -> [Double] {
        rirHistory[String(exerciseId)] ?? []
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

enum ExerciseVariabilityPreference: String, CaseIterable, Codable {
    case consistent = "consistent"   // More Consistent
    case balanced = "balanced"      // Balanced
    case variable = "variable"      // More Variable

    var displayName: String {
        switch self {
        case .consistent: return "More Consistent"
        case .balanced:   return "Balanced"
        case .variable:   return "More Variable"
        }
    }
}

enum TrainingSplitPreference: String, CaseIterable, Codable {
    case fresh = "fresh"
    case upperLower = "upper_lower"
    case fullBody = "full_body"
    case pushPullLower = "push_pull_lower"

    var displayName: String {
        switch self {
        case .fresh: return "Fresh Muscle Groups"
        case .upperLower: return "Upper/Lower Split"
        case .fullBody: return "Full Body"
        case .pushPullLower: return "Push/Pull/Lower Split"
        }
    }
}

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
