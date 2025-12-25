import Foundation
import SwiftUI

struct PlateEntry: Identifiable, Equatable {
    let id = UUID()
    var food: Food
    var servings: Double
    var selectedMeasureId: Int?
    let availableMeasures: [FoodMeasure]
    let baselineGramWeight: Double
    let baseNutrientValues: [String: RawNutrientValue]
    let baseMacroTotals: MacroTotals
    let servingDescription: String
    let mealItems: [MealItem]
    let mealPeriod: MealPeriod
    let mealTime: Date

    // Recipe ingredients for "Expand Ingredients" feature
    let recipeItems: [RecipeFoodItem]

    var title: String { food.displayName }
    var brand: String { food.brandText ?? "" }

    var selectedMeasure: FoodMeasure? {
        availableMeasures.first(where: { $0.id == selectedMeasureId }) ?? availableMeasures.first
    }

    var currentMeasureLabel: String {
        if let measure = selectedMeasure {
            let trimmed = measure.disseminationText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            return measure.measureUnitName
        }
        return servingDescription
    }

    var selectedMeasureWeight: Double {
        selectedMeasure?.gramWeight ?? baselineGramWeight
    }

    private var measureScalingFactor: Double {
        guard let measure = selectedMeasure,
              baselineGramWeight > 0,
              measure.gramWeight > 0 else { return 1 }
        return measure.gramWeight / baselineGramWeight
    }

    var totalGramWeight: Double {
        let weight = selectedMeasure?.gramWeight ?? baselineGramWeight
        return weight * servings
    }

    var macroTotals: MacroTotals {
        let factor = measureScalingFactor * servings
        return MacroTotals(
            calories: baseMacroTotals.calories * factor,
            protein: baseMacroTotals.protein * factor,
            carbs: baseMacroTotals.carbs * factor,
            fat: baseMacroTotals.fat * factor
        )
    }

    var nutrientValues: [String: RawNutrientValue] {
        baseNutrientValues.mapValues { value in
            RawNutrientValue(value: value.value * measureScalingFactor * servings, unit: value.unit)
        }
    }
}

final class PlateViewModel: ObservableObject {
    let instanceId = UUID()
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
        print("[PlateViewModel \(instanceId)] Added entry, now have \(entries.count) entries")
    }

    func updateServings(for entryID: UUID, servings: Double) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].servings = servings
    }

    func updateMeasure(for entryID: UUID, measureId: Int?) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].selectedMeasureId = measureId
    }

    func remove(_ entry: PlateEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    func clear() {
        print("[PlateViewModel \(instanceId)] Clearing all entries")
        entries.removeAll()
    }
}
