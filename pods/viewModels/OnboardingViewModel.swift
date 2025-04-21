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
        case onboardingGoal = 4
        case desiredWeight = 5
        case goalInfo = 6
        case goalTime = 7
        case twoX = 8
        case obstacles = 9
        case specificDiet = 10
        case accomplish = 11
        case connectHealth = 12
        case caloriesBurned = 13
        case rollover = 14
        case complete = 15
        
        // Return view type for this step
        var viewType: String {
            switch self {
            case .gender: return "GenderView"
            case .workoutDays: return "WorkoutDaysView"
            case .heightWeight: return "HeightWeightView"
            case .dob: return "DobView"
            case .onboardingGoal: return "OnboardingGoal"
            case .desiredWeight: return "DesiredWeightView"
            case .goalInfo: return "GoalInfoView"
            case .goalTime: return "GoalTimeView"
            case .twoX: return "TwoXView"
            case .obstacles: return "ObstaclesView"
            case .specificDiet: return "SpecificDietView"
            case .accomplish: return "AccomplishView"
            case .connectHealth: return "ConnectToAppleHealth"
            case .caloriesBurned: return "CaloriesBurnedView"
            case .rollover: return "RolloverView"
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
            case .onboardingGoal: return .onboardingGoal
            case .desiredWeight: return .desiredWeight
            case .goalInfo: return .goalInfo
            case .goalTime: return .goalTime
            case .twoX: return .twoX
            case .obstacles: return .obstacles
            case .specificDiet: return .specificDiet
            case .accomplish: return .accomplish
            case .connectHealth: return .connectHealth
            case .caloriesBurned: return .caloriesBurned
            case .rollover: return .rollover
            case .complete: return .complete
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
    
    // Add this property with the others
    @Published var isShowingOnboarding: Bool = false
    
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
    }
    
    func completeOnboarding() {
        onboardingCompleted = true
        saveOnboardingState()
    }
    
    // MARK: - Persistence
    
     func saveOnboardingState() {
        UserDefaults.standard.set(currentFlowStep.rawValue, forKey: "onboardingFlowStep")
        UserDefaults.standard.set(onboardingCompleted, forKey: "onboardingCompleted")
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
    func showFoodContainer() {
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
}
