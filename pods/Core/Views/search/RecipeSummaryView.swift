//
//  RecipeSummaryView.swift
//  pods
//
//  Created by Dimi Nunez on 12/18/25.
//


//
//  RecipeSummaryView.swift
//  pods
//
//  Created by Dimi Nunez on 12/18/25.
//

import SwiftUI

struct RecipeSummaryView: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var foodManager: FoodManager

    // Servings state
    @State private var servings: Double = 1.0
    @State private var servingsInput: String = "1"

    // UI state
    @State private var isLogging = false
    @State private var selectedMealPeriod: MealPeriod = .lunch
    @State private var mealTime: Date = Date()
    @State private var showMealTimePicker = false

    // Computed values
    private var scaledCalories: Double { recipe.calories * servings }
    private var scaledProtein: Double { recipe.protein * servings }
    private var scaledCarbs: Double { recipe.carbs * servings }
    private var scaledFat: Double { recipe.fat * servings }

    // Aggregated nutrients from all recipe items (vitamins, minerals, etc.)
    private var aggregatedNutrients: [String: (value: Double, unit: String)] {
        var result: [String: (value: Double, unit: String)] = [:]
        for item in recipe.recipeItems {
            guard let nutrients = item.foodNutrients else { continue }
            for nutrient in nutrients {
                let key = normalizedNutrientKey(nutrient.nutrientName)
                let value = (nutrient.value ?? 0) * servings
                if let existing = result[key] {
                    result[key] = (value: existing.value + value, unit: existing.unit)
                } else {
                    result[key] = (value: value, unit: nutrient.unitName ?? "")
                }
            }
        }
        return result
    }

    // Fiber value for net carbs calculation
    private var fiberValue: Double {
        let keys = ["fiber, total dietary", "dietary fiber", "fiber"]
        for key in keys {
            if let val = aggregatedNutrients[normalizedNutrientKey(key)]?.value, val > 0 {
                return val
            }
        }
        return 0
    }

    // Check if we have any micronutrient data
    private var hasNutrientData: Bool {
        !aggregatedNutrients.isEmpty
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("bg") : Color(UIColor.systemGroupedBackground)
    }

    private var cardColor: Color {
        colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color("bg")
    }

    private var chipColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Recipe info card
                        recipeInfoCard

                        // Serving selector
                        servingSelector

                        // Meal time selector
                        mealTimeSelector

                        // Macro summary
                        macroSummaryCard

                        // Detailed nutrient sections (when data is available)
                        if hasNutrientData {
                            nutrientSectionsCard
                        }

                        // Recipe items list
                        if !recipe.recipeItems.isEmpty {
                            recipeItemsSection
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }

                footerBar
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Log Recipe")
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
            .onAppear {
                selectedMealPeriod = suggestedMealPeriod(for: Date())
            }
        }
    }

    // MARK: - Recipe Info Card

    private var recipeInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            if let description = recipe.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                if let prepTime = recipe.prepTime, prepTime > 0 {
                    Label("\(prepTime) min prep", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let cookTime = recipe.cookTime, cookTime > 0 {
                    Label("\(cookTime) min cook", systemImage: "flame")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if recipe.servings > 0 {
                    Label("\(recipe.servings) servings", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let link = recipe.link, !link.isEmpty {
                HStack {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Imported recipe")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    // MARK: - Serving Selector

    private var servingSelector: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Servings")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 8) {
                    // Decrease button
                    Button {
                        if servings > 0.5 {
                            servings = max(servings - 0.5, 0.5)
                            servingsInput = formatServings(servings)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(servings <= 0.5 ? .secondary : .primary)
                    }
                    .disabled(servings <= 0.5)

                    // Input field
                    TextField("1", text: $servingsInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(chipColor)
                        .cornerRadius(8)
                        .onChange(of: servingsInput) { _, newValue in
                            if let parsed = parseServings(newValue) {
                                servings = parsed
                            }
                        }

                    // Increase button
                    Button {
                        servings += 0.5
                        servingsInput = formatServings(servings)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    // MARK: - Meal Time Selector

    private var mealTimeSelector: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Time")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 12) {
                    Menu {
                        ForEach(MealPeriod.allCases) { period in
                            Button(period.title) {
                                selectedMealPeriod = period
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedMealPeriod.title)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Capsule().fill(chipColor))
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showMealTimePicker.toggle()
                        }
                    } label: {
                        Text(relativeDayAndTimeString(for: mealTime))
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Capsule().fill(chipColor))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)

            if showMealTimePicker {
                DatePicker("",
                           selection: $mealTime,
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    // MARK: - Macro Summary Card

    private var macroSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    macroRow(title: "Protein", value: scaledProtein, unit: "g", color: Color("protein"))
                    Divider()
                    macroRow(title: "Fat", value: scaledFat, unit: "g", color: Color("fat"))
                    Divider()
                    macroRow(title: "Carbs", value: scaledCarbs, unit: "g", color: Color("carbs"))
                }

                Spacer()

                // Calorie ring
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 8)

                    VStack(spacing: -4) {
                        Text("\(Int(scaledCalories))")
                            .font(.system(size: 20, weight: .medium))
                        Text("cals")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 100, height: 100)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardColor)
            )
        }
        .padding(.horizontal)
    }

    private func macroRow(title: String, value: Double, unit: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Text("\(Int(value))\(unit)")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Nutrient Sections Card

    private var nutrientSectionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Nutrition")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                nutrientSection(title: "Carbohydrates", rows: NutrientDescriptors.totalCarbRows, color: NutrientDescriptors.carbColor)
                nutrientSection(title: "Fats", rows: NutrientDescriptors.fatRows, color: NutrientDescriptors.fatColor)
                nutrientSection(title: "Protein & Amino Acids", rows: NutrientDescriptors.proteinRows, color: NutrientDescriptors.proteinColor)
                nutrientSection(title: "Vitamins", rows: NutrientDescriptors.vitaminRows, color: .orange)
                nutrientSection(title: "Minerals", rows: NutrientDescriptors.mineralRows, color: .blue)
                nutrientSection(title: "Other", rows: NutrientDescriptors.otherRows, color: .purple)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardColor)
            )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func nutrientSection(title: String, rows: [NutrientRowDescriptor], color: Color) -> some View {
        let filteredRows = rows.filter { descriptor in
            switch descriptor.source {
            case .macro, .computed:
                return true
            case .nutrient(let names, _):
                return names.contains { name in
                    aggregatedNutrients[normalizedNutrientKey(name)] != nil
                }
            }
        }

        if !filteredRows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                ForEach(filteredRows) { descriptor in
                    nutrientRow(for: descriptor)
                }
            }
        }
    }

    private func nutrientRow(for descriptor: NutrientRowDescriptor) -> some View {
        let value = nutrientValue(for: descriptor)
        let unit = descriptor.defaultUnit

        return HStack {
            Text(descriptor.label)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text(formatNutrientValue(value, unit: unit))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func nutrientValue(for descriptor: NutrientRowDescriptor) -> Double {
        switch descriptor.source {
        case .macro(let macro):
            switch macro {
            case .protein: return scaledProtein
            case .carbs: return scaledCarbs
            case .fat: return scaledFat
            }
        case .nutrient(let names, let aggregation):
            let matches = names.compactMap { aggregatedNutrients[normalizedNutrientKey($0)] }
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
                return max(scaledCarbs - fiberValue, 0)
            case .calories:
                return scaledCalories
            }
        }
    }

    private func formatNutrientValue(_ value: Double, unit: String) -> String {
        if value < 1 && value > 0 {
            return String(format: "%.1f %@", value, unit)
        } else {
            return "\(Int(value.rounded())) \(unit)"
        }
    }

    // MARK: - Recipe Items Section

    private var recipeItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(recipe.recipeItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)

                            Text("\(Int(item.calories * servings)) cal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if let servingText = item.servingText {
                            Text(servingText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(chipColor)
                                .cornerRadius(6)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardColor)
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            Button(action: {
                HapticFeedback.generateLigth()
                logRecipe()
            }) {
                Text(isLogging ? "Logging..." : "Log Recipe")
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
            .disabled(isLogging)
            .opacity(isLogging ? 0.7 : 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            backgroundColor
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Actions

    private func logRecipe() {
        isLogging = true

        // Calculate scaled calories based on servings
        let logCalories = scaledCalories

        foodManager.logRecipe(
            recipe: recipe,
            mealTime: selectedMealPeriod.rawValue.capitalized,
            date: mealTime,
            notes: nil,
            calories: logCalories
        ) { result in
            DispatchQueue.main.async {
                isLogging = false
                switch result {
                case .success:
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToTimeline"), object: nil)
                    dismiss()
                case .failure(let error):
                    print("Failed to log recipe: \(error)")
                    dismiss()
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatServings(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func parseServings(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    private func suggestedMealPeriod(for date: Date) -> MealPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<21: return .dinner
        default: return .snack
        }
    }

    private func relativeDayAndTimeString(for date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Today, \(timeString)"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(timeString)"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow, \(timeString)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "MMM d"
            return "\(dayFormatter.string(from: date)), \(timeString)"
        }
    }
}

#Preview {
    RecipeSummaryView(recipe: Recipe(
        id: 1,
        title: "Chicken Stir Fry",
        description: "A healthy and delicious stir fry",
        instructions: "Cook chicken, add vegetables, serve",
        link: nil,
        privacy: "private",
        servings: 4,
        createdAt: Date(),
        updatedAt: nil,
        recipeItems: [],
        image: nil,
        prepTime: 15,
        cookTime: 20,
        totalCalories: 450,
        totalProtein: 35,
        totalCarbs: 30,
        totalFat: 15,
        scheduledAt: nil
    ))
    .environmentObject(FoodManager())
}
