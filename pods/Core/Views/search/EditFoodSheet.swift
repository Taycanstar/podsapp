//
//  EditFoodSheet.swift
//  pods
//
//  Created by Dimi Nunez on 12/23/25.
//

import SwiftUI

struct EditFoodSheet: View {
    enum EditMode {
        case editInPlace    // For user foods - updates existing
        case editACopy      // For database foods - creates new
    }

    let food: Food
    let mode: EditMode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var foodManager: FoodManager

    // Callback for when food is updated/created
    var onFoodUpdated: ((Food) -> Void)?

    // Loading state
    @State private var isSubmitting = false

    // Basic Info (from NewFoodView)
    @State private var name: String
    @State private var brand: String
    @State private var basedOn: NutritionBasis
    @State private var weight: String
    @State private var servingAmount: String
    @State private var servingUnit: String

    // Tab selection
    @State private var selectedTab: NutritionTab = .standard

    // Unit preferences for vitamins with dual units
    @State private var vitaminAUnit: VitaminUnit = .mcg
    @State private var vitaminDUnit: VitaminUnit = .mcg
    @State private var vitaminEUnit: VitaminUnit = .mcg

    // MARK: - Standard Nutrients
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var saturatedFat: String
    @State private var transFat: String
    @State private var cholesterol: String
    @State private var sodium: String
    @State private var fiber: String
    @State private var sugars: String
    @State private var addedSugars: String
    @State private var vitaminD: String
    @State private var vitaminC: String
    @State private var vitaminA: String
    @State private var calcium: String
    @State private var iron: String
    @State private var potassium: String

    // MARK: - Advanced - General
    @State private var alcohol: String
    @State private var caffeine: String
    @State private var choline: String
    @State private var water: String

    // MARK: - Advanced - Fats
    @State private var monoFat: String
    @State private var polyFat: String
    @State private var omega3ALA: String
    @State private var omega3EPA: String
    @State private var omega3DHA: String
    @State private var omega3DPA: String

    // MARK: - Advanced - Carbs
    @State private var starch: String
    @State private var sugarAlcohol: String

    // MARK: - Advanced - Vitamins
    @State private var vitaminE: String
    @State private var vitaminK: String
    @State private var thiamin: String
    @State private var riboflavin: String
    @State private var niacin: String
    @State private var pantothenicAcid: String
    @State private var vitaminB6: String
    @State private var vitaminB12: String
    @State private var folate: String
    @State private var biotin: String

    // MARK: - Advanced - Minerals
    @State private var magnesium: String
    @State private var phosphorus: String
    @State private var zinc: String
    @State private var copper: String
    @State private var manganese: String
    @State private var selenium: String
    @State private var fluoride: String

    // MARK: - Advanced - Amino Acids
    @State private var histidine: String
    @State private var isoleucine: String
    @State private var leucine: String
    @State private var lysine: String
    @State private var methionine: String
    @State private var cysteine: String
    @State private var phenylalanine: String
    @State private var threonine: String
    @State private var tryptophan: String
    @State private var tyrosine: String
    @State private var valine: String
    @State private var arginine: String
    @State private var alanine: String
    @State private var asparticAcid: String
    @State private var glutamicAcid: String
    @State private var glycine: String
    @State private var proline: String
    @State private var serine: String

