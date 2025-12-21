//
//  IngredientPlateSummaryView.swift
//  pods
//
//  Created by Dimi Nunez on 12/20/25.
//


//
//  IngredientPlateSummaryView.swift
//  pods
//
//  Created by Dimi Nunez on 12/20/25.
//

import SwiftUI

struct IngredientPlateSummaryView: View {
    let foods: [Food]
    let mealItems: [MealItem]
    var onAddToRecipe: ([Food], [MealItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel

    @State private var isAdding = false
    @State private var nutrientTargets: [String: NutrientTargetDetails] = NutritionGoalsStore.shared.currentTargets
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared

    /// Mutable copy of meal items for deletion support
    @State private var editableMealItems: [MealItem] = []

    private var plateBackground: Color {
        colorScheme == .dark ? Color("bg") : Color(UIColor.systemGroupedBackground)
    }

    private var cardColor: Color {
        colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color("bg")
    }

    // MARK: - Computed Macros

    private var totalMacros: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        var cals: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0

        // Use editable items (from editableMealItems for deletion support)
        for item in editableMealItems {
            cals += item.calories
            protein += item.protein
            carbs += item.carbs
            fat += item.fat
        }

        // Fallback to foods if editableMealItems is empty
        if editableMealItems.isEmpty {
            for food in foods {
                cals += food.calories ?? 0
                protein += food.protein ?? 0
                carbs += food.carbs ?? 0
                fat += food.fat ?? 0
            }
        }

        return (cals, protein, carbs, fat)
    }

    // Aggregated nutrients from all foods
    private var aggregatedNutrients: [String: (value: Double, unit: String)] {
        var result: [String: (value: Double, unit: String)] = [:]

        for food in foods {
            for nutrient in food.foodNutrients {
                let key = normalizedNutrientKey(nutrient.nutrientName)
                let value = nutrient.value ?? 0
                let unit = nutrient.unitName ?? ""
                if let existing = result[key] {
                    result[key] = (value: existing.value + value, unit: unit)
                } else {
                    result[key] = (value: value, unit: unit)
                }
            }
        }

        return result
    }

    private func normalizedNutrientKey(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Fiber value for net carbs calculation
    private var fiberValue: Double {
        let fiberKeys = ["fiber, total dietary", "dietary fiber"]
        for key in fiberKeys {
            if let match = aggregatedNutrients[normalizedNutrientKey(key)] {
                return match.value
            }
        }
        return 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ingredientItemsSection
                        macroSummaryCard

                        // Nutrient Sections
                        totalCarbsSection
                        fatTotalsSection
                        proteinTotalsSection
                        vitaminSection
                        mineralSection
                        otherNutrientSection

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }

                footerBar
            }
            .background(plateBackground.ignoresSafeArea())
            .navigationTitle("Add Ingredients")
            .navigationBarTitleDisplayMode(.inline)
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
                initializeEditableItems()
                nutrientTargets = goalsStore.currentTargets
            }
        }
    }

    private func initializeEditableItems() {
        if editableMealItems.isEmpty {
            editableMealItems = mealItems
        }
    }

    private func deleteMealItem(_ item: MealItem) {
        editableMealItems.removeAll { $0.id == item.id }
    }

    // MARK: - Ingredient Items Section

    private var ingredientItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if editableMealItems.isEmpty && foods.isEmpty {
                Text("No ingredients detected")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    // Show meal items
                    ForEach(editableMealItems) { item in
                        IngredientItemRow(item: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteMealItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }

                        if item.id != editableMealItems.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    // Show foods if no meal items
                    if editableMealItems.isEmpty {
                        ForEach(foods, id: \.fdcId) { food in
                            IngredientFoodRow(food: food)

                            if food.fdcId != foods.last?.fdcId {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardColor)
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Macro Summary Card

    private var macroSummaryCard: some View {
        VStack(spacing: 16) {
            // Calories
            Text("\(Int(totalMacros.calories.rounded()))")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)
            Text("total calories")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Macro breakdown
            HStack(spacing: 24) {
                macroItem(label: "Protein", value: Int(totalMacros.protein.rounded()), color: Color("protein"))
                macroItem(label: "Carbs", value: Int(totalMacros.carbs.rounded()), color: Color("carbs"))
                macroItem(label: "Fat", value: Int(totalMacros.fat.rounded()), color: Color("fat"))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    private func macroItem(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text("\(value)g")
                    .font(.system(size: 17, weight: .semibold))
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            Button(action: {
                HapticFeedback.generateLigth()
                isAdding = true
                onAddToRecipe(foods, editableMealItems)
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
            .disabled(isAdding || (editableMealItems.isEmpty && foods.isEmpty))
            .opacity(isAdding ? 0.7 : 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Nutrient Sections

    private var totalCarbsSection: some View {
        nutrientSection(title: "Total Carbs", descriptors: carbDescriptors)
    }

    private var fatTotalsSection: some View {
        nutrientSection(title: "Total Fat", descriptors: fatDescriptors)
    }

    private var proteinTotalsSection: some View {
        nutrientSection(title: "Total Protein", descriptors: proteinDescriptors)
    }

    private var vitaminSection: some View {
        nutrientSection(title: "Vitamins", descriptors: vitaminDescriptors)
    }

    private var mineralSection: some View {
        nutrientSection(title: "Minerals", descriptors: mineralDescriptors)
    }

    private var otherNutrientSection: some View {
        nutrientSection(title: "Other", descriptors: otherDescriptors)
    }

    @ViewBuilder
    private func nutrientSection(title: String, descriptors: [PlateNutrientRowDescriptor]) -> some View {
        let hasData = descriptors.contains { nutrientValue(for: $0) > 0 }
        if hasData {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    ForEach(descriptors) { descriptor in
                        nutrientRow(for: descriptor)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardColor)
                )
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func nutrientRow(for descriptor: PlateNutrientRowDescriptor) -> some View {
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

    // MARK: - Nutrient Value Helpers

    private func nutrientValue(for descriptor: PlateNutrientRowDescriptor) -> Double {
        switch descriptor.source {
        case .macro(let extractor):
            return extractor(totalMacros.calories, totalMacros.protein, totalMacros.carbs, totalMacros.fat)
        case .netCarbs:
            return max(0, totalMacros.carbs - fiberValue)
        case .nutrient(let keys):
            for key in keys {
                if let match = aggregatedNutrients[normalizedNutrientKey(key)] {
                    return match.value
                }
            }
            return 0
        }
    }

    private func nutrientUnit(for descriptor: PlateNutrientRowDescriptor) -> String {
        switch descriptor.source {
        case .macro, .netCarbs:
            return "g"
        case .nutrient(let keys):
            for key in keys {
                if let match = aggregatedNutrients[normalizedNutrientKey(key)] {
                    return match.unit.lowercased()
                }
            }
            return descriptor.defaultUnit
        }
    }

    // MARK: - Goal Helpers

    private func nutrientGoal(for descriptor: PlateNutrientRowDescriptor) -> Double? {
        // Check macro goals first
        switch descriptor.label.lowercased() {
        case "protein":
            return dayLogsVM.proteinGoal > 0 ? dayLogsVM.proteinGoal : nil
        case "carbohydrates", "carbs", "net carbs":
            return dayLogsVM.carbsGoal > 0 ? dayLogsVM.carbsGoal : nil
        case "fat":
            return dayLogsVM.fatGoal > 0 ? dayLogsVM.fatGoal : nil
        default:
            break
        }

        // Check nutrient targets by slug
        guard let slug = descriptor.slug,
              let target = nutrientTargets[slug],
              let targetValue = target.target,
              let targetUnit = target.unit else {
            return nil
        }

        let unit = nutrientUnit(for: descriptor)
        return convertGoal(targetValue, fromUnit: targetUnit, toUnit: unit)
    }

    private func nutrientPercentage(value: Double, goal: Double?) -> String {
        guard let goal = goal, goal > 0 else { return "" }
        let pct = (value / goal) * 100
        return "\(Int(pct.rounded()))%"
    }

    private func nutrientProgressValue(value: Double, goal: Double?) -> Double {
        guard let goal = goal, goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }

    private func nutrientRatioText(value: Double, goal: Double?, unit: String) -> String {
        let valueStr = value < 1 && value > 0 ? String(format: "%.1f", value) : "\(Int(value.rounded()))"
        if let goal = goal, goal > 0 {
            let goalStr = goal < 1 && goal > 0 ? String(format: "%.1f", goal) : "\(Int(goal.rounded()))"
            return "\(valueStr) / \(goalStr) \(unit)"
        }
        return "\(valueStr) \(unit)"
    }

    private func convertGoal(_ value: Double, fromUnit: String, toUnit: String) -> Double {
        let from = fromUnit.lowercased()
        let to = toUnit.lowercased()
        if from == to { return value }
        if from == "mg" && to == "g" { return value / 1000 }
        if from == "g" && to == "mg" { return value * 1000 }
        if from == "mcg" && to == "mg" { return value / 1000 }
        if from == "mg" && to == "mcg" { return value * 1000 }
        if from == "mcg" && to == "g" { return value / 1_000_000 }
        if from == "g" && to == "mcg" { return value * 1_000_000 }
        return value
    }

    // MARK: - Nutrient Descriptors

    private var carbDescriptors: [PlateNutrientRowDescriptor] {
        [
            PlateNutrientRowDescriptor(label: "Net Carbs", slug: "net_carbs", defaultUnit: "g", source: .netCarbs, color: Color("carbs")),
            PlateNutrientRowDescriptor(label: "Fiber", slug: "fiber", defaultUnit: "g", source: .nutrient(["fiber, total dietary", "dietary fiber"]), color: .orange),
            PlateNutrientRowDescriptor(label: "Sugar", slug: "sugar", defaultUnit: "g", source: .nutrient(["sugars, total including nlea", "total sugars"]), color: .pink)
        ]
    }

    private var fatDescriptors: [PlateNutrientRowDescriptor] {
        [
            PlateNutrientRowDescriptor(label: "Saturated Fat", slug: "saturated_fat", defaultUnit: "g", source: .nutrient(["fatty acids, total saturated"]), color: .red),
            PlateNutrientRowDescriptor(label: "Polyunsaturated Fat", slug: "polyunsaturated_fat", defaultUnit: "g", source: .nutrient(["fatty acids, total polyunsaturated"]), color: .blue),
            PlateNutrientRowDescriptor(label: "Monounsaturated Fat", slug: "monounsaturated_fat", defaultUnit: "g", source: .nutrient(["fatty acids, total monounsaturated"]), color: .green),
            PlateNutrientRowDescriptor(label: "Trans Fat", slug: "trans_fat", defaultUnit: "g", source: .nutrient(["fatty acids, total trans"]), color: .gray),
            PlateNutrientRowDescriptor(label: "Cholesterol", slug: "cholesterol", defaultUnit: "mg", source: .nutrient(["cholesterol"]), color: .purple)
        ]
    }

    private var proteinDescriptors: [PlateNutrientRowDescriptor] {
        [
            PlateNutrientRowDescriptor(label: "Protein", slug: "protein", defaultUnit: "g", source: .macro({ _, protein, _, _ in protein }), color: Color("protein"))
        ]
    }

    private var vitaminDescriptors: [PlateNutrientRowDescriptor] {
        [
            PlateNutrientRowDescriptor(label: "Vitamin A", slug: "vitamin_a", defaultUnit: "mcg", source: .nutrient(["vitamin a, rae"]), color: .orange),
            PlateNutrientRowDescriptor(label: "Vitamin C", slug: "vitamin_c", defaultUnit: "mg", source: .nutrient(["vitamin c, total ascorbic acid"]), color: .yellow),
            PlateNutrientRowDescriptor(label: "Vitamin D", slug: "vitamin_d", defaultUnit: "mcg", source: .nutrient(["vitamin d (d2 + d3)"]), color: .cyan),
            PlateNutrientRowDescriptor(label: "Vitamin E", slug: "vitamin_e", defaultUnit: "mg", source: .nutrient(["vitamin e (alpha-tocopherol)"]), color: .green),
            PlateNutrientRowDescriptor(label: "Vitamin K", slug: "vitamin_k", defaultUnit: "mcg", source: .nutrient(["vitamin k (phylloquinone)"]), color: .mint),
            PlateNutrientRowDescriptor(label: "Thiamin (B1)", slug: "thiamin", defaultUnit: "mg", source: .nutrient(["thiamin"]), color: .brown),
            PlateNutrientRowDescriptor(label: "Riboflavin (B2)", slug: "riboflavin", defaultUnit: "mg", source: .nutrient(["riboflavin"]), color: .indigo),
            PlateNutrientRowDescriptor(label: "Niacin (B3)", slug: "niacin", defaultUnit: "mg", source: .nutrient(["niacin"]), color: .teal),
            PlateNutrientRowDescriptor(label: "Vitamin B6", slug: "vitamin_b6", defaultUnit: "mg", source: .nutrient(["vitamin b-6"]), color: .purple),
            PlateNutrientRowDescriptor(label: "Folate", slug: "folate", defaultUnit: "mcg", source: .nutrient(["folate, total"]), color: .pink),
            PlateNutrientRowDescriptor(label: "Vitamin B12", slug: "vitamin_b12", defaultUnit: "mcg", source: .nutrient(["vitamin b-12"]), color: .red)
        ]
    }

    private var mineralDescriptors: [PlateNutrientRowDescriptor] {
        [
            PlateNutrientRowDescriptor(label: "Calcium", slug: "calcium", defaultUnit: "mg", source: .nutrient(["calcium, ca"]), color: .white),
            PlateNutrientRowDescriptor(label: "Iron", slug: "iron", defaultUnit: "mg", source: .nutrient(["iron, fe"]), color: .red),
            PlateNutrientRowDescriptor(label: "Magnesium", slug: "magnesium", defaultUnit: "mg", source: .nutrient(["magnesium, mg"]), color: .green),
            PlateNutrientRowDescriptor(label: "Phosphorus", slug: "phosphorus", defaultUnit: "mg", source: .nutrient(["phosphorus, p"]), color: .orange),
            PlateNutrientRowDescriptor(label: "Potassium", slug: "potassium", defaultUnit: "mg", source: .nutrient(["potassium, k"]), color: .purple),
            PlateNutrientRowDescriptor(label: "Zinc", slug: "zinc", defaultUnit: "mg", source: .nutrient(["zinc, zn"]), color: .gray),
            PlateNutrientRowDescriptor(label: "Copper", slug: "copper", defaultUnit: "mg", source: .nutrient(["copper, cu"]), color: .brown),
            PlateNutrientRowDescriptor(label: "Manganese", slug: "manganese", defaultUnit: "mg", source: .nutrient(["manganese, mn"]), color: .cyan),
            PlateNutrientRowDescriptor(label: "Selenium", slug: "selenium", defaultUnit: "mcg", source: .nutrient(["selenium, se"]), color: .yellow)
        ]
    }

    private var otherDescriptors: [PlateNutrientRowDescriptor] {
        [
            PlateNutrientRowDescriptor(label: "Sodium", slug: "sodium", defaultUnit: "mg", source: .nutrient(["sodium, na"]), color: .blue),
            PlateNutrientRowDescriptor(label: "Caffeine", slug: "caffeine", defaultUnit: "mg", source: .nutrient(["caffeine"]), color: .brown)
        ]
    }
}

// MARK: - Plate Nutrient Descriptor Types

private struct PlateNutrientRowDescriptor: Identifiable {
    let id = UUID()
    let label: String
    let slug: String?
    let defaultUnit: String
    let source: PlateNutrientSource
    let color: Color
}

private enum PlateNutrientSource {
    case macro((_ calories: Double, _ protein: Double, _ carbs: Double, _ fat: Double) -> Double)
    case netCarbs
    case nutrient([String])
}

// MARK: - Ingredient Item Row (for MealItem)

struct IngredientItemRow: View {
    let item: MealItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("\(Int(item.calories.rounded())) cal")
                    }

                    macroLabel(prefix: "P", value: Int(item.protein.rounded()))
                    macroLabel(prefix: "F", value: Int(item.fat.rounded()))
                    macroLabel(prefix: "C", value: Int(item.carbs.rounded()))
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }
}

// MARK: - Ingredient Food Row (for Food)

struct IngredientFoodRow: View {
    let food: Food

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.description)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("\(Int((food.calories ?? 0).rounded())) cal")
                    }

                    macroLabel(prefix: "P", value: Int((food.protein ?? 0).rounded()))
                    macroLabel(prefix: "F", value: Int((food.fat ?? 0).rounded()))
                    macroLabel(prefix: "C", value: Int((food.carbs ?? 0).rounded()))
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }
}

#Preview {
    IngredientPlateSummaryView(
        foods: [],
        mealItems: [],
        onAddToRecipe: { _, _ in }
    )
}
