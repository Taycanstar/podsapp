//
//  IngredientSummaryView.swift
//  pods
//
//  Created by Dimi Nunez on 12/20/25.
//

import SwiftUI
import UIKit

// MARK: - MacroRingView (copied from ConfirmLogView for ingredient summary)

private struct IngredientMacroRingView: View {
    let calories: Double
    let arcs: [IngredientMacroArc]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 8)

            ForEach(arcs.indices, id: \.self) { index in
                let arc = arcs[index]
                Circle()
                    .trim(from: CGFloat(arc.start), to: CGFloat(arc.end))
                    .stroke(arc.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: -4) {
                Text(String(format: "%.0f", calories))
                    .font(.system(size: 20, weight: .medium))
                Text("cals")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct IngredientMacroArc {
    let start: Double
    let end: Double
    let color: Color
}

private struct IngredientMacroSegment {
    let color: Color
    let fraction: Double
}

// MARK: - IngredientSummaryView

struct IngredientSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel

    let food: Food
    var onAddToRecipe: (Food) -> Void

    @State private var numberOfServings: Double = 1
    @State private var servingsInput: String = "1"
    @State private var servingAmountInput: String = "1"
    @State private var servingAmount: Double = 1
    @State private var selectedMeasure: FoodMeasure?
    @State private var isAdding = false
    @State private var nutrientTargets: [String: NutrientTargetDetails] = NutritionGoalsStore.shared.currentTargets
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared
    @FocusState private var isServingsFocused: Bool

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("bg") : Color(UIColor.systemGroupedBackground)
    }

    private var cardColor: Color {
        colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color("bg")
    }

    private var chipColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }

    // Available measures from food
    private var availableMeasures: [FoodMeasure] {
        food.foodMeasures ?? []
    }

    private var hasMeasureOptions: Bool {
        availableMeasures.count > 1
    }

    // Baseline gram weight (the original measure's gram weight)
    private var baselineGramWeight: Double {
        availableMeasures.first?.gramWeight ?? food.servingSize ?? 100
    }

    // Selected measure's gram weight
    private var selectedGramWeight: Double {
        selectedMeasure?.gramWeight ?? baselineGramWeight
    }

    // Measure scaling factor (how much does selected measure differ from baseline)
    private var measureScalingFactor: Double {
        guard baselineGramWeight > 0, selectedGramWeight > 0 else { return 1 }
        return selectedGramWeight / baselineGramWeight
    }

    // Base nutrient values (per single serving as provided by API)
    private var baseCalories: Double {
        food.calories ?? 0
    }

    private var baseProtein: Double {
        food.protein ?? 0
    }

    private var baseCarbs: Double {
        food.carbs ?? 0
    }

    private var baseFat: Double {
        food.fat ?? 0
    }

    // Adjusted values based on serving amount, measure, and number of servings
    private var adjustedCalories: Double {
        baseCalories * servingAmount * numberOfServings * measureScalingFactor
    }

    private var adjustedProtein: Double {
        baseProtein * servingAmount * numberOfServings * measureScalingFactor
    }

    private var adjustedCarbs: Double {
        baseCarbs * servingAmount * numberOfServings * measureScalingFactor
    }

    private var adjustedFat: Double {
        baseFat * servingAmount * numberOfServings * measureScalingFactor
    }

    // Macro arcs for ring view
    private var macroSegments: [IngredientMacroSegment] {
        let proteinCalories = adjustedProtein * 4
        let carbCalories = adjustedCarbs * 4
        let fatCalories = adjustedFat * 9
        let total = max(proteinCalories + carbCalories + fatCalories, 1)
        return [
            IngredientMacroSegment(color: Color("protein"), fraction: proteinCalories / total),
            IngredientMacroSegment(color: Color("fat"), fraction: fatCalories / total),
            IngredientMacroSegment(color: Color("carbs"), fraction: carbCalories / total)
        ]
    }

    private var macroArcs: [IngredientMacroArc] {
        var running: Double = 0
        return macroSegments.map { segment in
            let arc = IngredientMacroArc(start: running, end: running + segment.fraction, color: segment.color)
            running += segment.fraction
            return arc
        }
    }

    // Fiber value for net carbs calculation
    private var adjustedFiber: Double {
        nutrientValue(for: IngredientNutrientRowDescriptor(
            label: "Fiber",
            slug: "fiber",
            defaultUnit: "g",
            source: .nutrient(names: ["fiber, total dietary", "dietary fiber"]),
            color: .clear
        ))
    }

    // Normalized nutrient lookup from food.foodNutrients
    private var nutrientLookup: [String: (value: Double, unit: String)] {
        var lookup: [String: (Double, String)] = [:]
        for nutrient in food.foodNutrients {
            let key = nutrient.nutrientName.lowercased()
            let value = nutrient.value ?? 0
            let unit = nutrient.unitName ?? ""
            lookup[key] = (value, unit)
        }
        return lookup
    }

    private func nutrientValue(for descriptor: IngredientNutrientRowDescriptor) -> Double {
        let scaleFactor = servingAmount * numberOfServings * measureScalingFactor

        switch descriptor.source {
        case .macro(let macro):
            switch macro {
            case .protein: return adjustedProtein
            case .carbs: return adjustedCarbs
            case .fat: return adjustedFat
            }
        case .nutrient(let names, let aggregation):
            let matches = names.compactMap { nutrientLookup[$0.lowercased()] }
            guard !matches.isEmpty else { return 0 }
            let baseValue: Double
            switch aggregation {
            case .first:
                baseValue = matches.first?.value ?? 0
            case .sum:
                baseValue = matches.reduce(0) { $0 + $1.value }
            }
            return baseValue * scaleFactor
        case .computed(let computation):
            switch computation {
            case .netCarbs:
                return max(adjustedCarbs - adjustedFiber, 0)
            case .calories:
                return adjustedCalories
            }
        }
    }

    private func nutrientUnit(for descriptor: IngredientNutrientRowDescriptor) -> String {
        descriptor.defaultUnit
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        macroSummaryCard
                        portionDetailsCard

                        // Nutrient Sections
                        totalCarbsSection
                        fatTotalsSection
                        proteinTotalsSection
                        vitaminSection
                        mineralSection
                        otherNutrientSection

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }

                footerBar
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(food.description)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                setupInitialValues()
                nutrientTargets = goalsStore.currentTargets
            }
        }
    }

    private func setupInitialValues() {
        // Set initial selected measure
        if selectedMeasure == nil {
            selectedMeasure = availableMeasures.first
        }
        // Set initial serving amount from food
        if let size = food.servingSize, size > 0 {
            servingAmount = 1
            servingAmountInput = "1"
        }
    }

    // MARK: - Macro Summary Card (matches ConfirmLogView)

    private var macroSummaryCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                macroStatRow(title: "Protein", value: adjustedProtein, unit: "g", color: Color("protein"))
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Fat", value: adjustedFat, unit: "g", color: Color("fat"))
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Carbs", value: adjustedCarbs, unit: "g", color: Color("carbs"))
            }

            Spacer()

            IngredientMacroRingView(calories: adjustedCalories, arcs: macroArcs)
                .frame(width: 100, height: 100)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    private func macroStatRow(title: String, value: Double, unit: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(title.capitalized)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Text("\(value.cleanOneDecimal)\(unit)")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Portion Details Card (matches ConfirmLogView)

    private var portionDetailsCard: some View {
        VStack(spacing: 0) {
            // Serving Size row
            labeledRow("Serving Size") {
                HStack(spacing: 8) {
                    TextField("1", text: $servingAmountInput)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.center)
                        .focused($isServingsFocused)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(chipColor)
                        )
                        .frame(width: 70)
                        .onChange(of: servingAmountInput) { _, newValue in
                            if let parsed = parseServingsInput(newValue), parsed > 0 {
                                servingAmount = parsed
                            }
                        }

                    if hasMeasureOptions {
                        Menu {
                            ForEach(availableMeasures, id: \.id) { measure in
                                Button(sanitizedMeasureLabel(measure)) {
                                    selectedMeasure = measure
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(sanitizedMeasureLabel(selectedMeasure ?? availableMeasures.first))
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(
                                Capsule()
                                    .fill(chipColor)
                            )
                        }
                        .menuStyle(.borderlessButton)
                    } else {
                        Text(sanitizedMeasureLabel(selectedMeasure ?? availableMeasures.first))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(
                                Capsule()
                                    .fill(chipColor)
                            )
                    }
                }
            }

            Divider().padding(.leading, 16)

            // Number of Servings row
            labeledRow("Servings") {
                TextField("1", text: $servingsInput)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(chipColor)
                    )
                    .frame(width: 70)
                    .onChange(of: servingsInput) { _, newValue in
                        if let parsed = parseServingsInput(newValue), parsed > 0 {
                            numberOfServings = parsed
                        }
                    }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    private func labeledRow<Content: View>(
        _ label: String,
        verticalPadding: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, verticalPadding)
    }

    private func sanitizedMeasureLabel(_ measure: FoodMeasure?) -> String {
        guard let measure = measure else {
            return food.householdServingFullText ?? "serving"
        }
        let text = measure.disseminationText ?? measure.modifier ?? "serving"
        return text.isEmpty ? "serving" : text
    }

    private func parseServingsInput(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }

        // Handle fractions like "1/2"
        if trimmed.contains("/") {
            let parts = trimmed.split(separator: "/")
            if parts.count == 2,
               let num = Double(parts[0]),
               let denom = Double(parts[1]),
               denom != 0 {
                return num / denom
            }
        }

        return Double(trimmed)
    }

    // MARK: - Nutrient Sections

    private var totalCarbsSection: some View {
        nutrientSection(title: "Total Carbs", rows: IngredientNutrientDescriptors.totalCarbRows)
    }

    private var fatTotalsSection: some View {
        nutrientSection(title: "Total Fat", rows: IngredientNutrientDescriptors.fatRows)
    }

    private var proteinTotalsSection: some View {
        nutrientSection(title: "Total Protein", rows: IngredientNutrientDescriptors.proteinRows)
    }

    private var vitaminSection: some View {
        nutrientSection(title: "Vitamins", rows: IngredientNutrientDescriptors.vitaminRows)
    }

    private var mineralSection: some View {
        nutrientSection(title: "Minerals", rows: IngredientNutrientDescriptors.mineralRows)
    }

    private var otherNutrientSection: some View {
        nutrientSection(title: "Other", rows: IngredientNutrientDescriptors.otherRows)
    }

    private func nutrientSection(title: String, rows: [IngredientNutrientRowDescriptor]) -> some View {
        // Filter rows to only show nutrients that exist in the data
        let filteredRows = rows.filter { descriptor in
            switch descriptor.source {
            case .macro, .computed:
                return true
            case .nutrient(let names, _):
                return names.contains { name in
                    nutrientLookup[name.lowercased()] != nil
                }
            }
        }

        return Group {
            if !filteredRows.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.horizontal)

                    VStack(spacing: 16) {
                        ForEach(filteredRows) { descriptor in
                            nutrientRow(for: descriptor)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(cardColor)
                    )
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    private func nutrientRow(for descriptor: IngredientNutrientRowDescriptor) -> some View {
        let value = nutrientValue(for: descriptor)
        let goal = nutrientGoal(for: descriptor)
        let unit = nutrientUnit(for: descriptor)
        let percentage = nutrientPercentage(value: value, goal: goal)
        let ratio = nutrientRatioText(value: value, goal: goal, unit: unit)
        let progress = nutrientProgressValue(value: value, goal: goal)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(ratio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(percentage)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(descriptor.color)
            }

            ProgressView(value: progress)
                .tint(descriptor.color)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
        }
    }

    // MARK: - Goal Helper Functions

    private func nutrientGoal(for descriptor: IngredientNutrientRowDescriptor) -> Double? {
        var resolvedGoal: Double?
        if let slug = descriptor.slug,
           let details = nutrientTargets[slug] {
            if let target = details.target, target > 0 {
                resolvedGoal = target
            } else if let max = details.max, max > 0 {
                resolvedGoal = max
            } else if let idealMax = details.idealMax, idealMax > 0 {
                resolvedGoal = idealMax
            }
        }
        if let resolvedGoal {
            return convertGoal(resolvedGoal, for: descriptor)
        }

        switch descriptor.source {
        case .macro(let macro):
            switch macro {
            case .protein: return dayLogsVM.proteinGoal
            case .carbs: return dayLogsVM.carbsGoal
            case .fat: return dayLogsVM.fatGoal
            }
        case .computed(let computation):
            switch computation {
            case .calories:
                return dayLogsVM.calorieGoal
            case .netCarbs:
                if let target = nutrientTargets["net_carbs"]?.target {
                    return convertGoal(target, for: descriptor)
                }
                return nil
            }
        default:
            return nil
        }
    }

    private func nutrientPercentage(value: Double, goal: Double?) -> String {
        guard let goal, goal > 0 else { return "--" }
        let percent = (value / goal) * 100
        return "\(percent.cleanZeroDecimal)%"
    }

    private func nutrientProgressValue(value: Double, goal: Double?) -> Double {
        guard let goal, goal > 0 else { return 0 }
        return min(max(value / goal, 0), 1)
    }

    private func nutrientRatioText(value: Double, goal: Double?, unit: String) -> String {
        let valueText = value.goalShareFormatted
        let goalText = goal.map { $0.goalShareFormatted } ?? "--"
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUnit.isEmpty {
            return "\(valueText)/\(goalText)"
        } else {
            return "\(valueText)/\(goalText) \(trimmedUnit)"
        }
    }

    private func convertGoal(_ goal: Double, for descriptor: IngredientNutrientRowDescriptor) -> Double {
        guard let slug = descriptor.slug,
              let storedUnit = nutrientTargets[slug]?.unit,
              !storedUnit.isEmpty else { return goal }
        let src = storedUnit.lowercased()
        let dst = descriptor.defaultUnit.lowercased()
        if src == dst { return goal }

        // Unit conversions
        if src == "mg" && dst == "g" { return goal / 1000 }
        if src == "g" && dst == "mg" { return goal * 1000 }
        if (src == "µg" || src == "mcg") && dst == "mg" { return goal / 1000 }
        if (src == "µg" || src == "mcg") && dst == "g" { return goal / 1_000_000 }
        if src == "mg" && (dst == "µg" || dst == "mcg") { return goal * 1000 }
        if src == "g" && (dst == "µg" || dst == "mcg") { return goal * 1_000_000 }

        return goal
    }

    private func reloadStoredNutrientTargets() {
        nutrientTargets = NutritionGoalsStore.shared.currentTargets
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            Button(action: {
                HapticFeedback.generateLigth()
                isAdding = true

                // Create a copy of the food with updated servings
                var updatedFood = food
                updatedFood.numberOfServings = numberOfServings * servingAmount

                onAddToRecipe(updatedFood)
                dismiss()
            }) {
                Text(isAdding ? "Adding..." : "Add to Recipe")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color("background"))
            )
            .foregroundColor(Color("text"))
            .disabled(isAdding)
            .opacity(isAdding ? 0.7 : 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Nutrient Section Types

private enum IngredientMacroType {
    case protein, carbs, fat
}

private enum IngredientNutrientAggregation {
    case first, sum
}

private enum IngredientNutrientComputation {
    case netCarbs, calories
}

private enum IngredientNutrientSource {
    case macro(IngredientMacroType)
    case nutrient(names: [String], aggregation: IngredientNutrientAggregation = .first)
    case computed(IngredientNutrientComputation)
}

private struct IngredientNutrientRowDescriptor: Identifiable {
    let id = UUID()
    let label: String
    let slug: String?
    let defaultUnit: String
    let source: IngredientNutrientSource
    let color: Color
}

private enum IngredientNutrientDescriptors {
    static let proteinColor = Color("protein")
    static let fatColor = Color("fat")
    static let carbColor = Color("carbs")

    static var totalCarbRows: [IngredientNutrientRowDescriptor] {
        [
            IngredientNutrientRowDescriptor(label: "Carbs", slug: "carbs", defaultUnit: "g", source: .macro(.carbs), color: carbColor),
            IngredientNutrientRowDescriptor(label: "Fiber", slug: "fiber", defaultUnit: "g", source: .nutrient(names: ["fiber, total dietary", "dietary fiber"]), color: carbColor),
            IngredientNutrientRowDescriptor(label: "Net (Non-fiber)", slug: "net_carbs", defaultUnit: "g", source: .computed(.netCarbs), color: carbColor),
            IngredientNutrientRowDescriptor(label: "Sugars", slug: "sugars", defaultUnit: "g", source: .nutrient(names: ["sugars, total including nlea", "sugars, total", "sugar"]), color: carbColor),
            IngredientNutrientRowDescriptor(label: "Sugars Added", slug: "added_sugars", defaultUnit: "g", source: .nutrient(names: ["sugars, added", "added sugars"]), color: carbColor)
        ]
    }

    static var fatRows: [IngredientNutrientRowDescriptor] {
        [
            IngredientNutrientRowDescriptor(label: "Fat", slug: "fat", defaultUnit: "g", source: .macro(.fat), color: fatColor),
            IngredientNutrientRowDescriptor(label: "Monounsaturated", slug: "monounsaturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total monounsaturated"]), color: fatColor),
            IngredientNutrientRowDescriptor(label: "Polyunsaturated", slug: "polyunsaturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total polyunsaturated"]), color: fatColor),
            IngredientNutrientRowDescriptor(label: "Saturated", slug: "saturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total saturated"]), color: fatColor),
            IngredientNutrientRowDescriptor(label: "Trans Fat", slug: "trans_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total trans"]), color: fatColor),
            IngredientNutrientRowDescriptor(label: "Cholesterol", slug: "cholesterol", defaultUnit: "mg", source: .nutrient(names: ["cholesterol"]), color: fatColor)
        ]
    }

    static var proteinRows: [IngredientNutrientRowDescriptor] {
        [
            IngredientNutrientRowDescriptor(label: "Protein", slug: "protein", defaultUnit: "g", source: .macro(.protein), color: proteinColor),
            IngredientNutrientRowDescriptor(label: "Histidine", slug: "histidine", defaultUnit: "mg", source: .nutrient(names: ["histidine"]), color: proteinColor),
            IngredientNutrientRowDescriptor(label: "Isoleucine", slug: "isoleucine", defaultUnit: "mg", source: .nutrient(names: ["isoleucine"]), color: proteinColor),
            IngredientNutrientRowDescriptor(label: "Leucine", slug: "leucine", defaultUnit: "mg", source: .nutrient(names: ["leucine"]), color: proteinColor),
            IngredientNutrientRowDescriptor(label: "Lysine", slug: "lysine", defaultUnit: "mg", source: .nutrient(names: ["lysine"]), color: proteinColor),
            IngredientNutrientRowDescriptor(label: "Methionine", slug: "methionine", defaultUnit: "mg", source: .nutrient(names: ["methionine"]), color: proteinColor),
            IngredientNutrientRowDescriptor(label: "Phenylalanine", slug: "phenylalanine", defaultUnit: "mg", source: .nutrient(names: ["phenylalanine"]), color: proteinColor),
            IngredientNutrientRowDescriptor(label: "Threonine", slug: "threonine", defaultUnit: "mg", source: .nutrient(names: ["threonine"]), color: proteinColor),
            IngredientNutrientRowDescriptor(label: "Tryptophan", slug: "tryptophan", defaultUnit: "mg", source: .nutrient(names: ["tryptophan"]), color: proteinColor),
            IngredientNutrientRowDescriptor(label: "Valine", slug: "valine", defaultUnit: "mg", source: .nutrient(names: ["valine"]), color: proteinColor)
        ]
    }

    static var vitaminRows: [IngredientNutrientRowDescriptor] {
        [
            IngredientNutrientRowDescriptor(label: "B1, Thiamine", slug: "vitamin_b1_thiamin", defaultUnit: "mg", source: .nutrient(names: ["thiamin", "vitamin b-1"]), color: .orange),
            IngredientNutrientRowDescriptor(label: "B2, Riboflavin", slug: "vitamin_b2_riboflavin", defaultUnit: "mg", source: .nutrient(names: ["riboflavin", "vitamin b-2"]), color: .orange),
            IngredientNutrientRowDescriptor(label: "B3, Niacin", slug: "vitamin_b3_niacin", defaultUnit: "mg", source: .nutrient(names: ["niacin", "vitamin b-3"]), color: .orange),
            IngredientNutrientRowDescriptor(label: "B6, Pyridoxine", slug: "vitamin_b6_pyridoxine", defaultUnit: "mg", source: .nutrient(names: ["vitamin b-6", "pyridoxine", "vitamin b6"]), color: .orange),
            IngredientNutrientRowDescriptor(label: "B5, Pantothenic Acid", slug: "vitamin_b5_pantothenic_acid", defaultUnit: "mg", source: .nutrient(names: ["pantothenic acid"]), color: .orange),
            IngredientNutrientRowDescriptor(label: "B12, Cobalamin", slug: "vitamin_b12_cobalamin", defaultUnit: "mcg", source: .nutrient(names: ["vitamin b-12", "cobalamin"]), color: .orange),
            IngredientNutrientRowDescriptor(label: "Folate", slug: "folate", defaultUnit: "mcg", source: .nutrient(names: ["folate, total", "folic acid"]), color: .orange),
            IngredientNutrientRowDescriptor(label: "Vitamin A", slug: "vitamin_a", defaultUnit: "mcg", source: .nutrient(names: ["vitamin a, rae", "vitamin a"]), color: .orange),
            IngredientNutrientRowDescriptor(label: "Vitamin C", slug: "vitamin_c", defaultUnit: "mg", source: .nutrient(names: ["vitamin c, total ascorbic acid", "vitamin c"]), color: .orange),
            IngredientNutrientRowDescriptor(label: "Vitamin D", slug: "vitamin_d", defaultUnit: "IU", source: .nutrient(names: ["vitamin d (d2 + d3)", "vitamin d"]), color: .orange),
            IngredientNutrientRowDescriptor(label: "Vitamin E", slug: "vitamin_e", defaultUnit: "mg", source: .nutrient(names: ["vitamin e (alpha-tocopherol)", "vitamin e"]), color: .orange),
            IngredientNutrientRowDescriptor(label: "Vitamin K", slug: "vitamin_k", defaultUnit: "mcg", source: .nutrient(names: ["vitamin k (phylloquinone)", "vitamin k"]), color: .orange)
        ]
    }

    static var mineralRows: [IngredientNutrientRowDescriptor] {
        [
            IngredientNutrientRowDescriptor(label: "Calcium", slug: "calcium", defaultUnit: "mg", source: .nutrient(names: ["calcium, ca"]), color: .blue),
            IngredientNutrientRowDescriptor(label: "Copper", slug: "copper", defaultUnit: "mcg", source: .nutrient(names: ["copper, cu"]), color: .blue),
            IngredientNutrientRowDescriptor(label: "Iron", slug: "iron", defaultUnit: "mg", source: .nutrient(names: ["iron, fe"]), color: .blue),
            IngredientNutrientRowDescriptor(label: "Magnesium", slug: "magnesium", defaultUnit: "mg", source: .nutrient(names: ["magnesium, mg"]), color: .blue),
            IngredientNutrientRowDescriptor(label: "Manganese", slug: "manganese", defaultUnit: "mg", source: .nutrient(names: ["manganese, mn"]), color: .blue),
            IngredientNutrientRowDescriptor(label: "Phosphorus", slug: "phosphorus", defaultUnit: "mg", source: .nutrient(names: ["phosphorus, p"]), color: .blue),
            IngredientNutrientRowDescriptor(label: "Potassium", slug: "potassium", defaultUnit: "mg", source: .nutrient(names: ["potassium, k"]), color: .blue),
            IngredientNutrientRowDescriptor(label: "Selenium", slug: "selenium", defaultUnit: "mcg", source: .nutrient(names: ["selenium, se"]), color: .blue),
            IngredientNutrientRowDescriptor(label: "Sodium", slug: "sodium", defaultUnit: "mg", source: .nutrient(names: ["sodium, na"]), color: .blue),
            IngredientNutrientRowDescriptor(label: "Zinc", slug: "zinc", defaultUnit: "mg", source: .nutrient(names: ["zinc, zn"]), color: .blue)
        ]
    }

    static var otherRows: [IngredientNutrientRowDescriptor] {
        [
            IngredientNutrientRowDescriptor(label: "Calories", slug: "calories", defaultUnit: "kcal", source: .computed(.calories), color: .purple),
            IngredientNutrientRowDescriptor(label: "Alcohol", slug: "alcohol", defaultUnit: "g", source: .nutrient(names: ["alcohol, ethyl"]), color: .purple),
            IngredientNutrientRowDescriptor(label: "Caffeine", slug: "caffeine", defaultUnit: "mg", source: .nutrient(names: ["caffeine"]), color: .purple),
            IngredientNutrientRowDescriptor(label: "Water", slug: "water", defaultUnit: "ml", source: .nutrient(names: ["water"]), color: .purple)
        ]
    }
}

#Preview {
    IngredientSummaryView(
        food: Food(
            fdcId: 123,
            description: "Chicken Breast",
            brandOwner: nil,
            brandName: nil,
            servingSize: 100,
            numberOfServings: 1,
            servingSizeUnit: "g",
            householdServingFullText: "1 breast",
            foodNutrients: [],
            foodMeasures: [],
            healthAnalysis: nil,
            aiInsight: nil,
            nutritionScore: nil,
            mealItems: nil,
            barcode: nil
        ),
        onAddToRecipe: { _ in }
    )
}
