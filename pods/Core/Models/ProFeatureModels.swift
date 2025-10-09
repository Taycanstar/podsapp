import Foundation

struct FeatureAccessResponse: Codable {
    let allowed: Bool
    let reason: String?
    let tier: String?
    let currentUsage: Int?
    let limit: Int?
    let resetAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case allowed
        case reason
        case tier
        case currentUsage = "current_usage"
        case limit
        case resetAt = "reset_at"
    }
}

struct UsageSummary: Codable {
    let subscriptionTier: String
    let foodScans: UsageDetail?
    let workouts: UsageDetail?
    
    enum CodingKeys: String, CodingKey {
        case subscriptionTier = "subscription_tier"
        case foodScans = "food_scans"
        case workouts
    }
}

struct UsageDetail: Codable {
    let current: Int
    let limit: Int?
    let resetAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case current
        case limit
        case resetAt = "reset_at"
    }
}

struct ProFoodSearchResult: Codable {
    struct Macros: Codable {
        let proteinG: Double?
        let carbsG: Double?
        let fatG: Double?
        
        enum CodingKeys: String, CodingKey {
            case proteinG = "protein_g"
            case carbsG = "carbs_g"
            case fatG = "fat_g"
        }
    }
    
    struct Micro: Codable {
        let name: String
        let amount: String
        
        enum CodingKeys: String, CodingKey {
            case name
            case amount
        }
    }
    
    let name: String?
    let serving: String?
    let calories: Double?
    let macros: Macros?
    let micros: [Micro]?
    let sources: [String]?
}

struct ScheduleMealResponse: Codable {
    let id: Int
    let scheduleType: String
    let targetDate: Date
    let mealType: String?
    let sourceType: String
    let logId: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case scheduleType = "schedule_type"
        case targetDate = "target_date"
        case mealType = "meal_type"
        case sourceType = "source_type"
        case logId = "log_id"
    }
}
