import Foundation

enum WaterUnit: String, CaseIterable, Identifiable {
    case cupsImperial = "cups (Imperial)"
    case cupsUS = "cups (US)"
    case fluidOunceImperial = "fl oz (Imperial)"
    case fluidOunceUS = "fl oz (US)"
    case liters = "L"
    case milliliters = "mL"
    case pintImperial = "pt (Imperial)"
    case pintUS = "pt (US)"

    static let defaultUnit: WaterUnit = .fluidOunceUS
    static let storageKey = "water.unit.preference"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var abbreviation: String {
        switch self {
        case .cupsImperial, .cupsUS:
            return "cups"
        case .fluidOunceImperial, .fluidOunceUS:
            return "fl oz"
        case .liters:
            return "L"
        case .milliliters:
            return "mL"
        case .pintImperial, .pintUS:
            return "pt"
        }
    }

    var presets: [Double] {
        switch self {
        case .fluidOunceUS, .fluidOunceImperial:
            return [8, 12, 16, 20, 24, 32]
        case .cupsUS, .cupsImperial, .pintUS, .pintImperial:
            return [0.5, 1, 1.5, 2, 2.5, 3]
        case .liters:
            return [0.25, 0.5, 0.75, 1, 1.5, 2]
        case .milliliters:
            return [125, 250, 375, 500, 750, 1000]
        }
    }

    private var maximumFractionDigits: Int {
        switch self {
        case .milliliters:
            return 0
        case .liters:
            return 2
        case .cupsImperial, .cupsUS, .pintImperial, .pintUS:
            return 2
        case .fluidOunceImperial, .fluidOunceUS:
            return 1
        }
    }

    private var millilitersPerUnit: Double {
        switch self {
        case .cupsImperial:
            return 284.130625
        case .cupsUS:
            return 236.5882365
        case .fluidOunceImperial:
            return 28.4130625
        case .fluidOunceUS:
            return 29.5735295625
        case .liters:
            return 1000
        case .milliliters:
            return 1
        case .pintImperial:
            return 568.26125
        case .pintUS:
            return 473.176473
        }
    }

    func format(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%0.*f", maximumFractionDigits, amount)
    }

    func presetLabel(for amount: Double) -> String {
        "\(format(amount)) \(abbreviation)"
    }

    func convertToUSFluidOunces(_ amount: Double) -> Double {
        let milliliters = amount * millilitersPerUnit
        return milliliters / WaterUnit.fluidOunceUS.millilitersPerUnit
    }

    func convertFromUSFluidOunces(_ usOunces: Double) -> Double {
        let milliliters = usOunces * WaterUnit.fluidOunceUS.millilitersPerUnit
        return milliliters / millilitersPerUnit
    }
}