    private var chipColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }

    // MARK: - Initializer
    init(food: Food, mode: EditMode = .editInPlace, onFoodUpdated: ((Food) -> Void)? = nil) {
        self.food = food
        self.mode = mode
        self.onFoodUpdated = onFoodUpdated

        // Pre-populate basic info
        _name = State(initialValue: food.displayName)
        _brand = State(initialValue: food.brandName ?? "")
        _basedOn = State(initialValue: .serving)
        _weight = State(initialValue: food.servingSize.map { String(format: "%.0f", $0) } ?? "")
        _servingAmount = State(initialValue: food.servingSize.map { String(format: "%.0f", $0) } ?? "1")
        _servingUnit = State(initialValue: food.servingSizeUnit ?? "serving")

        // Pre-populate nutrients from food
        _calories = State(initialValue: Self.nutrientString(food, names: ["Energy", "Calories"]) ?? String(format: "%.0f", food.calories ?? 0))
        _protein = State(initialValue: Self.nutrientString(food, names: ["Protein"]) ?? String(format: "%.0f", food.protein ?? 0))
        _carbs = State(initialValue: Self.nutrientString(food, names: ["Carbohydrate, by difference", "Carbs", "Total Carbohydrates"]) ?? String(format: "%.0f", food.carbs ?? 0))
        _fat = State(initialValue: Self.nutrientString(food, names: ["Total lipid (fat)", "Fat", "Total Fat"]) ?? String(format: "%.0f", food.fat ?? 0))
        _saturatedFat = State(initialValue: Self.nutrientString(food, names: ["Fatty acids, total saturated", "Saturated Fat"]) ?? "")
        _transFat = State(initialValue: Self.nutrientString(food, names: ["Fatty acids, total trans", "Trans Fat"]) ?? "")
        _cholesterol = State(initialValue: Self.nutrientString(food, names: ["Cholesterol"]) ?? "")
        _sodium = State(initialValue: Self.nutrientString(food, names: ["Sodium, Na", "Sodium"]) ?? "")
        _fiber = State(initialValue: Self.nutrientString(food, names: ["Fiber, total dietary", "Fiber"]) ?? "")
        _sugars = State(initialValue: Self.nutrientString(food, names: ["Sugars, total including NLEA", "Sugars"]) ?? "")
        _addedSugars = State(initialValue: Self.nutrientString(food, names: ["Sugars, added", "Added Sugars"]) ?? "")
        _vitaminD = State(initialValue: Self.nutrientString(food, names: ["Vitamin D (D2 + D3)", "Vitamin D"]) ?? "")
        _vitaminC = State(initialValue: Self.nutrientString(food, names: ["Vitamin C, total ascorbic acid", "Vitamin C"]) ?? "")
        _vitaminA = State(initialValue: Self.nutrientString(food, names: ["Vitamin A, RAE", "Vitamin A"]) ?? "")
        _calcium = State(initialValue: Self.nutrientString(food, names: ["Calcium, Ca", "Calcium"]) ?? "")
        _iron = State(initialValue: Self.nutrientString(food, names: ["Iron, Fe", "Iron"]) ?? "")
        _potassium = State(initialValue: Self.nutrientString(food, names: ["Potassium, K", "Potassium"]) ?? "")

        // Advanced - General
        _alcohol = State(initialValue: Self.nutrientString(food, names: ["Alcohol, ethyl"]) ?? "")
        _caffeine = State(initialValue: Self.nutrientString(food, names: ["Caffeine"]) ?? "")
        _choline = State(initialValue: Self.nutrientString(food, names: ["Choline, total"]) ?? "")
        _water = State(initialValue: Self.nutrientString(food, names: ["Water"]) ?? "")

        // Advanced - Fats
        _monoFat = State(initialValue: Self.nutrientString(food, names: ["Fatty acids, total monounsaturated"]) ?? "")
        _polyFat = State(initialValue: Self.nutrientString(food, names: ["Fatty acids, total polyunsaturated"]) ?? "")
        _omega3ALA = State(initialValue: Self.nutrientString(food, names: ["18:3 n-3 c,c,c (ALA)"]) ?? "")
        _omega3EPA = State(initialValue: Self.nutrientString(food, names: ["20:5 n-3 (EPA)"]) ?? "")
        _omega3DHA = State(initialValue: Self.nutrientString(food, names: ["22:6 n-3 (DHA)"]) ?? "")
        _omega3DPA = State(initialValue: Self.nutrientString(food, names: ["22:5 n-3 (DPA)"]) ?? "")

        // Advanced - Carbs
        _starch = State(initialValue: Self.nutrientString(food, names: ["Starch"]) ?? "")
        _sugarAlcohol = State(initialValue: Self.nutrientString(food, names: ["Sugar Alcohol"]) ?? "")

        // Advanced - Vitamins
        _vitaminE = State(initialValue: Self.nutrientString(food, names: ["Vitamin E (alpha-tocopherol)"]) ?? "")
        _vitaminK = State(initialValue: Self.nutrientString(food, names: ["Vitamin K (phylloquinone)"]) ?? "")
        _thiamin = State(initialValue: Self.nutrientString(food, names: ["Thiamin"]) ?? "")
        _riboflavin = State(initialValue: Self.nutrientString(food, names: ["Riboflavin"]) ?? "")
        _niacin = State(initialValue: Self.nutrientString(food, names: ["Niacin"]) ?? "")
        _pantothenicAcid = State(initialValue: Self.nutrientString(food, names: ["Pantothenic acid"]) ?? "")
        _vitaminB6 = State(initialValue: Self.nutrientString(food, names: ["Vitamin B-6"]) ?? "")
        _vitaminB12 = State(initialValue: Self.nutrientString(food, names: ["Vitamin B-12"]) ?? "")
        _folate = State(initialValue: Self.nutrientString(food, names: ["Folate, total"]) ?? "")
        _biotin = State(initialValue: Self.nutrientString(food, names: ["Biotin"]) ?? "")

        // Advanced - Minerals
        _magnesium = State(initialValue: Self.nutrientString(food, names: ["Magnesium, Mg"]) ?? "")
        _phosphorus = State(initialValue: Self.nutrientString(food, names: ["Phosphorus, P"]) ?? "")
        _zinc = State(initialValue: Self.nutrientString(food, names: ["Zinc, Zn"]) ?? "")
        _copper = State(initialValue: Self.nutrientString(food, names: ["Copper, Cu"]) ?? "")
        _manganese = State(initialValue: Self.nutrientString(food, names: ["Manganese, Mn"]) ?? "")
        _selenium = State(initialValue: Self.nutrientString(food, names: ["Selenium, Se"]) ?? "")
        _fluoride = State(initialValue: Self.nutrientString(food, names: ["Fluoride, F"]) ?? "")

        // Advanced - Amino Acids
        _histidine = State(initialValue: Self.nutrientString(food, names: ["Histidine"]) ?? "")
        _isoleucine = State(initialValue: Self.nutrientString(food, names: ["Isoleucine"]) ?? "")
        _leucine = State(initialValue: Self.nutrientString(food, names: ["Leucine"]) ?? "")
        _lysine = State(initialValue: Self.nutrientString(food, names: ["Lysine"]) ?? "")
        _methionine = State(initialValue: Self.nutrientString(food, names: ["Methionine"]) ?? "")
        _cysteine = State(initialValue: Self.nutrientString(food, names: ["Cystine", "Cysteine"]) ?? "")
        _phenylalanine = State(initialValue: Self.nutrientString(food, names: ["Phenylalanine"]) ?? "")
        _threonine = State(initialValue: Self.nutrientString(food, names: ["Threonine"]) ?? "")
        _tryptophan = State(initialValue: Self.nutrientString(food, names: ["Tryptophan"]) ?? "")
        _tyrosine = State(initialValue: Self.nutrientString(food, names: ["Tyrosine"]) ?? "")
        _valine = State(initialValue: Self.nutrientString(food, names: ["Valine"]) ?? "")
        _arginine = State(initialValue: Self.nutrientString(food, names: ["Arginine"]) ?? "")
        _alanine = State(initialValue: Self.nutrientString(food, names: ["Alanine"]) ?? "")
        _asparticAcid = State(initialValue: Self.nutrientString(food, names: ["Aspartic acid"]) ?? "")
        _glutamicAcid = State(initialValue: Self.nutrientString(food, names: ["Glutamic acid"]) ?? "")
        _glycine = State(initialValue: Self.nutrientString(food, names: ["Glycine"]) ?? "")
        _proline = State(initialValue: Self.nutrientString(food, names: ["Proline"]) ?? "")
        _serine = State(initialValue: Self.nutrientString(food, names: ["Serine"]) ?? "")
    }

    private static func nutrientString(_ food: Food, names: [String]) -> String? {
        for name in names {
            if let nutrient = food.foodNutrients.first(where: { $0.nutrientName.lowercased() == name.lowercased() }),
               let value = nutrient.value, value > 0 {
                return value == floor(value) ? String(format: "%.0f", value) : String(format: "%.1f", value)
            }
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            List {
                // Basic Info Section
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Required", text: $name)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Brand")
                        Spacer()
                        TextField("Optional", text: $brand)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Nutrition Values Section
                Section {
                    // Based on row
                    HStack {
                        Text("Based on")
                        Spacer()
                        Menu {
                            ForEach(NutritionBasis.allCases, id: \.self) { basis in
                                Button(basis.rawValue) {
                                    basedOn = basis
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(basedOn.rawValue)
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

                    // Weight/Volume row
                    HStack {
                        Text(basedOn.weightLabel)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField(basedOn.unitSuffix, text: $weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            if !weight.isEmpty {
                                Text(basedOn.unitSuffix)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Serving Size row with chips
                    HStack {
                        Text("Serving Size")

                        Spacer()

                        HStack(spacing: 6) {
                            TextField("1", text: $servingAmount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .frame(width: 50)
                                .background(
                                    Capsule().fill(chipColor)
                                )
                                .font(.system(size: 15))
                                .fixedSize()

                            TextField("serving", text: $servingUnit)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    Capsule().fill(chipColor)
                                )
                                .font(.system(size: 15))
                                .fixedSize()
                        }
                    }
                } header: {
                    Text("Nutrition Values")
                }

                // Segmented Picker
                HStack {
                    Picker("", selection: $selectedTab) {
                        ForEach(NutritionTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 22, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Content based on tab
                switch selectedTab {
                case .standard:
                    standardSections
                case .advanced:
                    advancedSections
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .contentMargins(.top, 4, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(mode == .editInPlace ? "Edit Food" : "Edit a Copy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveChanges()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                        }
                    }
                    .tint(.accentColor)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .disabled(name.isEmpty || calories.isEmpty || isSubmitting)
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
            nutrientRow(label: "Calcium", unit: "mg", text: $calcium)
            nutrientRow(label: "Iron", unit: "mg", text: $iron)
            nutrientRow(label: "Potassium", unit: "mg", text: $potassium)
            nutrientRow(label: "Vitamin C", unit: "mg", text: $vitaminC)
            vitaminRowWithUnitPicker(label: "Vitamin D", text: $vitaminD, unit: $vitaminDUnit)
            vitaminRowWithUnitPicker(label: "Vitamin A", text: $vitaminA, unit: $vitaminAUnit)
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

        // Vitamins Section
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

    // MARK: - Save Changes

    private func saveChanges() {
        isSubmitting = true

        let updatedFood = buildFood()

        switch mode {
        case .editInPlace:
            // Update existing food definition
            foodManager.updateFood(food: updatedFood) { result in
                isSubmitting = false

                switch result {
                case .success(let savedFood):
                    onFoodUpdated?(savedFood)
                    dismiss()
                case .failure(let error):
                    print("❌ Failed to update food: \(error.localizedDescription)")
                }
            }

        case .editACopy:
            // Create new user food (copy)
            foodManager.createManualFood(food: updatedFood, showPreview: false) { result in
                isSubmitting = false

                switch result {
                case .success(let newFood):
                    onFoodUpdated?(newFood)
                    dismiss()
                case .failure(let error):
                    print("❌ Failed to create food copy: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Build Food Object

    private func buildFood() -> Food {
        var nutrients: [Nutrient] = []

        func addNutrient(_ name: String, _ value: String, _ unit: String) {
            guard !value.isEmpty, let numericValue = Double(value.replacingOccurrences(of: ",", with: ".")) else { return }
            nutrients.append(Nutrient(nutrientName: name, value: numericValue, unitName: unit))
        }

        func addVitamin(_ name: String, _ value: String, unit: VitaminUnit, type: VitaminType, baseUnit: String) {
            guard !value.isEmpty, let numericValue = Double(value.replacingOccurrences(of: ",", with: ".")) else { return }
            let convertedValue = type.toBaseUnit(numericValue, from: unit)
            nutrients.append(Nutrient(nutrientName: name, value: convertedValue, unitName: baseUnit))
        }

        // Standard nutrients
        addNutrient("Energy", calories, "kcal")
        addNutrient("Protein", protein, "g")
        addNutrient("Carbohydrate, by difference", carbs, "g")
        addNutrient("Total lipid (fat)", fat, "g")
        addNutrient("Fatty acids, total saturated", saturatedFat, "g")
        addNutrient("Fatty acids, total trans", transFat, "g")
        addNutrient("Cholesterol", cholesterol, "mg")
        addNutrient("Sodium, Na", sodium, "mg")
        addNutrient("Fiber, total dietary", fiber, "g")
        addNutrient("Sugars, total including NLEA", sugars, "g")
        addNutrient("Sugars, added", addedSugars, "g")
        addNutrient("Calcium, Ca", calcium, "mg")
        addNutrient("Iron, Fe", iron, "mg")
        addNutrient("Potassium, K", potassium, "mg")
        addNutrient("Vitamin C, total ascorbic acid", vitaminC, "mg")

        // Vitamins with IU conversion
        addVitamin("Vitamin D (D2 + D3)", vitaminD, unit: vitaminDUnit, type: .vitaminD, baseUnit: "mcg")
        addVitamin("Vitamin A, RAE", vitaminA, unit: vitaminAUnit, type: .vitaminA, baseUnit: "mcg")
        addVitamin("Vitamin E (alpha-tocopherol)", vitaminE, unit: vitaminEUnit, type: .vitaminE, baseUnit: "mg")

        // Advanced - General
        addNutrient("Alcohol, ethyl", alcohol, "g")
        addNutrient("Caffeine", caffeine, "mg")
        addNutrient("Choline, total", choline, "mg")
        addNutrient("Water", water, "g")

        // Advanced - Fats
        addNutrient("Fatty acids, total monounsaturated", monoFat, "g")
        addNutrient("Fatty acids, total polyunsaturated", polyFat, "g")
        addNutrient("18:3 n-3 c,c,c (ALA)", omega3ALA, "g")
        addNutrient("20:5 n-3 (EPA)", omega3EPA, "g")
        addNutrient("22:6 n-3 (DHA)", omega3DHA, "g")
        addNutrient("22:5 n-3 (DPA)", omega3DPA, "g")

        // Advanced - Carbs
        addNutrient("Starch", starch, "g")
        addNutrient("Sugar Alcohol", sugarAlcohol, "g")

        // Advanced - Vitamins
        addNutrient("Vitamin K (phylloquinone)", vitaminK, "mcg")
        addNutrient("Thiamin", thiamin, "mg")
        addNutrient("Riboflavin", riboflavin, "mg")
        addNutrient("Niacin", niacin, "mg")
        addNutrient("Pantothenic acid", pantothenicAcid, "mg")
        addNutrient("Vitamin B-6", vitaminB6, "mg")
        addNutrient("Vitamin B-12", vitaminB12, "mcg")
        addNutrient("Folate, total", folate, "mcg")
        addNutrient("Biotin", biotin, "mcg")

        // Advanced - Minerals
        addNutrient("Magnesium, Mg", magnesium, "mg")
        addNutrient("Phosphorus, P", phosphorus, "mg")
        addNutrient("Zinc, Zn", zinc, "mg")
        addNutrient("Copper, Cu", copper, "mg")
        addNutrient("Manganese, Mn", manganese, "mg")
        addNutrient("Selenium, Se", selenium, "mcg")
        addNutrient("Fluoride, F", fluoride, "mcg")

        // Advanced - Amino Acids
        addNutrient("Histidine", histidine, "g")
        addNutrient("Isoleucine", isoleucine, "g")
        addNutrient("Leucine", leucine, "g")
        addNutrient("Lysine", lysine, "g")
        addNutrient("Methionine", methionine, "g")
        addNutrient("Cystine", cysteine, "g")
        addNutrient("Phenylalanine", phenylalanine, "g")
        addNutrient("Threonine", threonine, "g")
        addNutrient("Tryptophan", tryptophan, "g")
        addNutrient("Tyrosine", tyrosine, "g")
        addNutrient("Valine", valine, "g")
        addNutrient("Arginine", arginine, "g")
        addNutrient("Alanine", alanine, "g")
        addNutrient("Aspartic acid", asparticAcid, "g")
        addNutrient("Glutamic acid", glutamicAcid, "g")
        addNutrient("Glycine", glycine, "g")
        addNutrient("Proline", proline, "g")
        addNutrient("Serine", serine, "g")

        // Build serving description
        let servingQty = Double(servingAmount.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        let servingText = "\(servingAmount) \(servingUnit)"
        let weightGrams = Double(weight.replacingOccurrences(of: ",", with: "."))

        // Create a measure for this food
        let measureId = Int.random(in: 100_000...999_999)
        let measure = FoodMeasure(
            disseminationText: servingText,
            gramWeight: weightGrams ?? 0,
            id: measureId,
            modifier: servingText,
            measureUnitName: servingUnit,
            rank: 1
        )

        // Get resolved brand
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBrand = trimmedBrand.isEmpty ? nil : trimmedBrand

        // Generate new ID for copy mode, keep existing for edit-in-place
        let foodId = mode == .editACopy
            ? Int.random(in: 10_000_000...99_999_999)
            : food.fdcId

        return Food(
            fdcId: foodId,
            description: name,
            brandOwner: resolvedBrand,
            brandName: resolvedBrand,
            servingSize: servingQty,
            numberOfServings: 1,
            servingSizeUnit: servingUnit,
            householdServingFullText: servingText,
            foodNutrients: nutrients,
            foodMeasures: [measure],
            healthAnalysis: nil,
            aiInsight: nil,
            nutritionScore: nil,
            mealItems: nil
        )
    }
}

#Preview {
    EditFoodSheet(
        food: Food(
            fdcId: 123456,
            description: "Test Food",
            brandOwner: "Test Brand",
            brandName: "Test Brand",
            servingSize: 100,
            numberOfServings: 1,
            servingSizeUnit: "g",
            householdServingFullText: "1 serving",
            foodNutrients: [
                Nutrient(nutrientName: "Energy", value: 200, unitName: "kcal"),
                Nutrient(nutrientName: "Protein", value: 10, unitName: "g"),
                Nutrient(nutrientName: "Carbohydrate, by difference", value: 20, unitName: "g"),
                Nutrient(nutrientName: "Total lipid (fat)", value: 5, unitName: "g")
            ],
            foodMeasures: [],
            healthAnalysis: nil,
            aiInsight: nil,
            nutritionScore: nil,
            mealItems: nil
        )
    )
    .environmentObject(FoodManager())
}
