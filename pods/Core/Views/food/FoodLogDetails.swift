//
//  FoodLogDetails.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/25.
//

import SwiftUI

struct FoodLogDetails: View {
    @Environment(\.dismiss) private var dismiss
    let food: Food
    
    // Helper to get nutrient value by name
    private func nutrientValue(_ name: String) -> String {
        if let value = food.foodNutrients.first(where: { $0.nutrientName == name })?.value {
            return String(format: "%g", value)
        }
        return "0"
    }
    
    // Helper to get nutrient value with unit
    private func nutrientValueWithUnit(_ name: String, defaultUnit: String) -> String {
        if let nutrient = food.foodNutrients.first(where: { $0.nutrientName == name }) {
            let value = nutrient.value ?? 0
            let unit = nutrient.unitName ?? defaultUnit
            return "\(String(format: "%g", value)) \(unit)"
        }
        return "0 \(defaultUnit)"
    }
    
    @State private var showMoreNutrients: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Basic food info card
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("iosnp"))
                    VStack(spacing: 0) {
                        // Title
                        HStack {
                            Text(food.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        Divider().padding(.leading, 16)
                        // Serving Size
                        HStack {
                            Text("Serving Size")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(food.householdServingFullText ?? "-")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        Divider().padding(.leading, 16)
                        // Number of Servings
                        HStack {
                            Text("Number of Servings")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(String(format: "%g", food.numberOfServings ?? 1))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal)
                // Nutrition facts section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nutrition Facts")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("iosnp"))
                        VStack(spacing: 0) {
                            // Calories
                            HStack {
                                Text("Calories")
                                Spacer()
                                Text(nutrientValue("Energy"))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            Divider().padding(.leading, 16)
                            // Protein
                            HStack {
                                Text("Protein (g)")
                                Spacer()
                                Text(nutrientValue("Protein"))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            Divider().padding(.leading, 16)
                            // Carbs
                            HStack {
                                Text("Carbs (g)")
                                Spacer()
                                Text(nutrientValue("Carbohydrate, by difference"))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            Divider().padding(.leading, 16)
                            // Fat
                            HStack {
                                Text("Total Fat (g)")
                                Spacer()
                                Text(nutrientValue("Total lipid (fat)"))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal)
                    // Show More Nutrients button
                    Button(action: { withAnimation { showMoreNutrients.toggle() } }) {
                        HStack {
                            Text(showMoreNutrients ? "Hide Additional Nutrients" : "Show More Nutrients")
                                .foregroundColor(.accentColor)
                            Image(systemName: showMoreNutrients ? "chevron.up" : "chevron.down")
                                .foregroundColor(.accentColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                        .background(Color("iosnp"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                // Additional nutrients section (collapsible)
                if showMoreNutrients {
                    VStack(alignment: .leading, spacing: 16) {
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("iosnp"))
                            VStack(spacing: 0) {
                                ForEach(additionalNutrients, id: \.0) { label, name, unit in
                                    HStack {
                                        Text(label)
                                        Spacer()
                                        Text(nutrientValueWithUnit(name, defaultUnit: unit))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 16)
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .transition(.opacity)
                }
                Spacer().frame(height: 40)
            }
            .padding(.top, 16)
        }
        .background(Color("iosbg"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Log Details").font(.headline)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    // List of additional nutrients to show
    private var additionalNutrients: [(String, String, String)] {
        [
            ("Saturated Fat (g)", "Saturated Fatty Acids", "g"),
            ("Polyunsaturated Fat (g)", "Polyunsaturated Fatty Acids", "g"),
            ("Monounsaturated Fat (g)", "Monounsaturated Fatty Acids", "g"),
            ("Trans Fat (g)", "Trans Fatty Acids", "g"),
            ("Cholesterol (mg)", "Cholesterol", "mg"),
            ("Sodium (mg)", "Sodium", "mg"),
            ("Potassium (mg)", "Potassium", "mg"),
            ("Sugar (g)", "Sugar", "g"),
            ("Fiber (g)", "Fiber", "g"),
            ("Vitamin A (%)", "Vitamin A", "%"),
            ("Vitamin C (%)", "Vitamin C", "%"),
            ("Calcium (%)", "Calcium", "%"),
            ("Iron (%)", "Iron", "%")
        ]
    }
}

#Preview {
    // Provide a mock Food object for preview
    let food = Food(
        fdcId: 1,
        description: "Sample Food",
        brandOwner: nil,
        brandName: nil,
        servingSize: 1.0,
        numberOfServings: 1.0,
        servingSizeUnit: "g",
        householdServingFullText: "1 cup",
        foodNutrients: [
            Nutrient(nutrientName: "Energy", value: 120, unitName: "kcal"),
            Nutrient(nutrientName: "Protein", value: 5, unitName: "g"),
            Nutrient(nutrientName: "Carbohydrate, by difference", value: 20, unitName: "g"),
            Nutrient(nutrientName: "Total lipid (fat)", value: 2, unitName: "g"),
            Nutrient(nutrientName: "Saturated Fatty Acids", value: 1, unitName: "g"),
            Nutrient(nutrientName: "Polyunsaturated Fatty Acids", value: 0.5, unitName: "g"),
            Nutrient(nutrientName: "Monounsaturated Fatty Acids", value: 0.3, unitName: "g"),
            Nutrient(nutrientName: "Trans Fatty Acids", value: 0, unitName: "g"),
            Nutrient(nutrientName: "Cholesterol", value: 10, unitName: "mg"),
            Nutrient(nutrientName: "Sodium", value: 100, unitName: "mg"),
            Nutrient(nutrientName: "Potassium", value: 200, unitName: "mg"),
            Nutrient(nutrientName: "Sugar", value: 8, unitName: "g"),
            Nutrient(nutrientName: "Fiber", value: 3, unitName: "g"),
            Nutrient(nutrientName: "Vitamin A", value: 10, unitName: "%"),
            Nutrient(nutrientName: "Vitamin C", value: 15, unitName: "%"),
            Nutrient(nutrientName: "Calcium", value: 20, unitName: "%"),
            Nutrient(nutrientName: "Iron", value: 5, unitName: "%")
        ],
        foodMeasures: []
    )
    return FoodLogDetails(food: food)
}
