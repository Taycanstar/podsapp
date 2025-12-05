import Foundation

struct MacroTotals: Equatable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    init(calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    static let zero = MacroTotals(calories: 0, protein: 0, carbs: 0, fat: 0)

    mutating func add(_ other: MacroTotals) {
        calories += other.calories
        protein += other.protein
        carbs += other.carbs
        fat += other.fat
    }

    var isZero: Bool {
        calories == 0 && protein == 0 && carbs == 0 && fat == 0
    }

    var totalMacros: Double { protein + carbs + fat }

    var proteinPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return (protein / totalMacros) * 100
    }

    var carbsPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return (carbs / totalMacros) * 100
    }

    var fatPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return (fat / totalMacros) * 100
    }
}

enum MealPeriod: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var displayName: String { title }
}

struct RawNutrientValue: Equatable {
    let value: Double
    let unit: String?
}
