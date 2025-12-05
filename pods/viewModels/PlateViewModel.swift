import Foundation
import SwiftUI

struct PlateEntry: Identifiable, Equatable {
    let id = UUID()
    let food: Food
    let servings: Double
    let servingDescription: String
    let macroTotals: MacroTotals
    let nutrientValues: [String: RawNutrientValue]
    let mealItems: [MealItem]
    let mealPeriod: MealPeriod
    let mealTime: Date

    var title: String { food.displayName }
    var brand: String { food.brandText ?? "" }
}

final class PlateViewModel: ObservableObject {
    @Published private(set) var entries: [PlateEntry] = []

    var hasEntries: Bool { !entries.isEmpty }

    var totalMacros: MacroTotals {
        entries.reduce(into: MacroTotals.zero) { running, entry in
            running.add(entry.macroTotals)
        }
    }

    var totalNutrients: [String: RawNutrientValue] {
        entries.reduce(into: [:]) { partialResult, entry in
            for (key, value) in entry.nutrientValues {
                if let existing = partialResult[key] {
                    let combined = existing.value + value.value
                    partialResult[key] = RawNutrientValue(value: combined, unit: existing.unit ?? value.unit)
                } else {
                    partialResult[key] = value
                }
            }
        }
    }

    func reset(with entries: [PlateEntry]) {
        self.entries = entries
    }

    func add(_ entry: PlateEntry) {
        entries.append(entry)
    }

    func remove(_ entry: PlateEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    func clear() {
        entries.removeAll()
    }
}
