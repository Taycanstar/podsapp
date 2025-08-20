import SwiftUI

enum UnitsSystem: String, CaseIterable {
    case imperial = "imperial"
    case metric = "metric"
    
    var displayName: String {
        switch self {
        case .imperial:
            return "Imperial"
        case .metric:
            return "Metric"
        }
    }
}

@MainActor
class OnboardingViewModel: ObservableObject {
    // Original enum for core navigation states
    enum OnboardingStep {
        case landing
        case signup
        case emailVerification
        case info
        case gender
        case welcome
        case login
    }
    
    // Enum defining all detailed onboarding steps in order
    enum OnboardingFlowStep: Int, CaseIterable {
        case gender = 0
        case workoutDays = 1
        case heightWeight = 2
        case dob = 3
        case desiredWeight = 4
        case goalInfo = 5
        case goalTime = 6
        case twoX = 7
        case obstacles = 8
        case specificDiet = 9
        case accomplish = 10
        case fitnessLevel = 11
        case fitnessGoal = 12
        case sportSelection = 13
        case connectHealth = 14
        case complete = 15
        
        // Return view type for this step
        var viewType: String {
            switch self {
            case .gender: return "GenderView"
            case .workoutDays: return "WorkoutDaysView"
            case .heightWeight: return "HeightWeightView"
            case .dob: return "DobView"
            case .desiredWeight: return "DesiredWeightView"
            case .goalInfo: return "GoalInfoView"
            case .goalTime: return "GoalTimeView"
            case .twoX: return "TwoXView"
            case .obstacles: return "ObstaclesView"
            case .specificDiet: return "SpecificDietView"
            case .accomplish: return "AccomplishView"
            case .fitnessLevel: return "FitnessLevelView"
            case .fitnessGoal: return "FitnessGoalView"
            case .sportSelection: return "SportSelectionView"
            case .connectHealth: return "ConnectToAppleHealth"
            case .complete: return "CreatingPlanView"
            }
        }
        
        // Convert from FlowStep to OnboardingProgress.Screen
        var asScreen: OnboardingProgress.Screen {
            switch self {
            case .gender: return .gender
            case .workoutDays: return .workoutDays
            case .heightWeight: return .heightWeight
            case .dob: return .dob
            case .desiredWeight: return .desiredWeight
            case .goalInfo: return .goalInfo
            case .goalTime: return .goalTime
            case .twoX: return .twoX
            case .obstacles: return .obstacles
            case .specificDiet: return .specificDiet
            case .accomplish: return .accomplish
            case .fitnessLevel: return .fitnessLevel
            case .fitnessGoal: return .fitnessGoal
            case .sportSelection: return .sportSelection
            case .connectHealth: return .connectHealth
            case .complete: return .creatingPlan
            }
        }
    }
    
    @Published var currentStep: OnboardingStep = .landing
    @Published var currentFlowStep: OnboardingFlowStep = .gender
    @Published var onboardingCompleted: Bool = false
    @Published var email: String = ""
    @Published var region: String = ""
    @Published var name: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var activeTeamId: Int?
    @Published var activeWorkspaceId: Int?
    @Published var profileInitial: String = ""
    @Published var profileColor: String = ""
    @Published var userId: Int?
    
    // Food container visibility control
    @Published var isShowingFoodContainer: Bool = false
    
    // Streak visibility control
    @Published var isStreakVisible: Bool = true {
        didSet {
            // Save to UserDefaults whenever the value changes
            UserDefaults.standard.set(isStreakVisible, forKey: "isStreakVisible")
        }
    }
    
    // Add these new properties for subscription information
    @Published var subscriptionStatus: String = "none"
    @Published var subscriptionPlan: String?
    @Published var subscriptionExpiresAt: String?
    @Published var subscriptionRenews: Bool = false
    @Published var subscriptionSeats: Int?
    @Published var canCreateNewTeam: Bool = false
    
    // Server-reported onboarding completion status
    @Published var serverOnboardingCompleted: Bool = false
    
    // Add this property with the others
    @Published var isShowingOnboarding = false
    
    // MARK: - Profile Data
    @Published var profileData: ProfileDataResponse?
    @Published var isLoadingProfile = false
    @Published var profileError: String?
    
    // MARK: - Units System
    @Published var unitsSystem: UnitsSystem = .imperial {
        didSet {
            // Save to UserDefaults whenever the value changes
            UserDefaults.standard.set(unitsSystem.rawValue, forKey: "unitsSystem")
        }
    }
    
