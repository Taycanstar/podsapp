//
//  MealPlateSummaryView.swift
//  pods
//
//  Created by Dimi Nunez on 12/10/25.
//


import SwiftUI

struct MealPlateSummaryView: View {
    let foods: [Food]
    let mealItems: [MealItem]
    var onLogMeal: ([Food]) -> Void = { _ in }
    var onAddToPlate: ([Food]) -> Void = { _ in }

    @State private var selectedFood: Food?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    mealItemsSection
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }

            footerButtons
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Material.bar)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("My Meal")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding<Bool>(
            get: { selectedFood != nil },
            set: { if !$0 { selectedFood = nil } }
        )) {
            if let food = selectedFood {
                FoodSummaryView(food: food)
            }
        }
    }

    private var mealItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Items")
                .font(.headline)
                .foregroundColor(.primary)

            if mealItems.isEmpty && foods.isEmpty {
                Text("No meal items found.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let displayedItems = mealItemsFromFoodsOrFallback
                VStack(spacing: 10) {
                    ForEach(displayedItems, id: \.id) { item in
                        Button {
                            if let food = foodForMealItem(item) {
                                selectedFood = food
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name.isEmpty ? "Meal Item" : item.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                    if let brand = item.brand, !brand.isEmpty {
                                        Text(brand)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    if let serving = item.servingText, !serving.isEmpty {
                                        Text(serving)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if let cals = item.caloriesText {
                                    Text(cals)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button {
                onLogMeal(foods)
            } label: {
                Text("Log Meal")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }

            Button {
                onAddToPlate(foods)
            } label: {
                Text("Add to Plate")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(16)
            }
        }
    }

    private var mealItemsFromFoodsOrFallback: [MealItemListDisplay] {
        if !mealItems.isEmpty {
            return mealItems.map {
                MealItemListDisplay(
                    id: $0.id.uuidString,
                    name: $0.name,
                    brand: nil,
                    servingText: servingDescription(for: $0),
                    caloriesText: formattedCalories(from: $0.calories)
                )
            }
        }

        return foods.map { food in
            MealItemListDisplay(
                id: String(food.id),
                name: food.displayName,
                brand: food.brandText,
                servingText: food.servingSizeText,
                caloriesText: formattedCalories(from: food.calories)
            )
        }
    }

    private func servingDescription(for item: MealItem) -> String? {
        let amount = item.serving
        let unit = item.servingUnit ?? "serving"
        let amountText: String
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            amountText = String(Int(amount))
        } else {
            amountText = String(format: "%.2f", amount).replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
        }
        return "\(amountText) \(unit)"
    }

    private func formattedCalories(from value: Double?) -> String? {
        guard let value else { return nil }
        return "\(Int(value.rounded())) kcal"
    }

    private func foodForMealItem(_ item: MealItemListDisplay) -> Food? {
        if let match = foods.first(where: { $0.displayName == item.name }) {
            return match
        }
        return foods.first
    }
}

private struct MealItemListDisplay: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let servingText: String?
    let caloriesText: String?
}
