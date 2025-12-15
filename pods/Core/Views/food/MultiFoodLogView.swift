//
//  MultiFoodLogView.swift
//  pods
//
//  Created by Codex on 12/14/25.
//

import SwiftUI

struct MultiFoodLogView: View {
    let foods: [Food]
    let mealItems: [MealItem]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel

    @State private var selectedMeal: MealPeriod = .lunch
    @State private var mealTime: Date = Date()
    @State private var isLogging = false

    private var plateBackground: Color {
        colorScheme == .dark ? Color("bg") : Color(UIColor.systemGroupedBackground)
    }
    private var cardColor: Color {
        colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color("bg")
    }
    private var chipColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }

    private var displayFoods: [Food] {
        if foods.count > 1 {
            return foods
        }
        if let first = foods.first, let items = first.mealItems, !items.isEmpty {
            return items.map { item in
                Food(
                    fdcId: item.id.hashValue,
                    description: item.name,
                    brandOwner: nil,
                    brandName: nil,
                    servingSize: item.serving,
                    numberOfServings: 1,
                    servingSizeUnit: item.servingUnit,
                    householdServingFullText: item.originalServing?.resolvedText ?? "\(Int(item.serving)) \(item.servingUnit ?? "serving")",
                    foodNutrients: [
                        Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                        Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                        Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                        Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
                    ],
                    foodMeasures: [],
                    healthAnalysis: nil,
                    aiInsight: nil,
                    nutritionScore: nil,
                    mealItems: item.subitems
                )
            }
        }
        // Convert meal items to lightweight Food objects for display/logging
        return mealItems.map { item in
            Food(
                fdcId: item.id.hashValue,
                description: item.name,
                brandOwner: nil,
                brandName: nil,
                servingSize: item.serving,
                numberOfServings: 1,
                servingSizeUnit: item.servingUnit,
                householdServingFullText: item.originalServing?.resolvedText ?? "\(Int(item.serving)) \(item.servingUnit ?? "serving")",
                foodNutrients: [
                    Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                    Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                    Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                    Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
                ],
                foodMeasures: [],
                healthAnalysis: nil,
                aiInsight: nil,
                nutritionScore: nil,
                mealItems: []
            )
        }
    }

    private var displayItems: [MultiMealItemDisplay] {
        displayFoods.map { food in
            MultiMealItemDisplay(
                id: "\(food.fdcId ?? food.hashValue)",
                name: food.displayName,
                brand: food.brandText,
                servingText: food.householdServingFullText ?? food.servingSizeText ?? food.servingSizeUnit,
                calories: food.calories ?? 0,
                protein: food.protein ?? 0,
                carbs: food.carbs ?? 0,
                fat: food.fat ?? 0
            )
        }
    }

    private var totalMacros: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        displayItems.reduce((0, 0, 0, 0)) { acc, item in
            (acc.0 + item.calories, acc.1 + item.protein, acc.2 + item.carbs, acc.3 + item.fat)
        }
    }

    private var macroArcs: [MacroArc] {
        let proteinCalories = totalMacros.protein * 4
        let carbCalories = totalMacros.carbs * 4
        let fatCalories = totalMacros.fat * 9
        let total = max(proteinCalories + carbCalories + fatCalories, 1)
        let segments = [
            (Color("protein"), proteinCalories / total),
            (Color("fat"), fatCalories / total),
            (Color("carbs"), carbCalories / total)
        ]
        var start: Double = 0
        return segments.map { seg in
            let arc = MacroArc(start: start, end: start + seg.1, color: seg.0)
            start += seg.1
            return arc
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        mealItemsSection
                        macroSummaryCard
                        mealTimeSelector
                        macroChipsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }

                footerBar
            }
            .background(plateBackground.ignoresSafeArea())
            .navigationTitle("Review Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
    }

    private var mealItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Items")
                .font(.title3)
                .fontWeight(.semibold)
            VStack(spacing: 12) {
                ForEach(displayItems) { item in
                    MultiMealItemRow(item: item, cardColor: cardColor, chipColor: chipColor)
                }
            }
        }
    }

    private var macroSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Summary")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            HStack(alignment: .center, spacing: 16) {
                MacroRingView(calories: totalMacros.calories, arcs: macroArcs)
                    .frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 8) {
                    macroLine(label: "Calories", value: totalMacros.calories, unit: "kcal")
                    macroLine(label: "Protein", value: totalMacros.protein, unit: "g", color: Color("protein"))
                    macroLine(label: "Carbs", value: totalMacros.carbs, unit: "g", color: Color("carbs"))
                    macroLine(label: "Fat", value: totalMacros.fat, unit: "g", color: Color("fat"))
                }
                Spacer()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 18).fill(cardColor))
        }
    }

    private func macroLine(label: String, value: Double, unit: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(Int(value.rounded())) \(unit)")
                .font(.subheadline)
                .foregroundColor(color)
        }
    }

    private var macroChipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macros")
                .font(.title3)
                .fontWeight(.semibold)
            HStack(spacing: 12) {
                macroChip(title: "Protein", value: totalMacros.protein, unit: "g", color: Color("protein"))
                macroChip(title: "Carbs", value: totalMacros.carbs, unit: "g", color: Color("carbs"))
                macroChip(title: "Fat", value: totalMacros.fat, unit: "g", color: Color("fat"))
            }
        }
    }

    private func macroChip(title: String, value: Double, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Text("\(Int(value.rounded()))")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardColor))
    }

    private var mealTimeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal & Time")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                Menu {
                    ForEach(MealPeriod.allCases) { period in
                        Button(period.title) { selectedMeal = period }
                    }
                } label: {
                    HStack {
                        Text(selectedMeal.title)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(chipColor))
                }

                DatePicker("", selection: $mealTime, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 18).fill(cardColor))
        }
    }

    private var footerBar: some View {
        VStack(spacing: 12) {
            Divider().padding(.horizontal, -16)
            HStack(spacing: 12) {
                Button(action: logAllFoods) {
                    Text(isLogging ? "Logging..." : "Log Meal")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                        .foregroundColor(.white)
                }
                .disabled(isLogging || displayFoods.isEmpty)
                .opacity(isLogging || displayFoods.isEmpty ? 0.6 : 1)

                Button(action: { dismiss() }) {
                    Text("Add to Plate")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.accentColor, lineWidth: 1.5)
                        )
                        .foregroundColor(Color.accentColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .background(plateBackground.ignoresSafeArea(edges: .bottom))
    }

    private func logAllFoods() {
        guard !displayFoods.isEmpty else { return }
        isLogging = true
        logFood(at: 0)
    }

    private func logFood(at index: Int) {
        if index >= displayFoods.count {
            isLogging = false
            dayLogsVM.loadLogs(for: mealTime, force: true)
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToTimeline"), object: nil)
            dismiss()
            return
        }

        let food = displayFoods[index]
        foodManager.logFood(
            email: onboardingViewModel.email,
            food: food,
            meal: selectedMeal.title,
            servings: food.numberOfServings ?? 1,
            date: mealTime,
            notes: nil
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let logged):
                    let combined = CombinedLog(
                        type: .food,
                        status: logged.status,
                        calories: Double(logged.food.calories),
                        message: "\(logged.food.displayName) - \(logged.mealType)",
                        foodLogId: logged.foodLogId,
                        food: logged.food,
                        mealType: logged.mealType,
                        mealLogId: nil,
                        meal: nil,
                        mealTime: logged.mealType,
                        scheduledAt: mealTime,
                        recipeLogId: nil,
                        recipe: nil,
                        servingsConsumed: nil
                    )
                    self.dayLogsVM.addPending(combined)
                case .failure:
                    break
                }
                self.logFood(at: index + 1)
            }
        }
    }
}

// MARK: - Supporting UI

private struct MultiMealItemDisplay: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let servingText: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

private struct MultiMealItemRow: View {
    let item: MultiMealItemDisplay
    let cardColor: Color
    let chipColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name.isEmpty ? "Meal Item" : item.name)
                        .font(.system(size: 15))
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    if let brand = item.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 12)

                if let serving = item.servingText, !serving.isEmpty {
                    Text(serving)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(chipColor)
                        )
                        .fixedSize()
                }
            }

            HStack(spacing: 10) {
                Label("\(Int(item.calories.rounded()))cal", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(macroLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardColor)
        )
    }

    private var macroLine: String {
        let protein = Int(item.protein.rounded())
        let carbs = Int(item.carbs.rounded())
        let fat = Int(item.fat.rounded())
        return "P \(protein)g C \(carbs)g F \(fat)g"
    }
}

private struct MacroRingView: View {
    let calories: Double
    let arcs: [MacroArc]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 8)

            ForEach(arcs.indices, id: \.self) { idx in
                let arc = arcs[idx]
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

private struct MacroArc {
    let start: Double
    let end: Double
    let color: Color
}
