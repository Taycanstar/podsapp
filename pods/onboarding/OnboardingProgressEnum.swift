enum OnboardingProgressEnum: Int, CaseIterable, Codable {
    case gender = 1
    case workoutDays = 2
    case heightWeight = 3
    case dob = 4
    case onboardingGoal = 5
    case desiredWeight = 6
    case goalInfo = 7
    case goalTime = 8
    case twoX = 9
    case obstacles = 10
    case specificDiet = 11
    case accomplish = 12
    case connectHealth = 13
    case caloriesBurned = 14
    case rollover = 15
    case creatingPlan = 16
    
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
        case .creatingPlan: return .creatingPlan
        }
    }
} 