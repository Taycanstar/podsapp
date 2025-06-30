import SwiftUI

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
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var activeTeamId: Int?
    @Published var activeWorkspaceId: Int?
    @Published var profileInitial: String = ""
    @Published var profileColor: String = ""
    @Published var userId: Int?
    
    // Food container visibility control
    @Published var isShowingFoodContainer: Bool = false
    
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
    
    // MARK: - Server Communication
    private let networkManager = NetworkManagerTwo.shared
    
    // Computed property to get current progress
    var progress: CGFloat {
        return OnboardingProgress.progressFor(screen: currentFlowStep.asScreen)
    }
    
    init() {
        loadOnboardingState()
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
    
    func completeOnboarding() {
        // First, ensure we're on the final step
        currentFlowStep = .complete
        
        // Set default values for removed screens
        UserDefaults.standard.set(true, forKey: "addCaloriesBurned") // Default to true for calories burned
        UserDefaults.standard.set(false, forKey: "rolloverCalories") // Default to false for rollover calories
        
        // Create OnboardingData struct with all collected data
        let onboardingData = OnboardingData(
            email: UserDefaults.standard.string(forKey: "userEmail") ?? "",
            gender: UserDefaults.standard.string(forKey: "gender") ?? "",
            dateOfBirth: UserDefaults.standard.string(forKey: "dateOfBirth") ?? "",
            heightCm: UserDefaults.standard.double(forKey: "heightCentimeters"),
            weightKg: UserDefaults.standard.double(forKey: "weightKilograms"),
            desiredWeightKg: UserDefaults.standard.double(forKey: "desiredWeightKilograms"),
            dietGoal: UserDefaults.standard.string(forKey: "dietGoal") ?? "",
            workoutFrequency: UserDefaults.standard.string(forKey: "workoutFrequency") ?? "",
            dietPreference: UserDefaults.standard.string(forKey: "dietPreference") ?? "",
            primaryWellnessGoal: UserDefaults.standard.string(forKey: "primaryWellnessGoal") ?? "",
            goalTimeframeWeeks: UserDefaults.standard.integer(forKey: "goalTimeframeWeeks"),
            weeklyWeightChange: UserDefaults.standard.double(forKey: "weeklyWeightChange"),
            obstacles: UserDefaults.standard.stringArray(forKey: "selectedObstacles"),
            addCaloriesBurned: UserDefaults.standard.bool(forKey: "addCaloriesBurned"),
            rolloverCalories: UserDefaults.standard.bool(forKey: "rolloverCalories"),
            fitnessLevel: UserDefaults.standard.string(forKey: "fitnessLevel"),
            fitnessGoal: UserDefaults.standard.string(forKey: "fitnessGoalType"),
            sportType: UserDefaults.standard.string(forKey: "sportType")
        )
        
        // Debug log
        print("📊 Sending onboarding data - Height: \(onboardingData.heightCm)cm, Weight: \(onboardingData.weightKg)kg, Desired: \(onboardingData.desiredWeightKg)kg")
        
        // Send data to server using NetworkManagerTwo
        let networkManager = NetworkManagerTwo()
        networkManager.processOnboardingData(userData: onboardingData) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✓ Successfully processed onboarding data with server")
                    // Now mark as completed locally
                    self.onboardingCompleted = true
                    self.saveOnboardingState()
                    
                    // Mark that onboarding is no longer in progress
                    UserDefaults.standard.set(false, forKey: "onboardingInProgress")
                    
                    // Ensure all state is synchronized
                    UserDefaults.standard.synchronize()
                case .failure(let error):
                    print("⚠️ Failed to process onboarding data with server: \(error)")
                    // Handle error case
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
    func showFoodContainer(selectedMeal: String? = nil) {
        if let meal = selectedMeal {
            // Store the selected meal for FoodContainerView to use
            UserDefaults.standard.set(meal, forKey: "selectedMealFromNewSheet")
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
        guard !email.isEmpty else {
            profileError = "No user email available"
            return
        }
        
        isLoadingProfile = true
        profileError = nil
        
        networkManager.fetchProfileData(userEmail: email) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingProfile = false
                
                switch result {
                case .success(let data):
                    self?.profileData = data
                    self?.updateLocalUserData(from: data)
                    // Mark the fetch timestamp
                    UserDefaults.standard.set(Date(), forKey: "lastProfileDataFetch")
                case .failure(let error):
                    self?.profileError = error.localizedDescription
                }
            }
        }
    }
    
    /// Update local user data from profile response
    private func updateLocalUserData(from profileData: ProfileDataResponse) {
        // Update OnboardingViewModel properties
        if username != profileData.username {
            username = profileData.username
            UserDefaults.standard.set(profileData.username, forKey: "username")
        }
        
        if profileInitial != profileData.profileInitial {
            profileInitial = profileData.profileInitial
            UserDefaults.standard.set(profileData.profileInitial, forKey: "profileInitial")
        }
        
        if profileColor != profileData.profileColor {
            profileColor = profileData.profileColor
            UserDefaults.standard.set(profileData.profileColor, forKey: "profileColor")
        }
        
        // Save additional profile data to UserDefaults
        if let weightLbs = profileData.currentWeightLbs {
            UserDefaults.standard.set(weightLbs, forKey: "currentWeightLbs")
        }
        
        UserDefaults.standard.set(profileData.calorieGoal, forKey: "calorieGoal")
        UserDefaults.standard.set(profileData.proteinGoal, forKey: "proteinGoal")
        UserDefaults.standard.set(profileData.carbsGoal, forKey: "carbsGoal")
        UserDefaults.standard.set(profileData.fatGoal, forKey: "fatGoal")
        
        UserDefaults.standard.synchronize()
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
