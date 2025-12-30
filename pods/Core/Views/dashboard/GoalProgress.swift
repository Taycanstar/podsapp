//
//  GoalProgress.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/25.
//

import SwiftUI
import UIKit

// MARK: - Ring Segment

struct RingSegment: View {
    let start, percent: Double
    let color: Color

    var body: some View {
        Circle()
            .trim(from: start, to: start + percent)
            .stroke(color, style: .init(lineWidth: 12, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

// MARK: - Macro Type and Input Mode

fileprivate enum MacroType: String, CaseIterable, Identifiable {
    case protein, carbs, fat
    var id: String { rawValue }
}

fileprivate enum MacroInputMode: String, CaseIterable, Identifiable {
    case grams, percent
    var id: String { rawValue }
    var label: String { self == .grams ? "Grams" : "%" }
}

// MARK: - Nutrient Item for Advanced Section

private struct NutrientItem: Identifiable {
    let slug: String
    let label: String
    let unit: String
    let defaultTarget: Double?
    let note: String?

    var id: String { slug }

    init(slug: String, label: String, unit: String, defaultTarget: Double? = nil, note: String? = nil) {
        self.slug = slug
        self.label = label
        self.unit = unit
        self.defaultTarget = defaultTarget
        self.note = note
    }
}

// MARK: - GoalProgress View

struct GoalProgress: View {
    @EnvironmentObject var vm: DayLogsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isTabBarVisible) private var isTabBarVisible

    // Macro colors from asset catalog
    private let proteinColor = Color("protein")
    private let carbsColor = Color("carbs")
    private let fatColor = Color("fat")

    // State to hold temporary values while editing
    @State private var calorieGoal: String = ""
    @State private var proteinGoal: String = ""
    @State private var carbsGoal: String = ""
    @State private var fatGoal: String = ""
    @State private var currentGoals: NutritionGoals?

    // Advanced nutrient editing state
    @State private var showAdvancedNutrients = false
    @State private var editingValues: [String: String] = [:]
    @State private var removedOverrides: Set<String> = []

    @State private var isSubmitting = false
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showResetConfirmation = false

    // State for macro picker sheet
    @State private var showMacroPickerSheet = false

    // Unit preferences for water and vitamins
    @State private var waterUnit: WaterUnit = .milliliters
    @State private var vitaminAUnit: VitaminUnit = .mcg
    @State private var vitaminDUnit: VitaminUnit = .mcg
    @State private var vitaminEUnit: VitaminUnit = .mcg

    // Computed properties for goal macro calories
    private var proteinCals: Double {
        (Double(proteinGoal) ?? vm.proteinGoal) * 4
    }

    private var carbCals: Double {
        (Double(carbsGoal) ?? vm.carbsGoal) * 4
    }

    private var fatCals: Double {
        (Double(fatGoal) ?? vm.fatGoal) * 9
    }

    private var macroCals: Double {
        proteinCals + carbCals + fatCals
    }

    // Calculate percentages for ring segments based on goal calories
    private var totalGoalCalories: Double {
        max(Double(calorieGoal) ?? vm.calorieGoal, 1)
    }

    // Helper function to ensure percentages add up to exactly 100%
    private func adjustedPercentages() -> (protein: Double, carbs: Double, fat: Double) {
        let exactProtein = proteinCals / totalGoalCalories
        let exactCarbs = carbCals / totalGoalCalories
        let exactFat = fatCals / totalGoalCalories

        var roundedProtein = round(exactProtein * 100)
        var roundedCarbs = round(exactCarbs * 100)
        var roundedFat = round(exactFat * 100)

        let total = roundedProtein + roundedCarbs + roundedFat
        let difference = 100 - total

        if difference != 0 {
            let proteinRemainder = (exactProtein * 100) - roundedProtein
            let carbsRemainder = (exactCarbs * 100) - roundedCarbs
            let fatRemainder = (exactFat * 100) - roundedFat

            var remainders = [
                (proteinRemainder, 0),
                (carbsRemainder, 1),
                (fatRemainder, 2)
            ]
            remainders.sort { $0.0 > $1.0 }

            for i in 0..<abs(Int(difference)) {
                let macroIndex = remainders[i % 3].1
                if difference > 0 {
                    switch macroIndex {
                    case 0: roundedProtein += 1
                    case 1: roundedCarbs += 1
                    case 2: roundedFat += 1
                    default: break
                    }
                } else {
                    switch macroIndex {
                    case 0: roundedProtein -= 1
                    case 1: roundedCarbs -= 1
                    case 2: roundedFat -= 1
                    default: break
                    }
                }
            }
        }

        return (
            protein: roundedProtein / 100.0,
            carbs: roundedCarbs / 100.0,
            fat: roundedFat / 100.0
        )
    }

    private var proteinPercent: Double {
        adjustedPercentages().protein
    }

    private var carbPercent: Double {
        adjustedPercentages().carbs
    }

    private var fatPercent: Double {
        adjustedPercentages().fat
    }

    // MARK: - Grouped Nutrients for Advanced Section

    private var groupedNutrients: [(key: String, label: String, rows: [NutrientItem])] {
        guard let nutrientDict = currentGoals?.nutrients else { return [] }

        // Exclude macros category since calories, protein, carbs, fat are handled in general content
        let categoryOrder = ["carbohydrates", "fats", "amino_acids", "vitamins", "minerals", "hydration", "other"]

        var grouped: [String: [NutrientItem]] = [:]
        for (slug, details) in nutrientDict {
            let category = details.category ?? "other"
            // Skip macros category - already handled in general content
            guard category != "macros" else { continue }
            let item = NutrientItem(
                slug: slug,
                label: details.label ?? slug.replacingOccurrences(of: "_", with: " ").capitalized,
                unit: details.unit ?? "",
                defaultTarget: details.defaultTarget,
                note: details.note
            )
            grouped[category, default: []].append(item)
        }

        // Sort items within each category by display order
        for (category, _) in grouped {
            grouped[category]?.sort { a, b in
                let aOrder = nutrientDict[a.slug]?.displayOrder ?? Int.max
                let bOrder = nutrientDict[b.slug]?.displayOrder ?? Int.max
                return aOrder < bOrder
            }
        }

        // Build result with category labels
        return grouped
            .map { key, rows -> (String, String, [NutrientItem]) in
                let label = nutrientDict.values.first { $0.category == key }?.categoryLabel ?? key.replacingOccurrences(of: "_", with: " ").capitalized
                return (key, label, rows)
            }
            .sorted { lhs, rhs in
                let lhsIndex = categoryOrder.firstIndex(of: lhs.0) ?? categoryOrder.count
                let rhsIndex = categoryOrder.firstIndex(of: rhs.0) ?? categoryOrder.count
                return lhsIndex < rhsIndex
            }
    }

    private var hasAdvancedNutrients: Bool {
        !groupedNutrients.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            List {
                // General Content (always shown)
                generalContent

                // Show More Nutrients Button
                if hasAdvancedNutrients {
                    Section {
                        Button {
                            withAnimation {
                                showAdvancedNutrients.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: showAdvancedNutrients ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(showAdvancedNutrients ? "Hide Advanced Nutrients" : "Show More Nutrients")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.blue)
                        }
                    }
                }

                // Advanced Nutrients (shown when expanded)
                if showAdvancedNutrients {
                    advancedContent
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollDismissesKeyboard(.interactively)

            // Bottom button
            generateGoalsButton
                .background(
                    Color("iosbg")
                        .ignoresSafeArea(edges: .bottom)
                )
        }
        .background(Color("iosbg").ignoresSafeArea())
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog("Reset all overrides and return to defaults?", isPresented: $showResetConfirmation) {
            Button("Reset All Targets", role: .destructive) {
                saveGoals(clearAll: true)
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationTitle("Update Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if !isSubmitting {
                        saveGoals()
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)
            }
        }
        .sheet(isPresented: $showMacroPickerSheet) {
            MacroPickerSheet(
                proteinGoal: $proteinGoal,
                carbsGoal: $carbsGoal,
                fatGoal: $fatGoal,
                calorieGoal: $calorieGoal,
                isPresented: $showMacroPickerSheet,
                vmCalorieGoal: vm.calorieGoal,
                vm: vm
            )
            .presentationDetents(UIDevice.current.userInterfaceIdiom == .pad ? [.large] : [.fraction(0.45)])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            isTabBarVisible.wrappedValue = false
            loadGoalsFromUserDefaults()
            initializeAdvancedValues()
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
        }
    }

    // MARK: - General Content

    @ViewBuilder
    private var generalContent: some View {
        // Calories Section
        Section {
            HStack {
                Text("Daily Calories")
                Spacer()
                TextField("2000", text: $calorieGoal)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                Text("kcal")
                    .foregroundColor(.secondary)
            }
        }

        // Macro Ring Section
        Section {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                    RingSegment(
                        start: 0,
                        percent: proteinPercent,
                        color: proteinColor
                    )

                    RingSegment(
                        start: proteinPercent,
                        percent: carbPercent,
                        color: carbsColor
                    )

                    RingSegment(
                        start: proteinPercent + carbPercent,
                        percent: fatPercent,
                        color: fatColor
                    )

                    VStack(spacing: 0) {
                        Text("\(Int(macroCals))")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("cals")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 120, height: 120)
                .frame(maxWidth: .infinity, alignment: .center)

                // Macro legend
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(proteinColor)
                                .frame(width: 10, height: 10)
                            Text("Protein")
                                .font(.system(size: 13))
                        }
                        Text("\(Int(proteinCals)) cal")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(carbsColor)
                                .frame(width: 10, height: 10)
                            Text("Carbs")
                                .font(.system(size: 13))
                        }
                        Text("\(Int(carbCals)) cal")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(fatColor)
                                .frame(width: 10, height: 10)
                            Text("Fat")
                                .font(.system(size: 13))
                        }
                        Text("\(Int(fatCals)) cal")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }

        // Macronutrients Section
        Section {
            Button {
                showMacroPickerSheet = true
            } label: {
                HStack {
                    Text("Protein")
                        .foregroundColor(.primary)
                    Text(String(format: "%d%%", Int(proteinPercent * 100)))
                        .foregroundColor(proteinColor)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("\(proteinGoal)g")
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            Button {
                showMacroPickerSheet = true
            } label: {
                HStack {
                    Text("Carbs")
                        .foregroundColor(.primary)
                    Text(String(format: "%d%%", Int(carbPercent * 100)))
                        .foregroundColor(carbsColor)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("\(carbsGoal)g")
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            Button {
                showMacroPickerSheet = true
            } label: {
                HStack {
                    Text("Fat")
                        .foregroundColor(.primary)
                    Text(String(format: "%d%%", Int(fatPercent * 100)))
                        .foregroundColor(fatColor)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("\(fatGoal)g")
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Macronutrients")
        } footer: {
            Text("Tap to adjust macro distribution")
        }
    }

    // MARK: - Advanced Content

    @ViewBuilder
    private var advancedContent: some View {
        ForEach(groupedNutrients, id: \.key) { group in
            Section(header: Text(group.label)) {
                ForEach(group.rows) { item in
                    nutrientRow(for: item)
                }
            }
        }

        // Reset All button at bottom of advanced section
        Section {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Reset All to Defaults")
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                }
            }
            .disabled(isSubmitting)
        }
    }

    // MARK: - Nutrient Row (NutritionFactsView style)

    private func nutrientRow(for item: NutrientItem) -> some View {
        let binding = Binding<String>(
            get: { editingValues[item.slug] ?? "" },
            set: { newValue in
                editingValues[item.slug] = newValue
                if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    removedOverrides.insert(item.slug)
                } else {
                    removedOverrides.remove(item.slug)
                }
            }
        )

        // Handle special cases for water and vitamins with unit pickers
        switch item.slug {
        case "water":
            return AnyView(waterRowWithUnitPicker(text: binding))
        case "vitamin_a":
            return AnyView(vitaminRowWithUnitPicker(label: item.label, text: binding, unit: $vitaminAUnit, vitaminType: .vitaminA))
        case "vitamin_d":
            return AnyView(vitaminRowWithUnitPicker(label: item.label, text: binding, unit: $vitaminDUnit, vitaminType: .vitaminD))
        case "vitamin_e":
            return AnyView(vitaminRowWithUnitPicker(label: item.label, text: binding, unit: $vitaminEUnit, vitaminType: .vitaminE))
        default:
            return AnyView(
                HStack {
                    Text(item.label)
                    Spacer()
                    TextField("0", text: binding)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(item.unit)
                        .foregroundColor(.secondary)
                }
            )
        }
    }

    // MARK: - Water Row with Unit Picker

    private func waterRowWithUnitPicker(text: Binding<String>) -> some View {
        HStack {
            Text("Water")
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Menu {
                ForEach(WaterUnit.allCases) { unitOption in
                    Button(unitOption.displayName) {
                        // Convert value when unit changes
                        if let currentValue = Double(text.wrappedValue.replacingOccurrences(of: ",", with: ".")) {
                            // Convert current unit to US fl oz, then to new unit
                            let usOz = waterUnit.convertToUSFluidOunces(currentValue)
                            let newValue = unitOption.convertFromUSFluidOunces(usOz)
                            text.wrappedValue = unitOption.format(newValue)
                        }
                        waterUnit = unitOption
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(waterUnit.abbreviation)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Vitamin Row with Unit Picker

    private func vitaminRowWithUnitPicker(
        label: String,
        text: Binding<String>,
        unit: Binding<VitaminUnit>,
        vitaminType: VitaminType
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Menu {
                ForEach(VitaminUnit.allCases) { unitOption in
                    Button(unitOption.rawValue) {
                        // Convert value when unit changes
                        if let currentValue = Double(text.wrappedValue.replacingOccurrences(of: ",", with: ".")) {
                            // Convert current value to base unit, then to new unit
                            let baseValue = vitaminType.toBaseUnit(currentValue, from: unit.wrappedValue)
                            let newValue = vitaminType.fromBaseUnit(baseValue, to: unitOption)
                            text.wrappedValue = String(format: "%.1f", newValue)
                        }
                        unit.wrappedValue = unitOption
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(unit.wrappedValue.rawValue)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Generate Goals Button

    private var generateGoalsButton: some View {
        Button(action: {
            guard !isGenerating else { return }
            generateGoals()
        }) {
            Group {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Generate Personalized Goals")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isGenerating ? Color.gray : Color("background"))
            .foregroundColor(isGenerating ? Color.white : Color("bg"))
            .cornerRadius(999)
        }
        .disabled(isGenerating)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    // MARK: - Helper Functions

    private func formatValue(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.01 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func initializeAdvancedValues() {
        guard let goals = currentGoals else { return }

        // Start with default targets from nutrients
        var values: [String: String] = [:]
        if let nutrients = goals.nutrients {
            for (slug, details) in nutrients {
                // Use override target if present, otherwise use default target
                var baseValue: Double?
                if let overrideTarget = goals.overrides?[slug]?.target {
                    baseValue = overrideTarget
                } else if let defaultTarget = details.target ?? details.defaultTarget {
                    baseValue = defaultTarget
                }

                guard let value = baseValue else { continue }

                // Convert from base unit to display unit for special cases
                let displayValue: Double
                switch slug {
                case "vitamin_a":
                    displayValue = VitaminType.vitaminA.fromBaseUnit(value, to: vitaminAUnit)
                case "vitamin_d":
                    displayValue = VitaminType.vitaminD.fromBaseUnit(value, to: vitaminDUnit)
                case "vitamin_e":
                    displayValue = VitaminType.vitaminE.fromBaseUnit(value, to: vitaminEUnit)
                case "water":
                    // Convert from ml to display unit
                    let usOz = value / 29.5735295625 // Convert ml to US fl oz
                    displayValue = waterUnit.convertFromUSFluidOunces(usOz)
                default:
                    displayValue = value
                }

                values[slug] = formatValue(displayValue)
            }
        }
        editingValues = values
    }

    private func persist(goals: NutritionGoals) {
        currentGoals = goals
        vm.calorieGoal = goals.calories
        vm.proteinGoal = goals.protein
        vm.carbsGoal = goals.carbs
        vm.fatGoal = goals.fat
        vm.remainingCalories = max(0, goals.calories - vm.totalCalories)
        calorieGoal = String(Int(round(goals.calories)))
        proteinGoal = String(Int(round(goals.protein)))
        carbsGoal = String(Int(round(goals.carbs)))
        fatGoal = String(Int(round(goals.fat)))

        NutritionGoalsStore.shared.cache(goals: goals)
        UserDefaults.standard.set(goals.calories, forKey: "dailyCalorieGoal")
        UserGoalsManager.shared.dailyGoals = DailyGoals(
            calories: Int(goals.calories),
            protein: Int(goals.protein),
            carbs: Int(goals.carbs),
            fat: Int(goals.fat)
        )
        NotificationCenter.default.post(name: NSNotification.Name("LogsChangedNotification"), object: nil)

        // Reinitialize advanced values after persist
        initializeAdvancedValues()
    }

    private func loadGoalsFromUserDefaults() {
        if let goals = NutritionGoalsStore.shared.cachedGoals ??
            {
                guard let data = UserDefaults.standard.data(forKey: "nutritionGoalsData") else { return nil }
                return try? JSONDecoder().decode(NutritionGoals.self, from: data)
            }() {

            currentGoals = goals
            calorieGoal = String(Int(round(goals.calories)))
            proteinGoal = String(Int(round(goals.protein)))
            carbsGoal = String(Int(round(goals.carbs)))
            fatGoal = String(Int(round(goals.fat)))

            vm.calorieGoal = goals.calories
            vm.proteinGoal = goals.protein
            vm.carbsGoal = goals.carbs
            vm.fatGoal = goals.fat

        } else {
            let userGoals = UserGoalsManager.shared.dailyGoals

            calorieGoal = String(userGoals.calories)
            proteinGoal = String(userGoals.protein)
            carbsGoal = String(userGoals.carbs)
            fatGoal = String(userGoals.fat)

            vm.calorieGoal = Double(userGoals.calories)
            vm.proteinGoal = Double(userGoals.protein)
            vm.carbsGoal = Double(userGoals.carbs)
            vm.fatGoal = Double(userGoals.fat)
            currentGoals = nil
        }

        vm.remainingCalories = max(0, vm.calorieGoal - vm.totalCalories)
    }

    // MARK: - Save Goals

    private func saveGoals(clearAll: Bool = false) {
        guard let calories = Double(calorieGoal),
              let protein = Double(proteinGoal),
              let carbs = Double(carbsGoal),
              let fat = Double(fatGoal),
              calories > 0 else {
            errorMessage = "Please enter valid values for all fields"
            showError = true
            return
        }

        isSubmitting = true

        var overridesPayload: [String: GoalOverridePayload] = [:]

        if !clearAll {
            // Always include main macros
            overridesPayload["calories"] = GoalOverridePayload(min: nil, target: calories, max: nil)
            overridesPayload["protein"] = GoalOverridePayload(min: nil, target: protein, max: nil)
            overridesPayload["carbs"] = GoalOverridePayload(min: nil, target: carbs, max: nil)
            overridesPayload["fat"] = GoalOverridePayload(min: nil, target: fat, max: nil)

            // Include any advanced nutrient overrides
            for (slug, value) in editingValues {
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                if let number = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
                    // Convert vitamins from display unit to base unit
                    let convertedValue: Double
                    switch slug {
                    case "vitamin_a":
                        convertedValue = VitaminType.vitaminA.toBaseUnit(number, from: vitaminAUnit)
                    case "vitamin_d":
                        convertedValue = VitaminType.vitaminD.toBaseUnit(number, from: vitaminDUnit)
                    case "vitamin_e":
                        convertedValue = VitaminType.vitaminE.toBaseUnit(number, from: vitaminEUnit)
                    case "water":
                        // Convert water to ml (base unit stored in backend)
                        let usOz = waterUnit.convertToUSFluidOunces(number)
                        convertedValue = usOz * 29.5735295625 // US fl oz to ml
                    default:
                        convertedValue = number
                    }
                    overridesPayload[slug] = GoalOverridePayload(min: nil, target: convertedValue, max: nil)
                }
            }
        }

        let removals = clearAll ? [] : Array(removedOverrides)

        NetworkManagerTwo.shared.updateNutritionGoals(
            userEmail: vm.email,
            overrides: overridesPayload,
            removeOverrides: removals,
            clearAll: clearAll
        ) { result in
            isSubmitting = false

            switch result {
            case .success(let response):
                if clearAll {
                    editingValues = [:]
                    removedOverrides.removeAll()
                }
                persist(goals: response.goals)
                if !clearAll {
                    dismiss()
                }

            case .failure(let error):
                if let networkError = error as? NetworkManagerTwo.NetworkError {
                    errorMessage = networkError.localizedDescription
                } else {
                    errorMessage = error.localizedDescription
                }
                showError = true
            }
        }
    }

    // MARK: - Generate Goals

    private func generateGoals() {
        isGenerating = true

        NetworkManagerTwo.shared.generateNutritionGoals(
            userEmail: vm.email
        ) { result in
            isGenerating = false

            switch result {
            case .success(let response):
                persist(goals: response.goals)

            case .failure(let error):
                if let networkError = error as? NetworkManagerTwo.NetworkError {
                    errorMessage = networkError.localizedDescription
                } else {
                    errorMessage = error.localizedDescription
                }
                showError = true
            }
        }
    }
}

// MARK: - MacroPickerSheet

struct MacroPickerSheet: View {
    @Binding var proteinGoal: String
    @Binding var carbsGoal: String
    @Binding var fatGoal: String
    @Binding var calorieGoal: String
    @Binding var isPresented: Bool
    let vmCalorieGoal: Double
    @ObservedObject var vm: DayLogsViewModel

    // Macro colors from asset catalog
    private let proteinColor = Color("protein")
    private let carbsColor = Color("carbs")
    private let fatColor = Color("fat")

    @State private var inputMode: MacroInputMode = .grams
    @State private var proteinValue: Double = 0
    @State private var carbsValue: Double = 0
    @State private var fatValue: Double = 0

    private var totalCalories: Double {
        let parsedCalories = Double(calorieGoal) ?? 0
        let actualCalories = parsedCalories > 0 ? parsedCalories : vmCalorieGoal
        return max(actualCalories, 1)
    }

    private func adjustedPickerPercentages() -> (protein: Double, carbs: Double, fat: Double) {
        let exactProtein = (proteinValue * 4) / totalCalories * 100
        let exactCarbs = (carbsValue * 4) / totalCalories * 100
        let exactFat = (fatValue * 9) / totalCalories * 100

        var roundedProtein = round(exactProtein)
        var roundedCarbs = round(exactCarbs)
        var roundedFat = round(exactFat)

        let total = roundedProtein + roundedCarbs + roundedFat
        let difference = 100 - total

        if difference != 0 {
            let proteinRemainder = exactProtein - roundedProtein
            let carbsRemainder = exactCarbs - roundedCarbs
            let fatRemainder = exactFat - roundedFat

            var remainders = [
                (proteinRemainder, 0),
                (carbsRemainder, 1),
                (fatRemainder, 2)
            ]
            remainders.sort { $0.0 > $1.0 }

            for i in 0..<abs(Int(difference)) {
                let macroIndex = remainders[i % 3].1
                if difference > 0 {
                    switch macroIndex {
                    case 0: roundedProtein += 1
                    case 1: roundedCarbs += 1
                    case 2: roundedFat += 1
                    default: break
                    }
                } else {
                    switch macroIndex {
                    case 0: roundedProtein -= 1
                    case 1: roundedCarbs -= 1
                    case 2: roundedFat -= 1
                    default: break
                    }
                }
            }
        }

        return (protein: roundedProtein, carbs: roundedCarbs, fat: roundedFat)
    }

    private var proteinPercent: Double {
        adjustedPickerPercentages().protein
    }

    private var carbsPercent: Double {
        adjustedPickerPercentages().carbs
    }

    private var fatPercent: Double {
        adjustedPickerPercentages().fat
    }

    private var totalMacroCalories: Double {
        (proteinValue * 4) + (carbsValue * 4) + (fatValue * 9)
    }

    private var percentagesValid: Bool {
        if inputMode == .percent {
            let total = proteinPercent + carbsPercent + fatPercent
            return abs(total - 100) < 1.0
        }
        return true
    }

    private func percentLabel(_ value: Int, selected: Int) -> String {
        if inputMode == .percent {
            return value == selected ? "\(value) %" : "\(value)  "
        } else {
            return "\(value)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.primary)
                }

                Spacer()

                Picker("Input Mode", selection: $inputMode) {
                    Text("%").tag(MacroInputMode.percent)
                    Text("Grams").tag(MacroInputMode.grams)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 150)

                Spacer()

                Button(action: {
                    proteinGoal = String(Int(proteinValue))
                    carbsGoal = String(Int(carbsValue))
                    fatGoal = String(Int(fatValue))

                    if inputMode == .grams {
                        let newCalories = Int(totalMacroCalories)
                        calorieGoal = String(newCalories)
                    }

                    isPresented = false
                }) {
                    Image(systemName: "checkmark")
                        .font(.title2)
                        .foregroundColor(percentagesValid ? .primary : .gray)
                }
                .disabled(!percentagesValid)
            }
            .padding()

            // Macro labels
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Carbs")
                        .font(.system(size: 14))
                        .foregroundColor(carbsColor)

                    if inputMode == .percent {
                        Text("\(Int(carbsValue))g")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    } else {
                        Text("\(Int(carbsPercent)) %")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("Protein")
                        .font(.system(size: 14))
                        .foregroundColor(proteinColor)

                    if inputMode == .percent {
                        Text("\(Int(proteinValue))g")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    } else {
                        Text("\(Int(proteinPercent)) %")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("Fat")
                        .font(.system(size: 14))
                        .foregroundColor(fatColor)

                    if inputMode == .percent {
                        Text("\(Int(fatValue))g")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    } else {
                        Text("\(Int(fatPercent)) %")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom)

            // Three column wheel layout
            HStack(spacing: 0) {
                // Carbs Column
                VStack {
                    Picker("Carbs", selection: Binding(
                        get: { inputMode == .grams ? Int(carbsValue) : Int(carbsPercent) },
                        set: { newValue in
                            if inputMode == .grams {
                                carbsValue = Double(newValue)
                            } else {
                                let newCarbsPercent = Double(newValue)
                                let remainingPercent = 100 - newCarbsPercent
                                let currentProteinAndFat = proteinPercent + fatPercent

                                if currentProteinAndFat > 0 && remainingPercent > 0 {
                                    let proteinRatio = proteinPercent / currentProteinAndFat
                                    let fatRatio = fatPercent / currentProteinAndFat

                                    let newProteinPercent = remainingPercent * proteinRatio
                                    let newFatPercent = remainingPercent * fatRatio

                                    proteinValue = (newProteinPercent * totalCalories) / 4.0 / 100
                                    fatValue = (newFatPercent * totalCalories) / 9.0 / 100
                                }
                                carbsValue = (newCarbsPercent * totalCalories) / 4.0 / 100
                            }
                        }
                    )) {
                        ForEach(0...(inputMode == .grams ? 500 : 100), id: \.self) { value in
                            Text(percentLabel(value, selected: inputMode == .grams ? Int(carbsValue) : Int(carbsPercent)))
                                .font(.title3)
                                .frame(width: 60, alignment: .center)
                                .tag(value)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 150)
                }
                .frame(maxWidth: .infinity)

                // Protein Column
                VStack {
                    Picker("Protein", selection: Binding(
                        get: { inputMode == .grams ? Int(proteinValue) : Int(proteinPercent) },
                        set: { newValue in
                            if inputMode == .grams {
                                proteinValue = Double(newValue)
                            } else {
                                let newProteinPercent = Double(newValue)
                                let remainingPercent = 100 - newProteinPercent
                                let currentCarbsAndFat = carbsPercent + fatPercent

                                if currentCarbsAndFat > 0 && remainingPercent > 0 {
                                    let carbsRatio = carbsPercent / currentCarbsAndFat
                                    let fatRatio = fatPercent / currentCarbsAndFat

                                    let newCarbsPercent = remainingPercent * carbsRatio
                                    let newFatPercent = remainingPercent * fatRatio

                                    carbsValue = (newCarbsPercent * totalCalories) / 4.0 / 100
                                    fatValue = (newFatPercent * totalCalories) / 9.0 / 100
                                }
                                proteinValue = (newProteinPercent * totalCalories) / 4.0 / 100
                            }
                        }
                    )) {
                        ForEach(0...(inputMode == .grams ? 500 : 100), id: \.self) { value in
                            Text(percentLabel(value, selected: inputMode == .grams ? Int(proteinValue) : Int(proteinPercent)))
                                .font(.title3)
                                .frame(width: 60, alignment: .center)
                                .tag(value)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 150)
                }
                .frame(maxWidth: .infinity)

                // Fat Column
                VStack {
                    Picker("Fat", selection: Binding(
                        get: { inputMode == .grams ? Int(fatValue) : Int(fatPercent) },
                        set: { newValue in
                            if inputMode == .grams {
                                fatValue = Double(newValue)
                            } else {
                                let newFatPercent = Double(newValue)
                                let remainingPercent = 100 - newFatPercent
                                let currentProteinAndCarbs = proteinPercent + carbsPercent

                                if currentProteinAndCarbs > 0 && remainingPercent > 0 {
                                    let proteinRatio = proteinPercent / currentProteinAndCarbs
                                    let carbsRatio = carbsPercent / currentProteinAndCarbs

                                    let newProteinPercent = remainingPercent * proteinRatio
                                    let newCarbsPercent = remainingPercent * carbsRatio

                                    proteinValue = (newProteinPercent * totalCalories) / 4.0 / 100
                                    carbsValue = (newCarbsPercent * totalCalories) / 4.0 / 100
                                }
                                fatValue = (newFatPercent * totalCalories) / 9.0 / 100
                            }
                        }
                    )) {
                        ForEach(0...(inputMode == .grams ? 300 : 100), id: \.self) { value in
                            Text(percentLabel(value, selected: inputMode == .grams ? Int(fatValue) : Int(fatPercent)))
                                .font(.title3)
                                .frame(width: 60, alignment: .center)
                                .tag(value)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 150)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)

            Spacer().frame(height: 12)

            if inputMode == .percent && !percentagesValid {
                Text("Macronutrients must equal 100 %")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }

            VStack(spacing: 2) {
                if inputMode == .grams {
                    Text("\(Int(totalMacroCalories)) cal")
                        .font(.system(size: 22))
                        .fontWeight(.semibold)
                    Text("Changing grams will update your calorie goal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(Int(totalCalories)) cal")
                        .font(.system(size: 22))
                        .fontWeight(.semibold)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .onAppear {
            let vmProtein = vm.proteinGoal
            let vmCarbs = vm.carbsGoal
            let vmFat = vm.fatGoal

            proteinValue = max(Double(proteinGoal) ?? vmProtein, 0)
            carbsValue = max(Double(carbsGoal) ?? vmCarbs, 0)
            fatValue = max(Double(fatGoal) ?? vmFat, 0)
        }
    }
}

#Preview {
    NavigationStack {
        GoalProgress()
            .environmentObject(DayLogsViewModel())
    }
}
