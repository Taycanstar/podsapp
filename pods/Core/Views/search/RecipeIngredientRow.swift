//
//  RecipeIngredientEditableItem.swift
//  pods
//
//  Created by Dimi Nunez on 12/25/25.
//


import SwiftUI

struct RecipeIngredientEditableItem {
    var servingAmount: Double
    var servingAmountInput: String
    var selectedMeasureId: Int?
    let measures: [FoodMeasure]
    let baselineServing: Double
    let baselineMeasureId: Int?

    var selectedMeasure: FoodMeasure? {
        if let id = selectedMeasureId,
           let match = measures.first(where: { $0.id == id }) {
            return match
        }
        if let baselineId = baselineMeasureId,
           let match = measures.first(where: { $0.id == baselineId }) {
            return match
        }
        return measures.first
    }

    var hasMeasureOptions: Bool {
        measures.count > 1
    }

    var scalingFactor: Double {
        guard baselineServing > 0 else { return servingAmount }
        if let baselineWeight = measures.first(where: { $0.id == baselineMeasureId })?.gramWeight,
           baselineWeight > 0,
           let selectedWeight = selectedMeasure?.gramWeight,
           selectedWeight > 0 {
            return (servingAmount * selectedWeight) / (baselineServing * baselineWeight)
        }
        return servingAmount / baselineServing
    }

    init(from food: Food) {
        let initialServing = food.numberOfServings ?? 1.0
        let measures = food.foodMeasures
        let baselineId = RecipeIngredientEditableItem.matchingMeasureId(for: food, in: measures) ?? measures.first?.id
        self.servingAmount = initialServing
        self.servingAmountInput = RecipeIngredientEditableItem.formatServing(initialServing)
        self.measures = measures
        self.baselineServing = initialServing
        self.baselineMeasureId = baselineId
        self.selectedMeasureId = baselineId
    }

    static func formatServing(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
    }

    static func parseServing(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let slashIndex = trimmed.firstIndex(of: "/") {
            let numeratorStr = String(trimmed[..<slashIndex])
            let denominatorStr = String(trimmed[trimmed.index(after: slashIndex)...])
            if let num = Double(numeratorStr.trimmingCharacters(in: .whitespaces)),
               let denom = Double(denominatorStr.trimmingCharacters(in: .whitespaces)),
               denom != 0 {
                return num / denom
            }
        }

        return Double(trimmed)
    }

    static func shortUnitLabel(from text: String) -> String {
        var label = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if label.isEmpty { return "serving" }

        let weightParenPattern = "\\s*\\([0-9.]+\\s*(g|oz|ml|mL|fl oz)\\)"
        label = label.replacingOccurrences(of: weightParenPattern, with: "", options: .regularExpression)

        let numberPrefixPattern = "^[0-9]+(\\.[0-9]+)?([/][0-9]+)?\\s*(x)?\\s*"
        label = label.replacingOccurrences(of: numberPrefixPattern, with: "", options: .regularExpression)

        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "serving" : trimmed
    }

    private static func matchingMeasureId(for food: Food, in measures: [FoodMeasure]) -> Int? {
        guard !measures.isEmpty else { return nil }
        let servingText = food.householdServingFullText ?? ""
        let servingUnit = food.servingSizeUnit ?? ""
        let hints = [servingText, servingUnit]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { shortUnitLabel(from: $0).lowercased() }
            .filter { !$0.isEmpty }

        for hint in hints {
            if let match = measures.first(where: {
                let label = shortUnitLabel(from: $0.disseminationText).lowercased()
                if label == hint { return true }
                return $0.measureUnitName.lowercased() == hint
            }) {
                return match.id
            }
        }
        return measures.first?.id
    }
}

struct RecipeIngredientEditableRow: View {
    @Binding var food: Food
    @Binding var editableItem: RecipeIngredientEditableItem
    let chipColor: Color

    private var scaledCalories: Int {
        Int(((food.calories ?? 0) * editableItem.scalingFactor).rounded())
    }

    private var scaledProtein: Int {
        Int(((food.protein ?? 0) * editableItem.scalingFactor).rounded())
    }

    private var scaledFat: Int {
        Int(((food.fat ?? 0) * editableItem.scalingFactor).rounded())
    }