    // MARK: - Onboarding Data Properties
    @Published var gender: String = ""
    @Published var dateOfBirth: Date?
    @Published var heightCm: Double = 0.0
    @Published var weightKg: Double = 0.0
    @Published var desiredWeightKg: Double = 0.0
    @Published var dietGoal: String = ""
    @Published var fitnessGoal: String = ""
    @Published var goalTimeframeWeeks: Int = 0
    @Published var weeklyWeightChange: Double = 0.0
    @Published var workoutFrequency: String = ""
    @Published var dietPreference: String = ""
    @Published var primaryWellnessGoal: String = ""
    @Published var obstacles: [String] = []
    @Published var addCaloriesBurned: Bool = false
    @Published var rolloverCalories: Bool = false
    @Published var availableEquipment: [String] = []
    @Published var workoutLocation: String = ""
    @Published var preferredWorkoutDuration: Int = 0
    @Published var workoutDaysPerWeek: Int = 0
    @Published var restDays: [String] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Server Communication
    private let networkManager = NetworkManagerTwo.shared
    
    // Computed property to get current progress
    var progress: CGFloat {
        return OnboardingProgress.progressFor(screen: currentFlowStep.asScreen)
    }
    
    init() {
        loadOnboardingState()
        
        // Load units system from UserDefaults, default to imperial
        if let savedUnitsSystem = UserDefaults.standard.string(forKey: "unitsSystem"),
           let units = UnitsSystem(rawValue: savedUnitsSystem) {
            self.unitsSystem = units
        } else {
            self.unitsSystem = .imperial
            // Save the default value
            UserDefaults.standard.set(UnitsSystem.imperial.rawValue, forKey: "unitsSystem")
        }
        
        // Load streak visibility from UserDefaults, default to true (visible)
        if UserDefaults.standard.object(forKey: "isStreakVisible") != nil {
            self.isStreakVisible = UserDefaults.standard.bool(forKey: "isStreakVisible")
        } else {
            self.isStreakVisible = true
            // Save the default value
            UserDefaults.standard.set(true, forKey: "isStreakVisible")
        }
    }
    
    // MARK: - Onboarding Flow Navigation
    
    func nextStep() {
        guard let nextIndex = OnboardingFlowStep.allCases.firstIndex(where: { $0.rawValue == currentFlowStep.rawValue + 1 }) else {
            // Handle completion of onboarding
            completeOnboarding()
            return
        }
        
        currentFlowStep = OnboardingFlowStep.allCases[nextIndex]
        saveOnboardingState()
    }
    
    func previousStep() {
        guard let prevIndex = OnboardingFlowStep.allCases.firstIndex(where: { $0.rawValue == currentFlowStep.rawValue - 1 }),
              prevIndex >= 0 else {
            return
        }
        
        currentFlowStep = OnboardingFlowStep.allCases[prevIndex]
        saveOnboardingState()
    }
    
    func goToStep(_ step: OnboardingFlowStep) {
        currentFlowStep = step
        saveOnboardingState()
    }
    
    func startOnboarding() {
        currentStep = .gender
        currentFlowStep = .gender
        onboardingCompleted = false
        saveOnboardingState()
        
        // Mark that onboarding is now in progress
        UserDefaults.standard.set(true, forKey: "onboardingInProgress")
    }
    
    // MARK: - Validation
    
    func validateOnboardingData() -> Bool {
        // Basic validation - ensure required fields are filled
        guard !email.isEmpty,
              !gender.isEmpty,
              heightCm > 0,
              weightKg > 0,
              !dietGoal.isEmpty,
              !fitnessGoal.isEmpty else {
            print("❌ OnboardingViewModel: Validation failed - missing required fields")
            return false
        }
        
        print("✅ OnboardingViewModel: Validation passed")
        return true
    }
    
