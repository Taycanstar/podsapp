//
//  NutritionFactsView.swift
//  pods
//
//  Created by Dimi Nunez on 12/20/25.
//

import SwiftUI

// MARK: - Supporting Types

enum NutritionTab: String, CaseIterable {
    case standard = "Standard"
    case advanced = "Advanced"
}

enum VitaminUnit: String, CaseIterable {
    case mcg = "mcg"
    case iu = "IU"
}

enum VitaminType {
    case vitaminA
    case vitaminD

    /// Converts to mcg based on vitamin type
    /// Vitamin A: 1 mcg = 3.33 IU
    /// Vitamin D: 1 mcg = 40 IU
    func toMcg(_ value: Double, from unit: VitaminUnit) -> Double {
        switch unit {
        case .mcg:
            return value
        case .iu:
            switch self {
            case .vitaminA: return value / 3.33
            case .vitaminD: return value / 40
            }
        }
    }
}

// MARK: - NutritionFactsView

struct NutritionFactsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // Data from NewFoodView
    let name: String
    let brand: String
    let basedOn: NutritionBasis
    let weight: String
    let servingAmount: String
    let servingUnit: String

    // Tab selection
    @State private var selectedTab: NutritionTab = .standard

    // Unit preferences for vitamins with dual units
    @State private var vitaminAUnit: VitaminUnit = .mcg
    @State private var vitaminDUnit: VitaminUnit = .mcg

    // MARK: - Standard Nutrients
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var saturatedFat = ""
    @State private var transFat = ""
    @State private var cholesterol = ""
    @State private var sodium = ""
    @State private var fiber = ""
    @State private var sugars = ""
    @State private var addedSugars = ""
    @State private var vitaminD = ""
    @State private var vitaminC = ""
    @State private var vitaminA = ""
    @State private var calcium = ""
    @State private var iron = ""
    @State private var potassium = ""

    // MARK: - Advanced - General
    @State private var alcohol = ""
    @State private var caffeine = ""
    @State private var choline = ""
    @State private var water = ""

    // MARK: - Advanced - Fats
    @State private var monoFat = ""
    @State private var polyFat = ""
    @State private var omega3ALA = ""
    @State private var omega3EPA = ""
    @State private var omega3DHA = ""
    @State private var omega3DPA = ""

    // MARK: - Advanced - Carbs
    @State private var starch = ""
    @State private var sugarAlcohol = ""

    // MARK: - Advanced - Vitamins
    @State private var vitaminE = ""
    @State private var vitaminK = ""
    @State private var thiamin = ""
    @State private var riboflavin = ""
    @State private var niacin = ""
    @State private var pantothenicAcid = ""
    @State private var vitaminB6 = ""
    @State private var vitaminB12 = ""
    @State private var folate = ""
    @State private var biotin = ""

    // MARK: - Advanced - Minerals
    @State private var magnesium = ""
    @State private var phosphorus = ""
    @State private var zinc = ""
    @State private var copper = ""
    @State private var manganese = ""
    @State private var selenium = ""
    @State private var fluoride = ""

    // MARK: - Advanced - Amino Acids
    @State private var histidine = ""
    @State private var isoleucine = ""
    @State private var leucine = ""
    @State private var lysine = ""
    @State private var methionine = ""
    @State private var cysteine = ""
    @State private var phenylalanine = ""
    @State private var threonine = ""
    @State private var tryptophan = ""
    @State private var tyrosine = ""
    @State private var valine = ""
    @State private var arginine = ""
    @State private var alanine = ""
    @State private var asparticAcid = ""
    @State private var glutamicAcid = ""
    @State private var glycine = ""
    @State private var proline = ""
    @State private var serine = ""

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Picker
            Picker("", selection: $selectedTab) {
                ForEach(NutritionTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // Content based on tab
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case .standard:
                        standardNutrients
                    case .advanced:
                        advancedNutrients
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }

            footerBar
        }
        .navigationTitle("Nutrition Facts")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - Standard Tab

    private var standardNutrients: some View {
        VStack(alignment: .leading, spacing: 12) {
            card {
                nutrientField(label: "Calories", unit: "kcal", text: $calories, required: true)
                Divider()
                nutrientField(label: "Protein", unit: "g", text: $protein)
                Divider()
                nutrientField(label: "Carbs", unit: "g", text: $carbs)
                Divider()
                nutrientField(label: "Fat", unit: "g", text: $fat)
                Divider()
                nutrientField(label: "Saturated Fat", unit: "g", text: $saturatedFat)
                Divider()
                nutrientField(label: "Trans Fat", unit: "g", text: $transFat)
                Divider()
                nutrientField(label: "Cholesterol", unit: "mg", text: $cholesterol)
                Divider()
                nutrientField(label: "Sodium", unit: "mg", text: $sodium)
                Divider()
                nutrientField(label: "Fiber", unit: "g", text: $fiber)
                Divider()
                nutrientField(label: "Sugars", unit: "g", text: $sugars)
                Divider()
                nutrientField(label: "Added Sugars", unit: "g", text: $addedSugars)
                Divider()
                vitaminFieldWithUnitPicker(label: "Vitamin D", text: $vitaminD, unit: $vitaminDUnit)
                Divider()
                nutrientField(label: "Vitamin C", unit: "mg", text: $vitaminC)
                Divider()
                vitaminFieldWithUnitPicker(label: "Vitamin A", text: $vitaminA, unit: $vitaminAUnit)
                Divider()
                nutrientField(label: "Calcium", unit: "mg", text: $calcium)
                Divider()
                nutrientField(label: "Iron", unit: "mg", text: $iron)
                Divider()
                nutrientField(label: "Potassium", unit: "mg", text: $potassium)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Advanced Tab

    private var advancedNutrients: some View {
        VStack(alignment: .leading, spacing: 20) {
            // General Section
            section(title: "General") {
                nutrientField(label: "Calories", unit: "kcal", text: $calories, required: true)
                Divider()
                nutrientField(label: "Alcohol", unit: "g", text: $alcohol)
                Divider()
                nutrientField(label: "Caffeine", unit: "mg", text: $caffeine)
                Divider()
                nutrientField(label: "Cholesterol", unit: "mg", text: $cholesterol)
                Divider()
                nutrientField(label: "Choline", unit: "mg", text: $choline)
                Divider()
                nutrientField(label: "Water", unit: "g", text: $water)
            }

            // Protein Section
            section(title: "Protein") {
                nutrientField(label: "Protein", unit: "g", text: $protein)
                Divider()
                nutrientField(label: "Histidine", unit: "g", text: $histidine)
                Divider()
                nutrientField(label: "Isoleucine", unit: "g", text: $isoleucine)
                Divider()
                nutrientField(label: "Leucine", unit: "g", text: $leucine)
                Divider()
                nutrientField(label: "Lysine", unit: "g", text: $lysine)
                Divider()
                nutrientField(label: "Methionine", unit: "g", text: $methionine)
                Divider()
                nutrientField(label: "Cysteine", unit: "g", text: $cysteine)
                Divider()
                nutrientField(label: "Phenylalanine", unit: "g", text: $phenylalanine)
                Divider()
                nutrientField(label: "Threonine", unit: "g", text: $threonine)
                Divider()
                nutrientField(label: "Tryptophan", unit: "g", text: $tryptophan)
                Divider()
                nutrientField(label: "Tyrosine", unit: "g", text: $tyrosine)
                Divider()
                nutrientField(label: "Valine", unit: "g", text: $valine)
                Divider()
                nutrientField(label: "Arginine", unit: "g", text: $arginine)
                Divider()
                nutrientField(label: "Alanine", unit: "g", text: $alanine)
                Divider()
                nutrientField(label: "Aspartic Acid", unit: "g", text: $asparticAcid)
                Divider()
                nutrientField(label: "Glutamic Acid", unit: "g", text: $glutamicAcid)
                Divider()
                nutrientField(label: "Glycine", unit: "g", text: $glycine)
                Divider()
                nutrientField(label: "Proline", unit: "g", text: $proline)
                Divider()
                nutrientField(label: "Serine", unit: "g", text: $serine)
            }

            // Fat Section
            section(title: "Fat") {
                nutrientField(label: "Total Fat", unit: "g", text: $fat)
                Divider()
                nutrientField(label: "Saturated Fat", unit: "g", text: $saturatedFat)
                Divider()
                nutrientField(label: "Trans Fat", unit: "g", text: $transFat)
                Divider()
                nutrientField(label: "Monounsaturated Fat", unit: "g", text: $monoFat)
                Divider()
                nutrientField(label: "Polyunsaturated Fat", unit: "g", text: $polyFat)
                Divider()
                nutrientField(label: "Omega-3 ALA", unit: "g", text: $omega3ALA)
                Divider()
                nutrientField(label: "Omega-3 EPA", unit: "g", text: $omega3EPA)
                Divider()
                nutrientField(label: "Omega-3 DHA", unit: "g", text: $omega3DHA)
                Divider()
                nutrientField(label: "Omega-3 DPA", unit: "g", text: $omega3DPA)
            }

            // Carbohydrates Section
            section(title: "Carbohydrates") {
                nutrientField(label: "Total Carbs", unit: "g", text: $carbs)
                Divider()
                nutrientField(label: "Fiber", unit: "g", text: $fiber)
                Divider()
                nutrientField(label: "Sugars", unit: "g", text: $sugars)
                Divider()
                nutrientField(label: "Added Sugars", unit: "g", text: $addedSugars)
                Divider()
                nutrientField(label: "Starch", unit: "g", text: $starch)
                Divider()
                nutrientField(label: "Sugar Alcohol", unit: "g", text: $sugarAlcohol)
            }

            // Vitamins Section
            section(title: "Vitamins") {
                vitaminFieldWithUnitPicker(label: "Vitamin A", text: $vitaminA, unit: $vitaminAUnit)
                Divider()
                nutrientField(label: "Vitamin C", unit: "mg", text: $vitaminC)
                Divider()
                vitaminFieldWithUnitPicker(label: "Vitamin D", text: $vitaminD, unit: $vitaminDUnit)
                Divider()
                nutrientField(label: "Vitamin E", unit: "mg", text: $vitaminE)
                Divider()
                nutrientField(label: "Vitamin K", unit: "mcg", text: $vitaminK)
                Divider()
                nutrientField(label: "Thiamin (B1)", unit: "mg", text: $thiamin)
                Divider()
                nutrientField(label: "Riboflavin (B2)", unit: "mg", text: $riboflavin)
                Divider()
                nutrientField(label: "Niacin (B3)", unit: "mg", text: $niacin)
                Divider()
                nutrientField(label: "Pantothenic Acid (B5)", unit: "mg", text: $pantothenicAcid)
                Divider()
                nutrientField(label: "Vitamin B6", unit: "mg", text: $vitaminB6)
                Divider()
                nutrientField(label: "Vitamin B12", unit: "mcg", text: $vitaminB12)
                Divider()
                nutrientField(label: "Folate", unit: "mcg", text: $folate)
                Divider()
                nutrientField(label: "Biotin", unit: "mcg", text: $biotin)
            }

            // Minerals Section
            section(title: "Minerals") {
                nutrientField(label: "Calcium", unit: "mg", text: $calcium)
                Divider()
                nutrientField(label: "Iron", unit: "mg", text: $iron)
                Divider()
                nutrientField(label: "Magnesium", unit: "mg", text: $magnesium)
                Divider()
                nutrientField(label: "Phosphorus", unit: "mg", text: $phosphorus)
                Divider()
                nutrientField(label: "Potassium", unit: "mg", text: $potassium)
                Divider()
                nutrientField(label: "Sodium", unit: "mg", text: $sodium)
                Divider()
                nutrientField(label: "Zinc", unit: "mg", text: $zinc)
                Divider()
                nutrientField(label: "Copper", unit: "mg", text: $copper)
                Divider()
                nutrientField(label: "Manganese", unit: "mg", text: $manganese)
                Divider()
                nutrientField(label: "Selenium", unit: "mcg", text: $selenium)
                Divider()
                nutrientField(label: "Fluoride", unit: "mcg", text: $fluoride)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            Button(action: {
                HapticFeedback.generateLigth()
                submitFood()
            }) {
                Text("Create Food")
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
            .disabled(calories.isEmpty)
            .opacity(calories.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Helper Components

    private func card<T: View>(@ViewBuilder content: () -> T) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color("iosnp")))
    }

    private func section<T: View>(title: String, @ViewBuilder content: () -> T) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            card { content() }
        }
    }

    private func nutrientField(
        label: String,
        unit: String,
        text: Binding<String>,
        required: Bool = false
    ) -> some View {
        HStack {
            HStack(spacing: 4) {
                Text(label)
                if required {
                    Text("*")
                        .foregroundColor(.red)
                }
            }
            Spacer()
            TextField("0", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 80)
            Text(unit)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
        }
    }

    private func vitaminFieldWithUnitPicker(
        label: String,
        text: Binding<String>,
        unit: Binding<VitaminUnit>
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 80)
            Menu {
                ForEach(VitaminUnit.allCases, id: \.self) { unitOption in
                    Button(unitOption.rawValue) {
                        unit.wrappedValue = unitOption
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(unit.wrappedValue.rawValue)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            }
        }
    }

    // MARK: - Submit

    private func submitFood() {
        // TODO: Create food with all nutrient values
        // Convert IU to mcg for storage if needed
        // Submit to backend
    }
}

#Preview {
    NavigationStack {
        NutritionFactsView(
            name: "Test Food",
            brand: "Test Brand",
            basedOn: .serving,
            weight: "100",
            servingAmount: "1",
            servingUnit: "serving"
        )
    }
}