    private var scaledCarbs: Int {
        Int(((food.carbs ?? 0) * editableItem.scalingFactor).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(food.description)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                servingControls
            }

            macroRow
        }
        .onChange(of: editableItem.servingAmount) { newValue in
            if food.numberOfServings != newValue {
                food.numberOfServings = newValue
            }
        }
    }

    private var servingControls: some View {
        HStack(spacing: 6) {
            TextField("1", text: servingAmountBinding)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.center)
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
                .frame(width: 50)
                .background(
                    Capsule().fill(chipColor)
                )
                .font(.system(size: 15))

            if editableItem.hasMeasureOptions {
                measureMenu
            } else {
                Text(fallbackUnitLabel())
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule().fill(chipColor)
                    )
            }
        }
        .fixedSize()
    }

    private var macroRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("\(scaledCalories) cal")
            }

            macroLabel(prefix: "P", value: scaledProtein)
            macroLabel(prefix: "F", value: scaledFat)
            macroLabel(prefix: "C", value: scaledCarbs)

            Spacer()
        }
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }

    private var measureMenu: some View {
        Menu {
            ForEach(editableItem.measures, id: \.id) { measure in
                Button(action: { selectMeasure(measure) }) {
                    HStack {
                        Text(unitLabel(for: measure))
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        Spacer()
                        if measure.id == editableItem.selectedMeasureId {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(unitLabel(for: editableItem.selectedMeasure))
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule().fill(chipColor)
            )
        }
        .menuStyle(.borderlessButton)
    }

    private var servingAmountBinding: Binding<String> {
        Binding(
            get: { editableItem.servingAmountInput },
            set: { newValue in
                editableItem.servingAmountInput = newValue
                if let parsed = RecipeIngredientEditableItem.parseServing(newValue),
                   parsed > 0,
                   abs(parsed - editableItem.servingAmount) > 0.0001 {
                    editableItem.servingAmount = parsed
                }
            }
        )
    }

    private func selectMeasure(_ measure: FoodMeasure) {
        editableItem.selectedMeasureId = measure.id
        let text = measure.disseminationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            food.householdServingFullText = text
        } else {
            food.householdServingFullText = measure.measureUnitName
        }
    }

    private func unitLabel(for measure: FoodMeasure?) -> String {
        guard let measure else { return fallbackUnitLabel() }
        return RecipeIngredientEditableItem.shortUnitLabel(from: measure.disseminationText)
    }

    private func fallbackUnitLabel() -> String {
        if let text = food.householdServingFullText, !text.isEmpty {
            return RecipeIngredientEditableItem.shortUnitLabel(from: text)
        }
        if let unit = food.servingSizeUnit, !unit.isEmpty {
            return RecipeIngredientEditableItem.shortUnitLabel(from: unit)
        }
        return "serving"
    }

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }
}

struct RecipeIngredientReadOnlyRow: View {
    let item: RecipeFoodItem
    let chipColor: Color

    private var servingsValue: Double {
        Double(item.servings) ?? 1
    }

    private var scaledCalories: Int {
        Int((item.calories * servingsValue).rounded())
    }

    private var scaledProtein: Int {
        Int((item.protein * servingsValue).rounded())
    }

    private var scaledFat: Int {
        Int((item.fat * servingsValue).rounded())
    }

    private var scaledCarbs: Int {
        Int((item.carbs * servingsValue).rounded())
    }

    private var amountText: String {
        RecipeIngredientEditableItem.formatServing(servingsValue)
    }

    private var unitText: String {
        RecipeIngredientEditableItem.shortUnitLabel(from: item.servingText ?? "serving")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(item.name)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Text(amountText)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                        .background(
                            Capsule().fill(chipColor)
                        )
                    Text(unitText)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule().fill(chipColor)
                        )
                }
                .fixedSize()
            }

            macroRow
        }
    }

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }

    private var macroRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("\(scaledCalories) cal")
            }

            macroLabel(prefix: "P", value: scaledProtein)
            macroLabel(prefix: "F", value: scaledFat)
            macroLabel(prefix: "C", value: scaledCarbs)

            Spacer()
        }
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }
}
