//
//  FoodDetails.swift
//  pods
//
//  Created by Dimi Nunez on 12/22/25.
//

import SwiftUI

struct FoodDetails: View {
    let food: Food

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel
    @EnvironmentObject private var foodManager: FoodManager
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared

    @State private var nutrientTargets: [String: NutrientTargetDetails] = NutritionGoalsStore.shared.currentTargets
    @State private var displayFood: Food?
    @State private var isLoadingNutrients = false

    /// The food to display - uses fetched full nutrients if available, otherwise the original
    private var activeFood: Food {
        displayFood ?? food
    }

    /// Threshold for considering nutrients as "full" (more than basic macros)
    private var hasFullNutrients: Bool {
        activeFood.foodNutrients.count > 10
    }

    // MARK: - Colors
    private let proteinColor = Color("protein")
    private let fatColor = Color("fat")
    private let carbColor = Color("carbs")

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("bg") : Color(UIColor.systemGroupedBackground)
    }

    private var cardColor: Color {
        colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color("bg")
    }

    private var chipColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }

    // MARK: - Computed Nutrition Values
    private var calories: Double {
        activeFood.calories ?? 0
    }

    private var protein: Double {
        activeFood.protein ?? 0
    }

    private var carbs: Double {
        activeFood.carbs ?? 0
    }

    private var fat: Double {
        activeFood.fat ?? 0
    }

    private var fiber: Double {
        nutrientValue(for: ["Fiber, total dietary", "fiber, total dietary", "dietary fiber", "fiber"])
    }

    // MARK: - Nutrient Lookup
    private var nutrientValues: [String: RawNutrientValue] {
        var result: [String: RawNutrientValue] = [:]
        for nutrient in activeFood.foodNutrients {
            let key = normalizedNutrientKey(nutrient.nutrientName)
            result[key] = RawNutrientValue(value: nutrient.value ?? 0, unit: nutrient.unitName)
        }
        return result
    }

    private func nutrientValue(for names: [String]) -> Double {
        for name in names {
            if let val = nutrientValues[normalizedNutrientKey(name)]?.value, val > 0 {
                return val
            }
        }
        return 0
    }

    // MARK: - Macro Arcs
    private var macroArcs: [FoodDetailMacroArc] {
        let proteinCalories = protein * 4
        let carbCalories = carbs * 4
        let fatCalories = fat * 9
        let total = max(proteinCalories + carbCalories + fatCalories, 1)
        let segments = [
            (color: proteinColor, fraction: proteinCalories / total),
            (color: fatColor, fraction: fatCalories / total),
            (color: carbColor, fraction: carbCalories / total)
        ]
        var running: Double = 0
        return segments.map { segment in
            let arc = FoodDetailMacroArc(start: running, end: running + segment.fraction, color: segment.color)
            running += segment.fraction
            return arc
        }
    }

    // MARK: - Goal Percentages
    private var proteinGoalPercent: Double {
        guard dayLogsVM.proteinGoal > 0 else { return 0 }
        return (protein / dayLogsVM.proteinGoal) * 100
    }

    private var fatGoalPercent: Double {
        guard dayLogsVM.fatGoal > 0 else { return 0 }
        return (fat / dayLogsVM.fatGoal) * 100
    }

    private var carbGoalPercent: Double {
        guard dayLogsVM.carbsGoal > 0 else { return 0 }
        return (carbs / dayLogsVM.carbsGoal) * 100
    }

    private var shouldShowGoalsLoader: Bool {
        if case .loading = goalsStore.state { return true }
        return false
    }

    // MARK: - Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                foodInfoCard
                macroSummaryCard
                dailyGoalShareCard

                if isLoadingNutrients {
                    nutrientsLoadingView
                } else if shouldShowGoalsLoader {
                    goalsLoadingView
                } else if nutrientTargets.isEmpty {
                    missingTargetsCallout
                } else {
                    totalCarbsSection
                    fatTotalsSection
                    proteinTotalsSection
                    vitaminSection
                    mineralSection
                    otherNutrientSection
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Food Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            reloadStoredNutrientTargets()
            await loadFullNutrientsIfNeeded()
        }
        .onReceive(dayLogsVM.$nutritionGoalsVersion) { _ in
            reloadStoredNutrientTargets()
        }
        .onReceive(goalsStore.$state) { _ in
            reloadStoredNutrientTargets()
        }
    }

    // MARK: - Nutrients Loading View
    private var nutrientsLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading nutrition data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Load Full Nutrients
    private func loadFullNutrientsIfNeeded() async {
        // Skip if already has full nutrients
        guard food.foodNutrients.count <= 10 else { return }

        // Need user email for API call
        guard let email = foodManager.userEmail else { return }

        isLoadingNutrients = true
        defer { isLoadingNutrients = false }

        do {
            // Try to fetch full nutrients using the food name
            let fullResult = try await FoodService.shared.fullFoodLookup(
                nixItemId: nil,
                foodName: food.description,
                userEmail: email
            )
            displayFood = fullResult.toFood()
        } catch {
            print("[FoodDetails] Failed to load full nutrients: \(error)")
            // Keep using the original food with limited nutrients
        }
    }

    private func reloadStoredNutrientTargets() {
        nutrientTargets = NutritionGoalsStore.shared.currentTargets
    }

    // MARK: - Food Info Card (Name + Serving Size)
    private var foodInfoCard: some View {
        VStack(spacing: 0) {
            // Row 1: Name
            HStack {
                Text("Name")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                Spacer()
                Text(activeFood.displayName)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .padding(.vertical, 12)

            Divider()

            // Row 2: Serving Size
            HStack {
                Text("Serving Size")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                Spacer()
                Text(servingDescription)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(chipColor))
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    // MARK: - Macro Summary Card
    private var macroSummaryCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                macroStatRow(title: "Protein", value: protein, unit: "g", color: proteinColor)
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Fat", value: fat, unit: "g", color: fatColor)
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Carbs", value: carbs, unit: "g", color: carbColor)
            }

            Spacer()

            FoodDetailMacroRingView(calories: calories, arcs: macroArcs)
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
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(value.foodDetailFormatted)\(unit)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private var servingDescription: String {
        if let household = activeFood.householdServingFullText, !household.isEmpty {
            return household
        }
        if let size = activeFood.servingSize, let unit = activeFood.servingSizeUnit {
            let formattedSize = size == floor(size) ? String(Int(size)) : String(format: "%.1f", size)
            return "\(formattedSize) \(unit)"
        }
        return "1 serving"
    }

    // MARK: - Daily Goal Share Card
    private var dailyGoalShareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Goal Share")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                FoodDetailGoalShareBubble(title: "Protein",
                                          percent: proteinGoalPercent,
                                          grams: protein,
                                          goal: dayLogsVM.proteinGoal,
                                          color: proteinColor)
                FoodDetailGoalShareBubble(title: "Fat",
                                          percent: fatGoalPercent,
                                          grams: fat,
                                          goal: dayLogsVM.fatGoal,
                                          color: fatColor)
                FoodDetailGoalShareBubble(title: "Carbs",
                                          percent: carbGoalPercent,
                                          grams: carbs,
                                          goal: dayLogsVM.carbsGoal,
                                          color: carbColor)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(cardColor)
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Nutrient Sections
    private var totalCarbsSection: some View {
        nutrientSection(title: "Total Carbs", rows: NutrientDescriptors.totalCarbRows)
    }

    private var fatTotalsSection: some View {
        nutrientSection(title: "Total Fat", rows: NutrientDescriptors.fatRows)
    }

    private var proteinTotalsSection: some View {
        nutrientSection(title: "Total Protein", rows: NutrientDescriptors.proteinRows)
    }

    private var vitaminSection: some View {
        nutrientSection(title: "Vitamins", rows: NutrientDescriptors.vitaminRows)
    }

    private var mineralSection: some View {
        nutrientSection(title: "Minerals", rows: NutrientDescriptors.mineralRows)
    }

    private var otherNutrientSection: some View {
        nutrientSection(title: "Other", rows: NutrientDescriptors.otherRows)
    }

    private func nutrientSection(title: String, rows: [NutrientRowDescriptor]) -> some View {
        let filteredRows = rows.filter { descriptor in
            switch descriptor.source {
            case .macro, .computed:
                return true
            case .nutrient(let names, _):
                return names.contains { name in
                    nutrientValues[normalizedNutrientKey(name)] != nil
                }
            }
        }

        return Group {
            if !filteredRows.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)

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
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func nutrientRow(for descriptor: NutrientRowDescriptor) -> some View {
        let value = nutrientValueFor(descriptor)
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
    private func nutrientValueFor(_ descriptor: NutrientRowDescriptor) -> Double {
        switch descriptor.source {
        case .macro(let macro):
            switch macro {
            case .protein: return protein
            case .carbs: return carbs
            case .fat: return fat
            }
        case .nutrient(let names, let aggregation):
            let matches = names.compactMap { nutrientValues[normalizedNutrientKey($0)] }
            guard !matches.isEmpty else { return 0 }
            switch aggregation {
            case .first:
                return matches.first?.value ?? 0
            case .sum:
                return matches.reduce(0) { $0 + $1.value }
            }
        case .computed(let computation):
            switch computation {
            case .netCarbs:
                return max(carbs - fiber, 0)
            case .calories:
                return calories
            }
        }
    }

    private func nutrientGoal(for descriptor: NutrientRowDescriptor) -> Double? {
        if let slug = descriptor.slug,
           let details = nutrientTargets[slug] {
            if let target = details.target, target > 0 {
                return target
            } else if let max = details.max, max > 0 {
                return max
            } else if let idealMax = details.idealMax, idealMax > 0 {
                return idealMax
            }
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
                    return target
                }
                return nil
            }
        default:
            return nil
        }
    }

    private func nutrientUnit(for descriptor: NutrientRowDescriptor) -> String {
        switch descriptor.source {
        case .nutrient(let names, _):
            for name in names {
                if let raw = nutrientValues[normalizedNutrientKey(name)],
                   let unit = raw.unit, !unit.isEmpty {
                    return unit
                }
            }
        default:
            break
        }
        return descriptor.defaultUnit
    }

    private func nutrientPercentage(value: Double, goal: Double?) -> String {
        guard let goal, goal > 0 else { return "--" }
        let percent = (value / goal) * 100
        return "\(Int(percent.rounded()))%"
    }

    private func nutrientRatioText(value: Double, goal: Double?, unit: String) -> String {
        let valueText = value.foodDetailGoalShareFormatted
        let goalText = goal.map { $0.foodDetailGoalShareFormatted } ?? "--"
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUnit.isEmpty {
            return "\(valueText)/\(goalText)"
        } else {
            return "\(valueText)/\(goalText) \(trimmedUnit)"
        }
    }

    private func nutrientProgressValue(value: Double, goal: Double?) -> Double {
        guard let goal, goal > 0 else { return 0 }
        return min(max(value / goal, 0), 1)
    }

    // MARK: - Loading/Missing Views
    private var goalsLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView("Syncing your targets...")
                .progressViewStyle(CircularProgressViewStyle())
            Text("Hang tight while we fetch your personalized nutrient plan.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    private var missingTargetsCallout: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finish goal setup to unlock detailed targets")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("We'll automatically sync your nutrition plan and show daily percentages once it's ready.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button(action: {
                dayLogsVM.refreshNutritionGoals(forceRefresh: true)
            }) {
                HStack {
                    if dayLogsVM.isRefreshingNutritionGoals {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                    Text(dayLogsVM.isRefreshingNutritionGoals ? "Syncing Targets" : "Sync Now")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(dayLogsVM.isRefreshingNutritionGoals ? 0.4 : 0.15))
                .foregroundColor(.accentColor)
                .cornerRadius(12)
            }
            .disabled(dayLogsVM.isRefreshingNutritionGoals)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }
}

// MARK: - Supporting Views

private struct FoodDetailGoalShareBubble: View {
    let title: String
    let percent: Double
    let grams: Double
    let goal: Double
    let color: Color

    private var progress: Double {
        min(max(percent / 100, 0), 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(percent.rounded()))%")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(width: 76, height: 76)
            Text("\(grams.foodDetailGoalShareFormatted) / \(goal.foodDetailGoalShareFormatted)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FoodDetailMacroRingView: View {
    let calories: Double
    let arcs: [FoodDetailMacroArc]

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

private struct FoodDetailMacroArc {
    let start: Double
    let end: Double
    let color: Color
}

// MARK: - Double Extensions for FoodDetails

private extension Double {
    var foodDetailFormatted: String {
        if self.isNaN { return "0" }
        if abs(self - rounded()) < 0.01 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }

    var foodDetailGoalShareFormatted: String {
        if self.isNaN || self.isInfinite { return "0" }
        let roundedValue = (self * 10).rounded() / 10
        if roundedValue.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(roundedValue))
        }
        return String(format: "%.1f", roundedValue)
    }
}
