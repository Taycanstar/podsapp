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
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel

    @State private var selectedMeal: MealPeriod = .lunch
    @State private var mealTime: Date = Date()
    @State private var isLogging = false

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                mealHeader
                List(displayFoods) { food in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.displayName)
                            .font(.headline)
                        if let brand = food.brandText, !brand.isEmpty {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 12) {
                            if let calories = food.calories {
                                Label("\(Int(calories)) cal", systemImage: "flame.fill")
                                    .font(.caption)
                            }
                            if let protein = food.protein {
                                Text("\(Int(protein))g protein")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let carbs = food.carbs {
                                Text("\(Int(carbs))g carbs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let fat = food.fat {
                                Text("\(Int(fat))g fat")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.plain)

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
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
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

    private var mealHeader: some View {
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
                .padding(.vertical, 8)
                .background(Capsule().fill(Color(.secondarySystemFill)))
            }

            DatePicker("", selection: $mealTime, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
        }
        .padding(.horizontal)
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
