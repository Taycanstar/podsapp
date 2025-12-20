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
    case vitaminE

    /// Converts to mcg/mg based on vitamin type
    /// Vitamin A: 1 mcg = 3.33 IU
    /// Vitamin D: 1 mcg = 40 IU
    /// Vitamin E: 1 mg = 1.49 IU
    func toBaseUnit(_ value: Double, from unit: VitaminUnit) -> Double {
        switch unit {
        case .mcg:
            return value
        case .iu:
            switch self {
            case .vitaminA: return value / 3.33
            case .vitaminD: return value / 40
            case .vitaminE: return value / 1.49
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
    @State private var vitaminEUnit: VitaminUnit = .mcg

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
        List {
            // Tab Picker Section
            Section {
                Picker("", selection: $selectedTab) {
                    ForEach(NutritionTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            // Content based on tab
            switch selectedTab {
            case .standard:
                standardSections
            case .advanced:
                advancedSections
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
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

    // MARK: - Standard Tab Sections

    @ViewBuilder
    private var standardSections: some View {
        Section {
            nutrientRow(label: "Calories", unit: "kcal", text: $calories, required: true)
            nutrientRow(label: "Protein", unit: "g", text: $protein)
            nutrientRow(label: "Carbs", unit: "g", text: $carbs)
            nutrientRow(label: "Fat", unit: "g", text: $fat)
            nutrientRow(label: "Saturated Fat", unit: "g", text: $saturatedFat)
            nutrientRow(label: "Trans Fat", unit: "g", text: $transFat)
            nutrientRow(label: "Cholesterol", unit: "mg", text: $cholesterol)
            nutrientRow(label: "Sodium", unit: "mg", text: $sodium)
            nutrientRow(label: "Fiber", unit: "g", text: $fiber)
            nutrientRow(label: "Sugars", unit: "g", text: $sugars)
            nutrientRow(label: "Added Sugars", unit: "g", text: $addedSugars)
            nutrientRow(label: "Vitamin C", unit: "mg", text: $vitaminC)
            vitaminRowWithUnitPicker(label: "Vitamin D", text: $vitaminD, unit: $vitaminDUnit)
            vitaminRowWithUnitPicker(label: "Vitamin A", text: $vitaminA, unit: $vitaminAUnit)
            nutrientRow(label: "Calcium", unit: "mg", text: $calcium)
            nutrientRow(label: "Iron", unit: "mg", text: $iron)
            nutrientRow(label: "Potassium", unit: "mg", text: $potassium)
        }
    }

    // MARK: - Advanced Tab Sections

    @ViewBuilder
    private var advancedSections: some View {
        // General Section
        Section {
            nutrientRow(label: "Calories", unit: "kcal", text: $calories, required: true)
            nutrientRow(label: "Alcohol", unit: "g", text: $alcohol)
            nutrientRow(label: "Caffeine", unit: "mg", text: $caffeine)
            nutrientRow(label: "Cholesterol", unit: "mg", text: $cholesterol)
            nutrientRow(label: "Choline", unit: "mg", text: $choline)
            nutrientRow(label: "Water", unit: "g", text: $water)
        } header: {
            Text("General")
        }

        // Protein Section
        Section {
            nutrientRow(label: "Protein", unit: "g", text: $protein)
            nutrientRow(label: "Histidine", unit: "g", text: $histidine)
            nutrientRow(label: "Isoleucine", unit: "g", text: $isoleucine)
            nutrientRow(label: "Leucine", unit: "g", text: $leucine)
            nutrientRow(label: "Lysine", unit: "g", text: $lysine)
            nutrientRow(label: "Methionine", unit: "g", text: $methionine)
            nutrientRow(label: "Cysteine", unit: "g", text: $cysteine)
            nutrientRow(label: "Phenylalanine", unit: "g", text: $phenylalanine)
            nutrientRow(label: "Threonine", unit: "g", text: $threonine)
            nutrientRow(label: "Tryptophan", unit: "g", text: $tryptophan)
            nutrientRow(label: "Tyrosine", unit: "g", text: $tyrosine)
            nutrientRow(label: "Valine", unit: "g", text: $valine)
            nutrientRow(label: "Arginine", unit: "g", text: $arginine)
            nutrientRow(label: "Alanine", unit: "g", text: $alanine)
            nutrientRow(label: "Aspartic Acid", unit: "g", text: $asparticAcid)
            nutrientRow(label: "Glutamic Acid", unit: "g", text: $glutamicAcid)
            nutrientRow(label: "Glycine", unit: "g", text: $glycine)
            nutrientRow(label: "Proline", unit: "g", text: $proline)
            nutrientRow(label: "Serine", unit: "g", text: $serine)
        } header: {
            Text("Protein")
        }

        // Fat Section
        Section {
            nutrientRow(label: "Total Fat", unit: "g", text: $fat)
            nutrientRow(label: "Saturated Fat", unit: "g", text: $saturatedFat)
            nutrientRow(label: "Trans Fat", unit: "g", text: $transFat)
            nutrientRow(label: "Monounsaturated Fat", unit: "g", text: $monoFat)
            nutrientRow(label: "Polyunsaturated Fat", unit: "g", text: $polyFat)
            nutrientRow(label: "Omega-3 ALA", unit: "g", text: $omega3ALA)
            nutrientRow(label: "Omega-3 EPA", unit: "g", text: $omega3EPA)
            nutrientRow(label: "Omega-3 DHA", unit: "g", text: $omega3DHA)
            nutrientRow(label: "Omega-3 DPA", unit: "g", text: $omega3DPA)
        } header: {
            Text("Fat")
        }

        // Carbohydrates Section
        Section {
            nutrientRow(label: "Total Carbs", unit: "g", text: $carbs)
            nutrientRow(label: "Fiber", unit: "g", text: $fiber)
            nutrientRow(label: "Sugars", unit: "g", text: $sugars)
            nutrientRow(label: "Added Sugars", unit: "g", text: $addedSugars)
            nutrientRow(label: "Starch", unit: "g", text: $starch)
            nutrientRow(label: "Sugar Alcohol", unit: "g", text: $sugarAlcohol)
        } header: {
            Text("Carbohydrates")
        }

        // Vitamins Section - A, D, E first (they have pickers)
        Section {
            vitaminRowWithUnitPicker(label: "Vitamin A", text: $vitaminA, unit: $vitaminAUnit)
            vitaminRowWithUnitPicker(label: "Vitamin D", text: $vitaminD, unit: $vitaminDUnit)
            vitaminRowWithUnitPicker(label: "Vitamin E", text: $vitaminE, unit: $vitaminEUnit)
            nutrientRow(label: "Vitamin C", unit: "mg", text: $vitaminC)
            nutrientRow(label: "Vitamin K", unit: "mcg", text: $vitaminK)
            nutrientRow(label: "Thiamin (B1)", unit: "mg", text: $thiamin)
            nutrientRow(label: "Riboflavin (B2)", unit: "mg", text: $riboflavin)
            nutrientRow(label: "Niacin (B3)", unit: "mg", text: $niacin)
            nutrientRow(label: "Pantothenic Acid (B5)", unit: "mg", text: $pantothenicAcid)
            nutrientRow(label: "Vitamin B6", unit: "mg", text: $vitaminB6)
            nutrientRow(label: "Vitamin B12", unit: "mcg", text: $vitaminB12)
            nutrientRow(label: "Folate", unit: "mcg", text: $folate)
            nutrientRow(label: "Biotin", unit: "mcg", text: $biotin)
        } header: {
            Text("Vitamins")
        }

        // Minerals Section
        Section {
            nutrientRow(label: "Calcium", unit: "mg", text: $calcium)
            nutrientRow(label: "Iron", unit: "mg", text: $iron)
            nutrientRow(label: "Magnesium", unit: "mg", text: $magnesium)
            nutrientRow(label: "Phosphorus", unit: "mg", text: $phosphorus)
            nutrientRow(label: "Potassium", unit: "mg", text: $potassium)
            nutrientRow(label: "Sodium", unit: "mg", text: $sodium)
            nutrientRow(label: "Zinc", unit: "mg", text: $zinc)
            nutrientRow(label: "Copper", unit: "mg", text: $copper)
            nutrientRow(label: "Manganese", unit: "mg", text: $manganese)
            nutrientRow(label: "Selenium", unit: "mcg", text: $selenium)
            nutrientRow(label: "Fluoride", unit: "mcg", text: $fluoride)
        } header: {
            Text("Minerals")
        }
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

    // MARK: - Row Components

    private func nutrientRow(
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
            HStack(spacing: 4) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text(unit)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func vitaminRowWithUnitPicker(
        label: String,
        text: Binding<String>,
        unit: Binding<VitaminUnit>
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
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
                        .font(.system(size: 12))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color("iosbtn"))
                .cornerRadius(8)
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
