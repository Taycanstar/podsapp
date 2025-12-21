//
//  IngredientSummaryView.swift
//  pods
//
//  Created by Dimi Nunez on 12/20/25.
//

import SwiftUI

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

    let food: Food
    var onAddToRecipe: (Food) -> Void

    @State private var numberOfServings: Double = 1
    @State private var servingsInput: String = "1"
    @State private var servingAmountInput: String = "1"
    @State private var servingAmount: Double = 1
    @State private var selectedMeasure: FoodMeasure?
    @State private var isAdding = false
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

    // Gram weight for selected measure
    private var selectedGramWeight: Double {
        selectedMeasure?.gramWeight ?? food.servingSize ?? 100
    }

    // Base nutrient values per 100g
    private var baseCaloriesPer100g: Double {
        (food.calories ?? 0) / (food.servingSize ?? 100) * 100
    }

    private var baseProteinPer100g: Double {
        (food.protein ?? 0) / (food.servingSize ?? 100) * 100
    }

    private var baseCarbsPer100g: Double {
        (food.carbs ?? 0) / (food.servingSize ?? 100) * 100
    }

    private var baseFatPer100g: Double {
        (food.fat ?? 0) / (food.servingSize ?? 100) * 100
    }

    // Adjusted values based on serving amount and selected measure
    private var adjustedCalories: Double {
        (baseCaloriesPer100g / 100) * selectedGramWeight * servingAmount * numberOfServings
    }

    private var adjustedProtein: Double {
        (baseProteinPer100g / 100) * selectedGramWeight * servingAmount * numberOfServings
    }

    private var adjustedCarbs: Double {
        (baseCarbsPer100g / 100) * selectedGramWeight * servingAmount * numberOfServings
    }

    private var adjustedFat: Double {
        (baseFatPer100g / 100) * selectedGramWeight * servingAmount * numberOfServings
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        macroSummaryCard
                        portionDetailsCard
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

// MARK: - Double Extension for Clean Display

private extension Double {
    var cleanOneDecimal: String {
        if abs(self.rounded() - self) < 0.01 {
            return String(Int(self.rounded()))
        }
        return String(format: "%.1f", self)
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
