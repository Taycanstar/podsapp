import Foundation

enum VitaminUnit: String, CaseIterable, Identifiable {
    case mcg = "mcg"
    case iu = "IU"

    var id: String { rawValue }

    static let storageKeyPrefix = "vitamin.unit.preference."
}

enum VitaminType: String {
    case vitaminA = "vitamin_a"
    case vitaminD = "vitamin_d"
    case vitaminE = "vitamin_e"

    /// Base unit for storage (mcg for A/D, mg for E)
    var baseUnit: String {
        switch self {
        case .vitaminA, .vitaminD: return "mcg"
        case .vitaminE: return "mg"
        }
    }

    /// Display label for the vitamin
    var displayLabel: String {
        switch self {
        case .vitaminA: return "Vitamin A"
        case .vitaminD: return "Vitamin D"
        case .vitaminE: return "Vitamin E"
        }
    }

    /// Converts from IU to base unit (mcg for A/D, mg for E)
    /// Vitamin A: 1 mcg RAE = 3.33 IU
    /// Vitamin D: 1 mcg = 40 IU
    /// Vitamin E: 1 mg = 1.49 IU
    func toBaseUnit(_ value: Double, from unit: VitaminUnit) -> Double {
        switch unit {
        case .mcg:
            return value
        case .iu:
            switch self {
            case .vitaminA: return value / 3.33
            case .vitaminD: return value / 40
            case .vitaminE: return value / 1.49
            }
        }
    }

    /// Converts from base unit to IU
    func fromBaseUnit(_ value: Double, to unit: VitaminUnit) -> Double {
        switch unit {
        case .mcg:
            return value
        case .iu:
            switch self {
            case .vitaminA: return value * 3.33
            case .vitaminD: return value * 40
            case .vitaminE: return value * 1.49
            }
        }
    }
}