    func completeOnboarding() {
        print("🎯 OnboardingViewModel: Starting onboarding completion process")
        print("   └── User: \(email)")
        print("   └── Data validation: \(validateOnboardingData() ? "✅ Valid" : "❌ Invalid")")
        
        guard validateOnboardingData() else {
            print("❌ OnboardingViewModel: Validation failed - cannot complete onboarding")
            return
        }
        
        isLoading = true
        
        // Prepare onboarding data for DataLayer
        let onboardingData: [String: Any] = [
            "email": email,
            "gender": gender,
            "date_of_birth": dateOfBirth?.ISO8601Format() ?? "",
            "height_cm": heightCm,
            "weight_kg": weightKg,
            "desired_weight_kg": desiredWeightKg,
            "diet_goal": dietGoal,
            "fitness_goal": fitnessGoal,
            "goal_timeframe_weeks": goalTimeframeWeeks,
            "weekly_weight_change": weeklyWeightChange,
            "workout_frequency": workoutFrequency,
            "diet_preference": dietPreference,
            "primary_wellness_goal": primaryWellnessGoal,
            "obstacles": obstacles.joined(separator: ","),
            "add_calories_burned": addCaloriesBurned,
            "rollover_calories": rolloverCalories,
            "available_equipment": availableEquipment,
            "workout_location": workoutLocation,
            "preferred_workout_duration": preferredWorkoutDuration,
            "workout_days_per_week": workoutDaysPerWeek,
            "rest_days": restDays,
            "units_system": unitsSystem.rawValue
        ]
        
        print("📋 OnboardingViewModel: Prepared onboarding data with \(onboardingData.count) fields")
        
        Task {
            do {
                // Use DataLayer for local-first save with background sync
                print("💾 OnboardingViewModel: Saving via DataLayer (local-first strategy)")
                await DataLayer.shared.saveOnboardingData(onboardingData)
                
                // Update local state
                await MainActor.run {
                    print("✅ OnboardingViewModel: Updating local state")
                    self.onboardingCompleted = true
                    self.isLoading = false
                    self.isShowingOnboarding = false
                    
                    // Save completion status
                    UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                    UserDefaults.standard.set(self.email, forKey: "userEmail")
                    
                    print("🎉 OnboardingViewModel: Onboarding completed successfully!")
                    print("   └── User: \(self.email)")
                    print("   └── Data saved locally and queued for sync")
                }
                
            } catch {
                await MainActor.run {
                    print("❌ OnboardingViewModel: Failed to complete onboarding - \(error.localizedDescription)")
                    self.isLoading = false
                    self.errorMessage = "Failed to save onboarding data: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Persistence
    
     func saveOnboardingState() {
        UserDefaults.standard.set(currentFlowStep.rawValue, forKey: "onboardingFlowStep")
        UserDefaults.standard.set(onboardingCompleted, forKey: "onboardingCompleted")
        
        // Save step name for easier restoration
        UserDefaults.standard.set(currentFlowStep.viewType, forKey: "currentOnboardingStep")
    }
    
     func loadOnboardingState() {
        if UserDefaults.standard.bool(forKey: "onboardingCompleted") {
            onboardingCompleted = true
        } else if let stepValue = UserDefaults.standard.object(forKey: "onboardingFlowStep") as? Int,
                  let step = OnboardingFlowStep(rawValue: stepValue) {
            currentFlowStep = step
            currentStep = .gender // We'll use this to trigger showing the onboarding flow
        }
    }
    
    // Method to restore onboarding progress from a specific step name
    func restoreOnboardingProgress(step: String) {
        // Find the corresponding step from viewType
        if let flowStep = OnboardingFlowStep.allCases.first(where: { $0.viewType == step }) {
            currentFlowStep = flowStep
            // Default to gender for initial step
            currentStep = .gender
        }
    }
    
    // Method to load progress when view appears
    func loadProgress() {
        // Check if user is authenticated and load appropriate state
        if UserDefaults.standard.bool(forKey: "isAuthenticated") {
            onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")
            if onboardingCompleted {
            } else if let stepValue = UserDefaults.standard.object(forKey: "onboardingFlowStep") as? Int,
                      let step = OnboardingFlowStep(rawValue: stepValue) {
                currentFlowStep = step
                currentStep = .gender
            }
        }
    }
    
    func updateSubscriptionInfo(status: String?, plan: String?, expiresAt: String?, renews: Bool?, seats: Int?, canCreateNewTeam: Bool?) {
        self.subscriptionStatus = status ?? "none"
        self.subscriptionPlan = plan
        self.subscriptionExpiresAt = expiresAt
        self.subscriptionRenews = renews ?? false
        self.subscriptionSeats = seats
        self.canCreateNewTeam = canCreateNewTeam ?? false
        
        // Also update UserDefaults
        UserDefaults.standard.set(self.subscriptionStatus, forKey: "subscriptionStatus")
        UserDefaults.standard.set(self.subscriptionPlan, forKey: "subscriptionPlan")
        UserDefaults.standard.set(self.subscriptionExpiresAt, forKey: "subscriptionExpiresAt")
        UserDefaults.standard.set(self.subscriptionRenews, forKey: "subscriptionRenews")
        UserDefaults.standard.set(self.subscriptionSeats, forKey: "subscriptionSeats")
    }
    
    // Helper methods to show/hide food container
    func showFoodContainer(selectedMeal: String? = nil, initialTab: String? = nil) {
        if let meal = selectedMeal {
            // Store the selected meal for FoodContainerView to use
            UserDefaults.standard.set(meal, forKey: "selectedMealFromNewSheet")
        }
        if let tab = initialTab {
            // Store the initial tab for FoodContainerView to use
            UserDefaults.standard.set(tab, forKey: "initialFoodTabFromNewSheet")
        }
        isShowingFoodContainer = true
    }
    
    func hideFoodContainer() {
        isShowingFoodContainer = false
    }
    
    func getCurrentSubscriptionTier() -> SubscriptionTier {
        guard let plan = subscriptionPlan else {
            return .none
        }
        return SubscriptionTier(rawValue: plan) ?? .none
    }
    
    func hasActiveSubscription() -> Bool {
        return subscriptionStatus == "active" && subscriptionPlan != nil && subscriptionPlan != "None"
    }
    
    func getActiveSubscriptionType() -> SubscriptionTier {
        guard hasActiveSubscription() else {
            return .none
        }
        return getCurrentSubscriptionTier()
    }
    
    func updateActiveWorkspace(workspaceId: Int) {
        self.activeWorkspaceId = workspaceId
        UserDefaults.standard.set(workspaceId, forKey: "activeWorkspaceId")
    }
    
    // MARK: - Profile Data Methods
    
    /// Fetch comprehensive profile data for the current user
    func fetchProfileData() {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail"), !userEmail.isEmpty else {
            profileError = "No user email available"
            return
        }
        
        isLoadingProfile = true
        profileError = nil
        
        // CRITICAL FIX: Use correct timezone offset instead of defaulting to 0
        let timezoneOffset = TimeZone.current.secondsFromGMT() / 60
        print("🕐 OnboardingViewModel.fetchProfileData - Using timezone offset: \(timezoneOffset) minutes")
        
        // STEP 1: Try to get data from DataLayer first (faster)
        Task {
            if let cachedData = await DataLayer.shared.getData(key: "profile_data") as? [String: Any] {
                await MainActor.run {
                    // Convert cached data to ProfileDataResponse if needed
                    print("🚀 OnboardingViewModel.fetchProfileData - Loaded from DataLayer cache")
                }
            }
        }
        
        // STEP 2: Always fetch fresh data from server and update DataLayer
        networkManager.fetchProfileData(userEmail: userEmail, timezoneOffset: timezoneOffset) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingProfile = false
                
                switch result {
                case .success(let data):
                    self?.profileData = data
                    self?.updateLocalUserData(from: data)
                    
                    // Update UserProfileService with server data
                    let serverData: [String: Any] = [
                        "name": data.name,
                        "username": data.username,
                        "profileInitial": data.profileInitial,
                        "profileColor": data.profileColor
                    ]
                    UserProfileService.shared.updateFromServer(serverData: serverData)
                    
                    // Save to DataLayer for future use
                    Task {
                        await DataLayer.shared.updateProfileData(serverData)
                        print("💾 OnboardingViewModel.fetchProfileData - Saved to DataLayer")
                    }
                    
                    print("✅ OnboardingViewModel.fetchProfileData - Success with timezone offset: \(timezoneOffset)")
                    print("✅ Updated UserProfileService with server data")
                    
                case .failure(let error):
                    self?.profileError = error.localizedDescription
                    print("❌ OnboardingViewModel.fetchProfileData - Error: \(error)")
                }
            }
        }
    }
    
    /// Update local user data from profile response
    private func updateLocalUserData(from profileData: ProfileDataResponse) {
        // Update OnboardingViewModel properties (in memory only, no UserDefaults caching)
        name = profileData.name
        username = profileData.username
        profileInitial = profileData.profileInitial
        profileColor = profileData.profileColor
        
        // No UserDefaults caching - always use fresh data from server
    }
    
    /// Refresh profile data if it's stale (older than 5 minutes)
    func refreshProfileDataIfNeeded() {
        // Only fetch if we don't have data or if it's been a while
        if profileData == nil || isProfileDataStale() {
            fetchProfileData()
        }
    }
    
    private func isProfileDataStale() -> Bool {
        // Check if profile data was fetched more than 5 minutes ago
        if let lastFetch = UserDefaults.standard.object(forKey: "lastProfileDataFetch") as? Date {
            return Date().timeIntervalSince(lastFetch) > 300 // 5 minutes
        }
        return true
    }
}
