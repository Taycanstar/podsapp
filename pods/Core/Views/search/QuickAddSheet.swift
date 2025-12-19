//
//  QuickAddSheet.swift
//  pods
//
//  Created by Dimi Nunez on 12/17/25.
//

import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var foodManager: FoodManager

    // Form inputs
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""
    @State private var alcohol = ""

    // UI state
    @State private var isLogging = false

    // Focus state for calories field
    @FocusState private var isCaloriesFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Input form
                VStack(spacing: 0) {
                    inputRow(label: "Calories", text: $calories, placeholder: "Required", keyboardType: .decimalPad, isFocused: $isCaloriesFocused)
                    Divider().padding(.horizontal, 16)
                    inputRow(label: "Name", text: $name, placeholder: "Optional")
                    Divider().padding(.horizontal, 16)
                    inputRow(label: "Protein", text: $protein, placeholder: "0", suffix: "g", keyboardType: .decimalPad)
                    Divider().padding(.horizontal, 16)
                    inputRow(label: "Fat", text: $fat, placeholder: "0", suffix: "g", keyboardType: .decimalPad)
                    Divider().padding(.horizontal, 16)
                    inputRow(label: "Carbs", text: $carbs, placeholder: "0", suffix: "g", keyboardType: .decimalPad)
                    Divider().padding(.horizontal, 16)
                    inputRow(label: "Alcohol", text: $alcohol, placeholder: "0", suffix: "g", keyboardType: .decimalPad)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 20)

                Spacer()

                // Footer with two buttons
                footerBar
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }

    // MARK: - Input Row

    private func inputRow(
        label: String,
        text: Binding<String>,
        placeholder: String,
        suffix: String? = nil,
        keyboardType: UIKeyboardType = .default,
        isFocused: FocusState<Bool>.Binding? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 17))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 4) {
                if let isFocused = isFocused {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboardType)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                        .focused(isFocused)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboardType)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                }

                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            HStack(spacing: 12) {
                // Log Food button
                Button(action: {
                    HapticFeedback.generateLigth()
                    logFood()
                }) {
                    Text(isLogging ? "Logging..." : "Log Food")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(Color("background"))
                )
                .foregroundColor(Color("text"))
                .disabled(calories.isEmpty || isLogging)
                .opacity(isLogging ? 0.7 : 1)

                // Add to Plate button
                Button(action: {
                    HapticFeedback.generateLigth()
                    quickAdd()
                }) {
                    Text("Add to Plate")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(Color("background"))
                )
                .foregroundColor(Color("text"))
                .disabled(calories.isEmpty)
                .opacity(calories.isEmpty ? 0.5 : 1)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Actions

    private func logFood() {
        guard let caloriesValue = Double(calories) else { return }

        isLogging = true

        // Build nutrients array
        var nutrients: [Nutrient] = [
            Nutrient(nutrientName: "Energy", value: caloriesValue, unitName: "kcal")
        ]

        if let proteinValue = Double(protein), proteinValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Protein", value: proteinValue, unitName: "g"))
        }
        if let carbsValue = Double(carbs), carbsValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Carbohydrate, by difference", value: carbsValue, unitName: "g"))
        }
        if let fatValue = Double(fat), fatValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Total lipid (fat)", value: fatValue, unitName: "g"))
        }
        if let alcoholValue = Double(alcohol), alcoholValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Alcohol, ethyl", value: alcoholValue, unitName: "g"))
        }

        // Create a quick add food
        let foodName = name.isEmpty ? "Custom Food" : name
        let food = Food(
            fdcId: Int.random(in: 1000000..<9999999),
            description: foodName,
            brandOwner: nil,
            brandName: nil,
            servingSize: 1.0,
            numberOfServings: 1.0,
            servingSizeUnit: "serving",
            householdServingFullText: "1 serving",
            foodNutrients: nutrients,
            foodMeasures: []
        )

        // Log the food
        let mealType = suggestedMealPeriod(for: Date())
        foodManager.logFood(
            email: foodManager.userEmail ?? "",
            food: food,
            meal: mealType,
            servings: 1.0,
            date: Date()
        ) { result in
            DispatchQueue.main.async {
                isLogging = false
                switch result {
                case .success:
                    // Navigate to timeline
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToTimeline"), object: nil)
                    dismiss()
                case .failure:
                    dismiss()
                }
            }
        }
    }

    private func quickAdd() {
        // TODO: Implement quick add to plate
        dismiss()
    }

    // MARK: - Helper

    private func suggestedMealPeriod(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return "Breakfast"
        case 11..<15:
            return "Lunch"
        case 15..<21:
            return "Dinner"
        default:
            return "Snack"
        }
    }
}

#Preview {
    QuickAddSheet()
        .environmentObject(FoodManager())
}
