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

    @State private var isAdding = false

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ingredientItemsSection
                        macroSummaryCard
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
