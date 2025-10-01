import SwiftUI
import Combine

enum UnitsSystem: String, CaseIterable, Codable {
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
        case fitnessGoal
        case strengthExperience
        case desiredWeight
        case gymLocation
        case workoutSchedule
        case enableNotifications
        case reviewEquipment
        case signup
        case emailVerification
        case info
        case gender
        case welcome
        case login
    }

    enum FitnessGoalOption: String, CaseIterable, Identifiable {
        case liftMoreWeight = "Lift more weight"
        case gainMuscle = "Gain muscle"
        case leanAndToned = "Get lean and toned"
        case loseWeight = "Lose weight"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .liftMoreWeight:
                return "figure.strengthtraining.traditional"
            case .gainMuscle:
                return "bolt.heart"
            case .leanAndToned:
                return "figure.cooldown"
            case .loseWeight:
                return "scalemass"
            }
        }
    }

    enum StrengthExperienceOption: String, CaseIterable, Identifiable {
        case lessThanYear = "Less than a year"
        case oneToTwoYears = "1-2 years"
        case twoToFourYears = "2-4 years"
        case fourPlusYears = "4+ years"

        var id: String { rawValue }

        var experienceLevel: ExperienceLevel {
            switch self {
            case .lessThanYear:
                return .beginner
            case .oneToTwoYears, .twoToFourYears:
                return .intermediate
            case .fourPlusYears:
                return .advanced
            }
        }
    }

    enum GymLocationOption: String, CaseIterable, Identifiable {
        case largeGym
        case smallGym
        case garageGym
        case atHome
        case noEquipment
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .largeGym: return "Large Gym"
            case .smallGym: return "Small Gym"
            case .garageGym: return "Garage Gym"
            case .atHome: return "At Home"
            case .noEquipment: return "No Equipment"
            case .custom: return "Custom"
            }
        }

        var description: String {
            switch self {
            case .largeGym:
                return "Full fitness clubs with wide variety of equipment."
            case .smallGym:
                return "Compact gyms with essential equipment."
            case .garageGym:
                return "Dumbbells, squat rack, barbells and more."
            case .atHome:
                return "Bands, dumbbells, and minimum equipment."
            case .noEquipment:
                return "Bodyweight exercises only."
            case .custom:
                return "Create your equipment list from the ground up."
            }
        }
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
    @Published var email: String = "" {
        didSet {
            if !email.isEmpty {
                bindRepositories(for: email)
            }
        }
    }
    @Published var region: String = ""
    @Published var name: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var activeTeamId: Int?
    @Published var activeWorkspaceId: Int?
    @Published var profileInitial: String = ""
    @Published var profileColor: String = ""
    @Published var userId: Int?
    @Published var selectedFitnessGoal: FitnessGoalOption?
    @Published var selectedStrengthExperience: StrengthExperienceOption?
    @Published var desiredWeight: Double?
    @Published var selectedGymLocation: GymLocationOption? {
        didSet {
            equipmentInventory = equipmentForGymLocation(selectedGymLocation)
        }
    }
    @Published var equipmentInventory: Set<Equipment> = []
    @Published var trainingDaysPerWeek: Int = 3
    @Published var selectedTrainingDays: Set<Weekday> = []
    @Published var preferredWorkoutDays: [String] = []
    @Published var notificationPreviewTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @Published var notificationPreviewTimeISO8601: String = ""
    @Published var newOnboardingStepIndex: Int = 1

    let newOnboardingTotalSteps: Int = 7

    var newOnboardingProgress: Double {
        guard newOnboardingTotalSteps > 0 else { return 0 }
        return min(max(Double(newOnboardingStepIndex) / Double(newOnboardingTotalSteps), 0), 1)
    }

    var strengthExperienceLevel: ExperienceLevel? {
        selectedStrengthExperience?.experienceLevel
    }

    func equipmentForGymLocation(_ location: GymLocationOption?) -> Set<Equipment> {
        guard let location = location else {
            return equipmentInventory
        }

        let list: [Equipment]
        switch location {
        case .largeGym:
            list = Equipment.allCases.filter { $0 != .bodyWeight }
        case .smallGym:
            list = EquipmentView.EquipmentType.smallGym.equipmentList
        case .garageGym:
            list = EquipmentView.EquipmentType.garageGym.equipmentList
        case .atHome:
            list = EquipmentView.EquipmentType.atHome.equipmentList
        case .noEquipment:
            list = []
        case .custom:
            list = Array(equipmentInventory)
        }

        return Set(list)
    }

    func ensureDefaultSchedule() {
        if !preferredWorkoutDays.isEmpty {
            let restoredDays = Set(preferredWorkoutDays.compactMap { Weekday(rawValue: $0) })
            if !restoredDays.isEmpty {
                selectedTrainingDays = restoredDays
                trainingDaysPerWeek = restoredDays.count
                syncWorkoutSchedule()
                return
            }
        }

        if selectedTrainingDays.isEmpty {
            setTrainingDaysPerWeek(trainingDaysPerWeek, autoSelectDays: true)
        } else {
            syncWorkoutSchedule()
        }
    }

    func setTrainingDaysPerWeek(_ days: Int, autoSelectDays: Bool = true) {
        let clamped = min(max(days, 1), Weekday.allCases.count)
        trainingDaysPerWeek = clamped
        if autoSelectDays {
            selectedTrainingDays = Set(Weekday.allCases.prefix(clamped))
        }
        syncWorkoutSchedule()
    }

    func toggleTrainingDay(_ day: Weekday) {
        if selectedTrainingDays.contains(day) {
            selectedTrainingDays.remove(day)
        } else {
            selectedTrainingDays.insert(day)
        }

        if !selectedTrainingDays.isEmpty {
            trainingDaysPerWeek = selectedTrainingDays.count
        }

        syncWorkoutSchedule()
    }

    func syncWorkoutSchedule() {
        let effectiveCount = selectedTrainingDays.isEmpty ? trainingDaysPerWeek : selectedTrainingDays.count
        let normalized = min(max(effectiveCount, 1), Weekday.allCases.count)
        workoutFrequency = String(normalized)
        preferredWorkoutDays = selectedTrainingDays
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { $0.rawValue }
    }

    func setNotificationTime(_ date: Date) {
        notificationPreviewTime = date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        notificationPreviewTimeISO8601 = formatter.string(from: date)
    }

    enum Weekday: String, CaseIterable, Identifiable {
        case sunday = "Sunday"
        case monday = "Monday"
        case tuesday = "Tuesday"
        case wednesday = "Wednesday"
        case thursday = "Thursday"
        case friday = "Friday"
        case saturday = "Saturday"

        var id: String { rawValue }

        var shortLabel: String {
            String(rawValue.prefix(3))
        }

        var sortOrder: Int {
            Self.allCases.firstIndex(of: self) ?? 0
        }
    }
    
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
            // Backwards compatibility with legacy flag used in some views
            UserDefaults.standard.set(unitsSystem == .imperial, forKey: "isImperial")
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
    
    // Computed property to get current progress
    var progress: CGFloat {
        return OnboardingProgress.progressFor(screen: currentFlowStep.asScreen)
    }
    
    private let profileRepository = ProfileRepository.shared
    private let subscriptionRepository = SubscriptionRepository.shared
    private var repositoryEmail: String?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        loadOnboardingState()
        
        // Load units system from UserDefaults, default to imperial
        if let savedUnitsSystem = UserDefaults.standard.string(forKey: "unitsSystem"),
           let units = UnitsSystem(rawValue: savedUnitsSystem) {
            self.unitsSystem = units
            UserDefaults.standard.set(units == .imperial, forKey: "isImperial")
        } else {
            self.unitsSystem = .imperial
            // Save the default value
            UserDefaults.standard.set(UnitsSystem.imperial.rawValue, forKey: "unitsSystem")
            UserDefaults.standard.set(true, forKey: "isImperial")
        }
        
        // Load streak visibility from UserDefaults, default to true (visible)
        if UserDefaults.standard.object(forKey: "isStreakVisible") != nil {
            self.isStreakVisible = UserDefaults.standard.bool(forKey: "isStreakVisible")
        } else {
            self.isStreakVisible = true
            // Save the default value
            UserDefaults.standard.set(true, forKey: "isStreakVisible")
        }

        setNotificationTime(notificationPreviewTime)
    }

    func bindRepositories(for email: String) {
        guard repositoryEmail != email else { return }
        repositoryEmail = email

        cancellables.removeAll()

        profileRepository.configure(email: email)

        profileRepository.$profile
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let self else { return }
                self.profileData = profile
                self.updateLocalUserData(from: profile)
                self.profileError = nil
            }
            .store(in: &cancellables)

        subscriptionRepository.$subscription
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subscription in
                self?.updateSubscriptionInfo(
                    status: subscription.status,
                    plan: subscription.plan,
                    expiresAt: subscription.expiresAt,
                    renews: subscription.renews,
                    seats: subscription.seats,
                    canCreateNewTeam: subscription.canCreateNewTeam
                )
            }
            .store(in: &cancellables)

        // If repository already has cached profile, apply immediately
        if let profile = profileRepository.profile {
            profileData = profile
            updateLocalUserData(from: profile)
        }

        if let subscription = subscriptionRepository.subscription {
            updateSubscriptionInfo(
                status: subscription.status,
                plan: subscription.plan,
                expiresAt: subscription.expiresAt,
                renews: subscription.renews,
                seats: subscription.seats,
                canCreateNewTeam: subscription.canCreateNewTeam
            )
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
    func fetchProfileData(force: Bool = true) async {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail"), !userEmail.isEmpty else {
            profileError = "No user email available"
            return
        }

        bindRepositories(for: userEmail)

        isLoadingProfile = true
        profileError = nil

        await profileRepository.refresh(force: force)

        isLoadingProfile = false

        if let data = profileRepository.profile {
            profileData = data
            updateLocalUserData(from: data)
        } else {
            profileError = "Unable to load profile data"
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
    func refreshProfileDataIfNeeded() async {
        if profileData == nil || isProfileDataStale() {
            await fetchProfileData(force: false)
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
