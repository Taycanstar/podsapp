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
    struct OnboardingNutritionPlan {
        let bmr: Double
        let tdee: Double
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }
    // Original enum for core navigation states
    enum OnboardingStep {
        case landing
        case enterName
        case greeting
        case fitnessGoal
        case strengthExperience
        case programOverview
        case desiredWeight
        case gymLocation
        case reviewEquipment
        case workoutSchedule
        case dietPreferences
        case enableNotifications
        case demo              // Demo appears before allowHealth
        case allowHealth
        case aboutYou
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
        case buildEndurance = "Build endurance"

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
            case .buildEndurance:
                return "figure.run"
            }
        }

        /// Normalized backend goal value used during onboarding completion
        var mappedOnboardingValue: String {
            switch self {
            case .liftMoreWeight, .gainMuscle:
                return "strength"
            case .leanAndToned:
                return "hypertrophy"
            case .loseWeight:
                return "hypertrophy"
            case .buildEndurance:
                return "endurance"
            }
        }

        /// Map fitness goal to ICP (Ideal Customer Profile) for body composition phase
        var icp: String {
            switch self {
            case .loseWeight:
                return "cut"
            case .leanAndToned:
                return "cut"
            case .gainMuscle:
                return "lean_bulk"
            case .liftMoreWeight:
                return "recomp"
            case .buildEndurance:
                return "recomp"
            }
        }

        /// Best-effort reverse lookup from a stored onboarding value
        static func option(forOnboardingValue value: String) -> FitnessGoalOption? {
            switch value {
            case "strength":
                return .liftMoreWeight
            case "hypertrophy":
                return .leanAndToned
            case "endurance":
                return .buildEndurance
            case "circuit_training", "general":
                return .leanAndToned
            default:
                return nil
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

    enum DietPreferenceOption: String, CaseIterable, Identifiable {
        case balanced
        case keto
        case vegetarian
        case vegan
        case paleo
        case mediterranean

        var id: String { rawValue }

        var title: String {
            switch self {
            case .balanced: return "Balanced"
            case .keto: return "Keto"
            case .vegetarian: return "Vegetarian"
            case .vegan: return "Vegan"
            case .paleo: return "Paleo"
            case .mediterranean: return "Mediterranean"
            }
        }

        var systemImageName: String {
            switch self {
            case .balanced: return "fork.knife"
            case .keto: return "drop.fill"
            case .vegetarian: return "carrot.fill"
            case .vegan: return "leaf.fill"
            case .paleo: return "fish.fill"
            case .mediterranean: return "tree.fill"
            }
        }

        var description: String {
            switch self {
            case .balanced:
                return "Excludes nothing."
            case .keto:
                return "Excludes high-carb grains, refined starches, and sugar."
            case .vegetarian:
                return "Excludes red meat, poultry, fish, and shellfish."
            case .vegan:
                return "Excludes meat, fish, dairy, eggs, mayo, and honey."
            case .paleo:
                return "Excludes dairy, grains, legumes, soy, refined starches, and sugar."
            case .mediterranean:
                return "Excludes red meat, processed meats, fruit juices, refined starches, and sugar."
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
    
    @Published var currentStep: OnboardingStep = .landing {
        didSet {
            trackOnboardingStep(currentStep)
        }
    }
    @Published var currentFlowStep: OnboardingFlowStep = .gender
    @Published var onboardingCompleted: Bool = false
    private let nutritionSeedDefaultsKey = "hasSeededNutritionGoals"
    @Published private(set) var hasSeededNutritionProfile: Bool = UserDefaults.standard.bool(forKey: "hasSeededNutritionGoals")
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
    @Published var selectedFitnessGoal: FitnessGoalOption? {
        didSet {
            applyFitnessGoalMapping(for: selectedFitnessGoal)
        }
    }
    @Published var selectedStrengthExperience: StrengthExperienceOption?
    @Published var selectedDietPreference: DietPreferenceOption? {
        didSet {
            let value = selectedDietPreference?.rawValue ?? ""
            if dietPreference != value {
                dietPreference = value
            }
            UserDefaults.standard.set(value, forKey: "dietPreference")
        }
    }
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

    let newOnboardingTotalSteps: Int = 14
    private let notificationTimeDefaultsKey = "notificationPreviewTimeISO8601"
    private let nutritionPreviewDefaultsKey = "nutritionGoalsPreviewData"
    private lazy var dobFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    var newOnboardingProgress: Double {
        guard newOnboardingTotalSteps > 0 else { return 0 }
        return min(max(Double(newOnboardingStepIndex) / Double(newOnboardingTotalSteps), 0), 1)
    }

    var strengthExperienceLevel: ExperienceLevel? {
        selectedStrengthExperience?.experienceLevel
    }

    var programTitleDisplay: String {
        selectedFitnessGoal?.rawValue ?? "Your Program"
    }

    var trainingStyleDisplay: String {
        switch fitnessGoal {
        case "strength":
            return "Strength Training"
        case "hypertrophy":
            return "Hypertrophy"
        case "circuit_training":
            return "Circuit Training"
        default:
            return selectedFitnessGoal?.rawValue ?? "General Fitness"
        }
    }

    var trainingSplitDisplay: String {
        switch trainingSplit {
        case "full_body": return "Full Body"
        case "upper_lower": return "Upper/Lower"
        case "push_pull_lower": return "Push/Pull/Lower"
        case "fresh": return "Fresh Muscle Groups"
        default: return "Push/Pull/Lower"
        }
    }

    var equipmentProfileDisplay: String {
        selectedGymLocation?.title ?? "Not set"
    }

    var exerciseDifficultyDisplay: String {
        strengthExperienceLevel?.displayName ?? "Not set"
    }

    var nutritionPreviewGoals: NutritionGoals? {
        guard let plan = nutritionPreviewPlan else { return nil }
        return NutritionGoals(
            bmr: plan.bmr,
            tdee: plan.tdee,
            calories: Double(plan.calories),
            protein: Double(plan.protein),
            carbs: Double(plan.carbs),
            fat: Double(plan.fat)
        )
    }

    private func updateNutritionPreviewCache() {
        let plan = calculateNutritionPreview()
        nutritionPreviewPlan = plan
        persistNutritionPreview(plan: plan)
    }

    private func persistNutritionPreview(plan: OnboardingNutritionPlan?) {
        let defaults = UserDefaults.standard

        guard let plan else {
            defaults.removeObject(forKey: nutritionPreviewDefaultsKey)
            return
        }

        let goals = NutritionGoals(
            bmr: plan.bmr,
            tdee: plan.tdee,
            calories: Double(plan.calories),
            protein: Double(plan.protein),
            carbs: Double(plan.carbs),
            fat: Double(plan.fat)
        )

        do {
            let data = try JSONEncoder().encode(goals)
            defaults.set(data, forKey: nutritionPreviewDefaultsKey)
        } catch {
            print("⚠️ Failed to persist nutrition preview: \(error)")
        }
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
        workoutFrequency = activityLevel(forDays: normalized)
        workoutDaysPerWeek = normalized
        preferredWorkoutDays = selectedTrainingDays
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { $0.rawValue }

        let selectedIndices = selectedTrainingDays
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { $0.sortOrder }

        if let data = try? JSONEncoder().encode(selectedIndices) {
            UserDefaults.standard.set(data, forKey: "preferredWorkoutDays")
        }

        UserDefaults.standard.set(normalized, forKey: "workout_days_per_week")

        let allIndices = Set(Weekday.allCases.map { $0.sortOrder })
        let restIndices = Array(allIndices.subtracting(selectedIndices)).sorted()
        let restDayNames = restIndices.map { Weekday.allCases[$0].rawValue }
        restDays = restDayNames
        UserDefaults.standard.set(restDayNames, forKey: "rest_days")

        updateTrainingSplit(for: normalized)
    }

    func setNotificationTime(_ date: Date) {
        var components = Calendar.current.dateComponents([.hour, .minute], from: date)
        components.second = 0
        let normalized = Calendar.current.date(from: components) ?? date
        notificationPreviewTime = normalized
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        notificationPreviewTimeISO8601 = formatter.string(from: normalized)
        UserDefaults.standard.set(notificationPreviewTimeISO8601, forKey: notificationTimeDefaultsKey)
    }

    private func updateTrainingSplit(for workoutDays: Int) {
        let split: String
        switch workoutDays {
        case ...2:
            split = "full_body"
        case 3:
            split = "push_pull_lower"
        case 4...5:
            split = "upper_lower"
        case 6...:
            split = "push_pull_lower"
        default:
            split = "full_body"
        }

        if trainingSplit != split {
            trainingSplit = split
        }
    }

    private func applyFitnessGoalMapping(for option: FitnessGoalOption?) {
        if let option {
            UserDefaults.standard.set(option.rawValue, forKey: "selectedFitnessGoalOption")
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedFitnessGoalOption")
        }

        let mappedValue = option?.mappedOnboardingValue ?? ""
        fitnessGoal = mappedValue
    }

    private func calculateNutritionPreview() -> OnboardingNutritionPlan? {
        let weight = weightKg
        let height = heightCm
        guard weight > 0, height > 0 else { return nil }

        guard let age = calculatePreviewAge() else { return nil }

        let genderValue = gender.isEmpty ? "other" : gender.lowercased()
        let bmr = calculatePreviewBMR(weightKg: weight, heightCm: height, age: age, gender: genderValue)

        let activityLevel = resolveActivityLevel()
        let multiplier: Double
        switch activityLevel {
        case "low": multiplier = 1.2
        case "high": multiplier = 1.725
        default: multiplier = 1.55
        }
        let tdee = Double(round(100 * (bmr * multiplier)) / 100)

        let previewDietGoal = resolveDietGoal()
        let previewDietPreference = normalizedDietPreference(dietPreference).isEmpty ? "balanced" : normalizedDietPreference(dietPreference)
        let calorieTarget = calculatePreviewCalories(tdee: tdee, dietGoal: previewDietGoal, gender: genderValue)
        let macros = calculatePreviewMacros(
            calories: calorieTarget,
            weightKg: weight,
            dietGoal: previewDietGoal,
            dietPreference: previewDietPreference,
            fitnessGoal: fitnessGoal,
            activityLevel: activityLevel,
            age: age
        )

        guard let macros else { return nil }

        let macroCalories = (macros.protein * 4) + (macros.carbs * 4) + (macros.fat * 9)

        return OnboardingNutritionPlan(
            bmr: bmr,
            tdee: tdee,
            calories: macroCalories,
            protein: macros.protein,
            carbs: macros.carbs,
            fat: macros.fat
        )
    }

    private func calculatePreviewAge() -> Int? {
        guard let dob = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: dob, to: Date())
        guard let years = components.year, years > 0 else { return nil }
        return years
    }

    private func calculatePreviewBMR(weightKg: Double, heightCm: Double, age: Int, gender: String) -> Double {
        let rawValue: Double

        switch gender {
        case "male":
            rawValue = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
        case "female":
            rawValue = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) - 161
        default:
            let male = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
            let female = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) - 161
            rawValue = (male + female) / 2
        }

        return (rawValue * 100).rounded() / 100
    }

    private func resolveActivityLevel() -> String {
        let normalized = normalizedFrequencyValue(workoutFrequency)
        if normalized.isEmpty == false {
            return normalized
        }

        if workoutDaysPerWeek > 0 {
            return activityLevel(forDays: workoutDaysPerWeek)
        }

        return "medium"
    }

    private func activityLevel(forDays days: Int) -> String {
        switch days {
        case ...2: return "low"
        case 3...5: return "medium"
        default: return "high"
        }
    }

    private func normalizedFrequencyValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }

        let lowercased = trimmed.lowercased()
        if ["low", "medium", "high"].contains(lowercased) {
            return lowercased
        }

        if let days = Int(lowercased) {
            return activityLevel(forDays: days)
        }

        return "medium"
    }

    private func normalizedDietPreference(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }

        let lower = trimmed.lowercased()
        let canonicalMap: [String: String] = [
            "balanced": "balanced",
            "general": "balanced",
            "standard": "balanced",
            "keto": "keto",
            "vegetarian": "vegetarian",
            "vegan": "vegan",
            "paleo": "paleo",
            "mediterranean": "mediterranean",
            "pescatarian": "pescatarian",
            "pescetarian": "pescatarian",
            "seafood": "pescatarian",
            "fish": "pescatarian",
            "lowcarb": "lowCarb",
            "low-carb": "lowCarb",
            "low_carbs": "lowCarb",
            "low carbs": "lowCarb",
            "glutenfree": "glutenFree",
            "gluten-free": "glutenFree",
            "gluten_free": "glutenFree"
        ]

        if let mapped = canonicalMap[lower] {
            return mapped
        }

        // Preserve any newer or custom preferences without forcing them into legacy values.
        return trimmed
    }

    private func resolveDietGoal() -> String {
        let normalized = dietGoal.lowercased()
        if ["lose", "gain", "maintain"].contains(normalized) {
            return normalized
        }

        switch normalized {
        case "loseweight": return "lose"
        case "gainweight": return "gain"
        default:
            if desiredWeightKg > 0, weightKg > 0 {
                if abs(desiredWeightKg - weightKg) < 0.45 { return "maintain" }
                return desiredWeightKg < weightKg ? "lose" : "gain"
            }
            return "maintain"
        }
    }

    private func calculatePreviewCalories(tdee: Double, dietGoal: String, gender: String) -> Double {
        switch dietGoal {
        case "lose":
            let minimum = gender == "male" ? 1500.0 : 1200.0
            return max(minimum, tdee - 500.0)
        case "gain":
            return tdee + 500.0
        default:
            return tdee
        }
    }

    private func calculatePreviewMacros(calories: Double,
                                        weightKg: Double,
                                        dietGoal: String,
                                        dietPreference: String,
                                        fitnessGoal: String,
                                        activityLevel: String,
                                        age: Int) -> (protein: Int, carbs: Int, fat: Int)? {
        guard calories > 0, weightKg > 0 else { return nil }

        var baseProteinPerKg: Double
        switch dietGoal {
        case "lose": baseProteinPerKg = 1.8
        case "gain": baseProteinPerKg = 2.0
        default: baseProteinPerKg = 1.4
        }
        if age >= 40 { baseProteinPerKg += 0.1 }

        let proteinGrams = clamp(weightKg * baseProteinPerKg, min: 0.8 * weightKg, max: 2.2 * weightKg)

        let fatFloorGrams = max(0.8 * weightKg, 0.25 * calories / 9.0)
        var fatGrams = fatFloorGrams

        let remainingCalories = calories - (proteinGrams * 4.0 + fatGrams * 9.0)
        var carbGrams: Double

        if dietPreference.lowercased() == "keto" {
            carbGrams = 50.0
            fatGrams += (remainingCalories - carbGrams * 4.0) / 9.0
            fatGrams = min(fatGrams, 0.75 * calories / 9.0)
        } else {
            let carbCap = min(0.55 * calories / 4.0, 6.0 * weightKg)
            let carbFloor: Double
            if ["endurance", "circuit_training"].contains(fitnessGoal) && activityLevel == "high" {
                carbFloor = max(5.0 * weightKg, 130.0)
            } else {
                carbFloor = 130.0
            }
            carbGrams = clamp(remainingCalories / 4.0, min: carbFloor, max: carbCap)
            fatGrams += max(0.0, (remainingCalories - carbGrams * 4.0) / 9.0)
        }

        fatGrams = clamp(fatGrams, min: 0.0, max: 0.35 * calories / 9.0)

        if carbGrams < 0 { return nil }

        var protein = Int(round(proteinGrams))
        var carbs = Int(round(carbGrams))
        var fat = Int(round(fatGrams))

        let totalCalories = Double(protein * 4 + carbs * 4 + fat * 9)
        let calorieDiff = calories - totalCalories

        if abs(calorieDiff) >= 1 {
            var macros: [(value: Int, caloriesPerGram: Int, key: String)] = [
                (protein, 4, "protein"),
                (carbs, 4, "carbs"),
                (fat, 9, "fat")
            ]
            macros.sort { $0.value * $0.caloriesPerGram > $1.value * $1.caloriesPerGram }

            let primary = macros[0]
            let adjustment = Int(round(calorieDiff / Double(primary.caloriesPerGram)))

            switch primary.key {
            case "protein": protein += adjustment
            case "carbs": carbs += adjustment
            default: fat += adjustment
            }
        }

        protein = max(protein, 0)
        carbs = max(carbs, 0)
        fat = max(fat, 0)

        return (protein, carbs, fat)
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.max(min, Swift.min(max, value))
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
    @Published var pendingInitialFoodTab: String? = nil
    
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

    @Published var showProOnboarding: Bool = false

    @Published private(set) var nutritionPreviewPlan: OnboardingNutritionPlan?
    
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
    @Published var gender: String = "" {
        didSet {
            guard gender != oldValue else { return }
            if gender.isEmpty {
                UserDefaults.standard.removeObject(forKey: "gender")
            } else {
                UserDefaults.standard.set(gender, forKey: "gender")
            }
            updateNutritionPreviewCache()
        }
    }
    @Published var dateOfBirth: Date? {
        didSet {
            guard dateOfBirth != oldValue else { return }
            if let dob = dateOfBirth {
                UserDefaults.standard.set(dobFormatter.string(from: dob), forKey: "dateOfBirth")
            } else {
                UserDefaults.standard.removeObject(forKey: "dateOfBirth")
            }
            updateNutritionPreviewCache()
        }
    }
    @Published var heightCm: Double = 0.0 {
        didSet {
            guard heightCm != oldValue else { return }
            UserDefaults.standard.set(heightCm, forKey: "heightCentimeters")
            updateNutritionPreviewCache()
        }
    }
    @Published var weightKg: Double = 0.0 {
        didSet {
            guard weightKg != oldValue else { return }
            UserDefaults.standard.set(weightKg, forKey: "weightKilograms")
            updateNutritionPreviewCache()
        }
    }
    @Published var desiredWeightKg: Double = 0.0 {
        didSet {
            guard desiredWeightKg != oldValue else { return }
            UserDefaults.standard.set(desiredWeightKg, forKey: "desiredWeightKilograms")
            updateNutritionPreviewCache()
        }
    }
    @Published var dietGoal: String = "" {
        didSet {
            guard dietGoal != oldValue else { return }
            if dietGoal.isEmpty {
                UserDefaults.standard.removeObject(forKey: "dietGoal")
            } else {
                UserDefaults.standard.set(dietGoal, forKey: "dietGoal")
            }
            updateNutritionPreviewCache()
        }
    }
    @Published var fitnessGoal: String = "" {
        didSet {
            guard fitnessGoal != oldValue else { return }
            if fitnessGoal.isEmpty {
                UserDefaults.standard.removeObject(forKey: "fitnessGoal")
            } else {
                UserDefaults.standard.set(fitnessGoal, forKey: "fitnessGoal")
            }
            updateNutritionPreviewCache()
        }
    }
    @Published var goalTimeframeWeeks: Int = 0
    @Published var weeklyWeightChange: Double = 0.0
    @Published var workoutFrequency: String = "" {
        didSet {
            guard workoutFrequency != oldValue else { return }
            let normalized = normalizedFrequencyValue(workoutFrequency)

            if normalized != workoutFrequency {
                workoutFrequency = normalized
                return
            }

            if normalized.isEmpty {
                UserDefaults.standard.removeObject(forKey: "workoutFrequency")
            } else {
                UserDefaults.standard.set(normalized, forKey: "workoutFrequency")
            }
            updateNutritionPreviewCache()
        }
    }
    @Published var dietPreference: String = "" {
        didSet {
            guard dietPreference != oldValue else { return }
            if dietPreference.isEmpty {
                if selectedDietPreference != nil {
                    selectedDietPreference = nil
                }
                UserDefaults.standard.removeObject(forKey: "dietPreference")
            } else if let option = DietPreferenceOption(rawValue: dietPreference), option != selectedDietPreference {
                selectedDietPreference = option
                UserDefaults.standard.set(dietPreference, forKey: "dietPreference")
            } else if !dietPreference.isEmpty {
                UserDefaults.standard.set(dietPreference, forKey: "dietPreference")
            }

            updateNutritionPreviewCache()
        }
    }
    @Published var primaryWellnessGoal: String = ""
    @Published var obstacles: [String] = []
    @Published var addCaloriesBurned: Bool = false
    @Published var rolloverCalories: Bool = false
    @Published var availableEquipment: [String] = []
    @Published var workoutLocation: String = ""
    @Published var preferredWorkoutDuration: Int = 0
    @Published var workoutDaysPerWeek: Int = 0 {
        didSet {
            guard workoutDaysPerWeek != oldValue else { return }
            updateNutritionPreviewCache()
        }
    }
    @Published var restDays: [String] = []
    @Published var trainingSplit: String = "push_pull_lower" {
        didSet {
            if trainingSplit.isEmpty {
                UserDefaults.standard.removeObject(forKey: "trainingSplit")
            } else {
                UserDefaults.standard.set(trainingSplit, forKey: "trainingSplit")
            }
        }
    }
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
    private let initialWeightLogKeyPrefix = "initialWeightLogCreated_"

    init() {
        loadOnboardingState()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let storedDiet = UserDefaults.standard.string(forKey: "dietPreference"), !storedDiet.isEmpty {
            dietPreference = storedDiet
            if let option = DietPreferenceOption(rawValue: storedDiet) {
                selectedDietPreference = option
            }
        }

        if let storedTime = UserDefaults.standard.string(forKey: notificationTimeDefaultsKey),
           let storedDate = formatter.date(from: storedTime) {
            notificationPreviewTime = storedDate
        }

        if let data = UserDefaults.standard.data(forKey: "preferredWorkoutDays"),
           let indices = try? JSONDecoder().decode([Int].self, from: data) {
            let validDays = indices.compactMap { index -> Weekday? in
                guard index >= 0, index < Weekday.allCases.count else { return nil }
                return Weekday.allCases[index]
            }
            if !validDays.isEmpty {
                selectedTrainingDays = Set(validDays)
                trainingDaysPerWeek = validDays.count
                preferredWorkoutDays = validDays.map { $0.rawValue }
            }
        }

        if preferredWorkoutDays.isEmpty {
            let storedDays = UserDefaults.standard.integer(forKey: "workout_days_per_week")
            if storedDays > 0 {
                trainingDaysPerWeek = storedDays
                selectedTrainingDays = Set(Weekday.allCases.prefix(storedDays))
                preferredWorkoutDays = selectedTrainingDays
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .map { $0.rawValue }
            }
        }

        if let storedFitnessGoalOption = UserDefaults.standard.string(forKey: "selectedFitnessGoalOption"),
           let option = FitnessGoalOption(rawValue: storedFitnessGoalOption) {
            selectedFitnessGoal = option
        } else if let storedFitnessGoal = UserDefaults.standard.string(forKey: "fitnessGoal"), !storedFitnessGoal.isEmpty {
            fitnessGoal = storedFitnessGoal
            if selectedFitnessGoal == nil,
               let inferredOption = FitnessGoalOption.option(forOnboardingValue: storedFitnessGoal) {
                selectedFitnessGoal = inferredOption
            }
        }

        if let storedSplit = UserDefaults.standard.string(forKey: "trainingSplit"), !storedSplit.isEmpty {
            trainingSplit = storedSplit
        } else {
            updateTrainingSplit(for: max(trainingDaysPerWeek, 1))
        }

        if let storedName = UserDefaults.standard.string(forKey: "userName"), !storedName.isEmpty {
            name = storedName
        }

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
        syncWorkoutSchedule()
        updateNutritionPreviewCache()
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
        currentStep = .enterName
        currentFlowStep = .gender
        onboardingCompleted = false
        saveOnboardingState()

        // Mark that onboarding is now in progress
        UserDefaults.standard.set(true, forKey: "onboardingInProgress")
    }

    // MARK: - Analytics Tracking

    /// Tracks onboarding step views for drop-off analysis
    private func trackOnboardingStep(_ step: OnboardingStep) {
        // Map OnboardingStep to step name and index for tracking
        let stepInfo: (name: String, index: Int)?
        switch step {
        case .landing:
            stepInfo = nil // Don't track landing as a step
        case .enterName:
            stepInfo = ("enter_name", 1)
        case .greeting:
            stepInfo = ("greeting", 2)
        case .fitnessGoal:
            stepInfo = ("fitness_goal", 3)
        case .strengthExperience:
            stepInfo = ("strength_experience", 4)
        case .desiredWeight:
            stepInfo = ("desired_weight", 5)
        case .gymLocation:
            stepInfo = ("gym_location", 6)
        case .reviewEquipment:
            stepInfo = ("review_equipment", 7)
        case .workoutSchedule:
            stepInfo = ("workout_schedule", 8)
        case .dietPreferences:
            stepInfo = ("diet_preferences", 9)
        case .programOverview:
            stepInfo = ("program_overview", 10)
        case .demo:
            stepInfo = ("demo", 11)
        case .enableNotifications:
            stepInfo = ("enable_notifications", 12)
        case .allowHealth:
            stepInfo = ("allow_health", 13)
        case .signup:
            stepInfo = ("signup", 14)
        case .aboutYou, .emailVerification, .info, .gender, .welcome, .login:
            stepInfo = nil // Secondary screens, don't track as main funnel steps
        }

        if let stepInfo = stepInfo {
            AnalyticsManager.shared.trackOnboardingStepViewed(
                onboardingVersion: "2.0",
                stepName: stepInfo.name,
                stepIndex: stepInfo.index
            )
        }
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

    func trySeedRemoteNutritionProfile(force: Bool = false) {
        if !force, hasSeededNutritionProfile {
            return
        }

        guard let resolvedEmail = resolvedUserEmail() else {
            return
        }

        let payload = buildOnboardingSeedPayload()

        NetworkManagerTwo.shared.ensureNutritionGoals(
            userEmail: resolvedEmail,
            fallbackOnboardingPayload: payload
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                NutritionGoalsStore.shared.cache(goals: response.goals)
                self.markNutritionProfileSeeded()
            case .failure(let error):
                print("⚠️ OnboardingViewModel: ensureNutritionGoals failed - \(error.localizedDescription)")
            }
        }
    }

    private func markNutritionProfileSeeded() {
        hasSeededNutritionProfile = true
        UserDefaults.standard.set(true, forKey: nutritionSeedDefaultsKey)
    }

    private func resolvedUserEmail() -> String? {
        if !email.isEmpty {
            return email
        }
        if let stored = UserDefaults.standard.string(forKey: "userEmail"), !stored.isEmpty {
            return stored
        }
        return nil
    }

    private func buildOnboardingSeedPayload() -> [String: Any]? {
        let defaults = UserDefaults.standard

        let resolvedGender = !gender.isEmpty ? gender : (defaults.string(forKey: "gender") ?? "")
        let resolvedDOB: String? = {
            if let dob = dateOfBirth {
                return dobFormatter.string(from: dob)
            }
            if let stored = defaults.string(forKey: "dateOfBirth"), !stored.isEmpty {
                return stored
            }
            return nil
        }()

        var resolvedHeight = heightCm
        if resolvedHeight <= 0 {
            let stored = defaults.double(forKey: "heightCentimeters")
            if stored > 0 { resolvedHeight = stored }
        }

        var resolvedWeight = weightKg
        if resolvedWeight <= 0 {
            let stored = defaults.double(forKey: "weightKilograms")
            if stored > 0 { resolvedWeight = stored }
        }

        guard !resolvedGender.isEmpty,
              let dobString = resolvedDOB,
              !dobString.isEmpty,
              resolvedHeight > 0,
              resolvedWeight > 0 else {
            return nil
        }

        var payload: [String: Any] = [
            "gender": resolvedGender,
            "date_of_birth": dobString,
            "height_cm": resolvedHeight,
            "weight_kg": resolvedWeight,
        ]

        let resolvedDesiredWeight = desiredWeightKg > 0 ? desiredWeightKg : defaults.double(forKey: "desiredWeightKilograms")
        if resolvedDesiredWeight > 0 {
            payload["desired_weight_kg"] = resolvedDesiredWeight
        }

        let resolvedDietGoal = !dietGoal.isEmpty ? dietGoal : (defaults.string(forKey: "dietGoal") ?? "")
        payload["diet_goal"] = resolvedDietGoal.isEmpty ? "maintain" : resolvedDietGoal

        let resolvedFitnessGoal = !fitnessGoal.isEmpty ? fitnessGoal : (defaults.string(forKey: "fitnessGoal") ?? "")
        payload["fitness_goal"] = resolvedFitnessGoal.isEmpty ? "general" : resolvedFitnessGoal

        let resolvedFrequency = !workoutFrequency.isEmpty ? workoutFrequency : (defaults.string(forKey: "workoutFrequency") ?? "")
        payload["workout_frequency"] = resolvedFrequency.isEmpty ? "medium" : resolvedFrequency

        let resolvedDietPreference = !dietPreference.isEmpty ? dietPreference : (defaults.string(forKey: "dietPreference") ?? "")
        payload["diet_preference"] = resolvedDietPreference.isEmpty ? "balanced" : resolvedDietPreference

        if goalTimeframeWeeks > 0 {
            payload["goal_timeframe_weeks"] = goalTimeframeWeeks
        } else if defaults.integer(forKey: "goalTimeframeWeeks") > 0 {
            payload["goal_timeframe_weeks"] = defaults.integer(forKey: "goalTimeframeWeeks")
        }

        if weeklyWeightChange > 0 {
            payload["weekly_weight_change"] = weeklyWeightChange
        } else if defaults.double(forKey: "weeklyWeightChange") > 0 {
            payload["weekly_weight_change"] = defaults.double(forKey: "weeklyWeightChange")
        }

        if workoutDaysPerWeek > 0 {
            payload["workout_days_per_week"] = workoutDaysPerWeek
        } else if defaults.integer(forKey: "workout_days_per_week") > 0 {
            payload["workout_days_per_week"] = defaults.integer(forKey: "workout_days_per_week")
        }

        if preferredWorkoutDuration > 0 {
            payload["preferred_workout_duration"] = preferredWorkoutDuration
        }

        if !restDays.isEmpty {
            payload["rest_days"] = restDays
        } else if let storedRest = defaults.array(forKey: "rest_days") as? [String], !storedRest.isEmpty {
            payload["rest_days"] = storedRest
        }

        if !availableEquipment.isEmpty {
            payload["available_equipment"] = availableEquipment
        }

        payload["add_calories_burned"] = addCaloriesBurned || defaults.bool(forKey: "addCaloriesBurned")
        payload["rollover_calories"] = rolloverCalories || defaults.bool(forKey: "rolloverCalories")

        if let sport = UserDefaults.standard.string(forKey: "sportType"), !sport.isEmpty {
            payload["sport_type"] = sport
        }

        return payload
    }

    func signupOnboardingPayload() -> [String: Any]? {
        guard validateOnboardingData(), let dob = dateOfBirth else {
            print("❌ OnboardingViewModel: Cannot build signup payload - missing DOB or validation failed")
            return nil
        }

        let resolvedDietGoal = dietGoal
        let sanitizedFrequency = normalizedFrequencyValue(workoutFrequency)
        let resolvedWorkoutFrequency = sanitizedFrequency.isEmpty ? "medium" : sanitizedFrequency
        let sanitizedDietPreference = normalizedDietPreference(dietPreference)
        let resolvedDietPreference = sanitizedDietPreference.isEmpty ? "balanced" : sanitizedDietPreference
        let resolvedWorkoutLocation = workoutLocation.isEmpty ? "gym" : workoutLocation

        // Calculate ICP based on selected fitness goal
        let icp = selectedFitnessGoal?.icp ?? ""

        var payload: [String: Any] = [
            "gender": gender,
            "date_of_birth": dobFormatter.string(from: dob),
            "height_cm": heightCm,
            "weight_kg": weightKg,
            "desired_weight_kg": desiredWeightKg,
            "fitness_goal": fitnessGoal,
            "icp": icp,  // Add ICP mapped from fitness goal
            "workout_frequency": resolvedWorkoutFrequency,
            "diet_preference": resolvedDietPreference,
            "add_calories_burned": addCaloriesBurned,
            "rollover_calories": rolloverCalories,
            "available_equipment": availableEquipment,
            "workout_location": resolvedWorkoutLocation,
            "rest_days": restDays,
            "units_system": unitsSystem.rawValue
        ]

        if !resolvedDietGoal.isEmpty {
            payload["diet_goal"] = resolvedDietGoal
        }

        if !primaryWellnessGoal.isEmpty {
            payload["primary_wellness_goal"] = primaryWellnessGoal
        }

        if goalTimeframeWeeks > 0 {
            payload["goal_timeframe_weeks"] = goalTimeframeWeeks
        }

        if weeklyWeightChange > 0 {
            payload["weekly_weight_change"] = weeklyWeightChange
        }

        if workoutDaysPerWeek > 0 {
            payload["workout_days_per_week"] = workoutDaysPerWeek
        }

        if preferredWorkoutDuration > 0 {
            payload["preferred_workout_duration"] = preferredWorkoutDuration
        }

        if !obstacles.isEmpty {
            payload["obstacles"] = obstacles
        }

        if let level = strengthExperienceLevel?.rawValue {
            payload["fitness_level"] = level
        }

        if !trainingSplit.isEmpty {
            payload["training_split"] = trainingSplit
        }

        if let sportType = UserDefaults.standard.string(forKey: "sportType"), !sportType.isEmpty {
            payload["sport_type"] = sportType
        }

        return payload
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
        let sanitizedFrequency = normalizedFrequencyValue(workoutFrequency)
        let sanitizedDietPreference = normalizedDietPreference(dietPreference)

        // Calculate ICP based on selected fitness goal
        let icp = selectedFitnessGoal?.icp ?? ""

        let onboardingData: [String: Any] = [
            "user_email": email,
            "name": name,
            "gender": gender,
            "date_of_birth": dateOfBirth?.ISO8601Format() ?? "",
            "height_cm": heightCm,
            "weight_kg": weightKg,
            "desired_weight_kg": desiredWeightKg,
            "diet_goal": dietGoal,
            "fitness_goal": fitnessGoal,
            "icp": icp,  // Add ICP mapped from fitness goal
            "goal_timeframe_weeks": goalTimeframeWeeks,
            "weekly_weight_change": weeklyWeightChange,
            "workout_frequency": sanitizedFrequency.isEmpty ? "medium" : sanitizedFrequency,
            "diet_preference": sanitizedDietPreference.isEmpty ? "balanced" : sanitizedDietPreference,
            "primary_wellness_goal": primaryWellnessGoal,
            "obstacles": obstacles.joined(separator: ","),
            "add_calories_burned": addCaloriesBurned,
            "rollover_calories": rolloverCalories,
            "available_equipment": availableEquipment,
            "workout_location": workoutLocation,
            "preferred_workout_duration": preferredWorkoutDuration,
            "workout_days_per_week": workoutDaysPerWeek,
            "rest_days": restDays,
            "training_split": trainingSplit,
            "units_system": unitsSystem.rawValue
        ]
        
        print("📋 OnboardingViewModel: Prepared onboarding data with \(onboardingData.count) fields")
        
        Task {
            // First, save locally for offline access
            print("💾 OnboardingViewModel: Saving locally via DataLayer")
            await DataLayer.shared.saveOnboardingData(onboardingData)

            // Then, send to backend
            print("📤 OnboardingViewModel: Sending to backend via NetworkManager")
            NetworkManager().sendOnboardingData(onboardingData) { success, errorMessage in
                Task { @MainActor in
                    self.isLoading = false

                    if success {
                     
                        self.onboardingCompleted = true
                        self.isShowingOnboarding = false

                        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                        UserDefaults.standard.set(self.email, forKey: "userEmail")

                     
                    } else {
                        print("❌ OnboardingViewModel: Backend save failed - \(errorMessage ?? "Unknown error")")
                        self.onboardingCompleted = true
                        self.isShowingOnboarding = false
                        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                        UserDefaults.standard.set(self.email, forKey: "userEmail")

                        print("⚠️ OnboardingViewModel: Completed with local save only (backend sync failed)")
                        self.errorMessage = "Onboarding saved locally. Backend sync failed: \(errorMessage ?? "Unknown error")"
                    }

                    self.logInitialWeightIfNeeded()
                }
            }
        }
    }

    private func logInitialWeightIfNeeded() {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard weightKg > 0, !normalizedEmail.isEmpty else { return }

        let key = initialWeightLogKeyPrefix + normalizedEmail.lowercased()
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        NetworkManagerTwo.shared.logWeight(
            userEmail: normalizedEmail,
            weightKg: weightKg,
            notes: "Logged during onboarding"
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    UserDefaults.standard.set(true, forKey: key)
                    NotificationCenter.default.post(name: Notification.Name("WeightLoggedNotification"), object: nil)
                    print("✅ OnboardingViewModel: Initial weight log created during onboarding")
                case .failure(let error):
                    print("⚠️ OnboardingViewModel: Failed to log initial weight - \(error.localizedDescription)")
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
            return
        }

        switch step {
        case "EnterNameView":
            currentStep = .enterName
        case "GreetingView":
            currentStep = .greeting
        case "FitnessGoalSelectionView":
            currentStep = .fitnessGoal
        case "StrengthExperienceView":
            currentStep = .strengthExperience
        case "DesiredWeightSelectionView":
            currentStep = .desiredWeight
        case "GymLocationView":
            currentStep = .gymLocation
        case "ReviewEquipmentView":
            currentStep = .reviewEquipment
        case "ScheduleSelectionView":
            currentStep = .workoutSchedule
        case "DietPreferencesView":
            currentStep = .dietPreferences
        case "EnableNotificationsView":
            currentStep = .enableNotifications
        case "AllowHealthView":
            currentStep = .allowHealth
        case "AboutYouView":
            currentStep = .aboutYou
        case "ProgramOverviewView":
            currentStep = .programOverview
        case "SignupView":
            currentStep = .signup
        default:
            break
        }

        newOnboardingStepIndex = min(newOnboardingTotalSteps, newOnboardingIndex(for: currentStep))
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

    private func newOnboardingIndex(for step: OnboardingStep) -> Int {
        switch step {
        case .enterName: return 1
        case .greeting: return 2
        case .fitnessGoal: return 3
        case .strengthExperience: return 4
        case .gymLocation: return 5
        case .reviewEquipment: return 6
        case .workoutSchedule: return 7
        case .dietPreferences: return 8
        case .enableNotifications: return 9
        case .demo: return 10
        case .allowHealth: return 11
        case .aboutYou: return 12
        case .desiredWeight: return 13
        case .programOverview, .signup: return 14
        default: return 1
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
            pendingInitialFoodTab = tab
            // Store the initial tab for FoodContainerView to use
            UserDefaults.standard.set(tab, forKey: "initialFoodTabFromNewSheet")
        } else {
            pendingInitialFoodTab = nil
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
