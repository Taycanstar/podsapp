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
    var onLogMeal: ([Food], [MealItem]) -> Void = { _, _ in }
    var onAddToPlate: ([Food], [MealItem]) -> Void = { _, _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel

    @State private var selectedFood: Food?
    @State private var selectedMealPeriod: MealPeriod = .lunch
    @State private var mealTime: Date = Date()
    @State private var showMealTimePicker = false
    @State private var isLogging = false
    @State private var nutrientTargets: [String: NutrientTargetDetails] = NutritionGoalsStore.shared.currentTargets
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared

    /// Editable state for each meal item (keyed by item ID string)
    @State private var editableItems: [String: MealEditableItem] = [:]

    /// Mutable copy of meal items for deletion support
    @State private var editableMealItems: [MealItem] = []

    private var plateBackground: Color {
        colorScheme == .dark ? Color("bg") : Color(UIColor.systemGroupedBackground)
    }
    private var cardColor: Color {
        colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color("bg")
    }
    private var chipColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }

    // MARK: - Computed Macros
    private var totalMacros: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        var cals: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0

        // Use editable items to get scaled values (from editableMealItems for deletion support)
        for item in editableMealItems {
            let scalingFactor = editableItems[item.id.uuidString]?.scalingFactor ?? 1.0
            cals += (item.calories) * scalingFactor
            protein += (item.protein) * scalingFactor
            carbs += (item.carbs) * scalingFactor
            fat += (item.fat) * scalingFactor
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

    private var macroArcs: [MealMacroArc] {
        let proteinCalories = totalMacros.protein * 4
        let carbCalories = totalMacros.carbs * 4
        let fatCalories = totalMacros.fat * 9
        let total = max(proteinCalories + carbCalories + fatCalories, 1)
        let segments = [
            (color: Color("protein"), fraction: proteinCalories / total),
            (color: Color("fat"), fraction: fatCalories / total),
            (color: Color("carbs"), fraction: carbCalories / total)
        ]
        var running: Double = 0
        return segments.map { segment in
            let arc = MealMacroArc(start: running, end: running + segment.fraction, color: segment.color)
            running += segment.fraction
            return arc
        }
    }

    private var proteinGoalPercent: Double {
        guard dayLogsVM.proteinGoal > 0 else { return 0 }
        return (totalMacros.protein / dayLogsVM.proteinGoal) * 100
    }

    private var fatGoalPercent: Double {
        guard dayLogsVM.fatGoal > 0 else { return 0 }
        return (totalMacros.fat / dayLogsVM.fatGoal) * 100
    }

    private var carbGoalPercent: Double {
        guard dayLogsVM.carbsGoal > 0 else { return 0 }
        return (totalMacros.carbs / dayLogsVM.carbsGoal) * 100
    }

    // Aggregate nutrients from all foods
    private var aggregatedNutrients: [String: RawNutrientValue] {
        var result: [String: RawNutrientValue] = [:]
        for food in foods {
            for nutrient in food.foodNutrients {
                let key = normalizedNutrientKey(nutrient.nutrientName)
                let value = nutrient.value ?? 0
                if let existing = result[key] {
                    result[key] = RawNutrientValue(value: existing.value + value, unit: existing.unit)
                } else {
                    result[key] = RawNutrientValue(value: value, unit: nutrient.unitName)
                }
            }
        }
        return result
    }

    private func normalizedNutrientKey(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var fiberValue: Double {
        let keys = ["fiber, total dietary", "dietary fiber", "fiber"]
        for key in keys {
            if let val = aggregatedNutrients[key]?.value, val > 0 {
                return val
            }
        }
        return 0
    }

    private var shouldShowGoalsLoader: Bool {
        if case .loading = goalsStore.state { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    mealItemsSection
                    macroSummaryCard
                    mealTimeSelector
                    dailyGoalShareCard
                    if !mealItems.isEmpty || !foods.isEmpty {
                        if shouldShowGoalsLoader {
                            goalsLoadingView
                        } else if nutrientTargets.isEmpty {
                            missingTargetsCallout
                        } else {
                            totalCarbsSection
                            fatTotalsSection
                            proteinTotalsSection
                            vitaminSection
                            mineralSection
                            otherNutrientSection
                        }
                    }
                    Spacer(minLength: 20)
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }

            footerBar
        }
        .background(plateBackground.ignoresSafeArea())
        .navigationTitle("My Meal")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationDestination(item: $selectedFood) { food in
            FoodSummaryView(food: food)
        }
        .onAppear {
            // Set meal period based on current time
            selectedMealPeriod = suggestedMealPeriod(for: Date())
            reloadStoredNutrientTargets()
            initializeEditableItems()
        }
        .onReceive(dayLogsVM.$nutritionGoalsVersion) { _ in
            reloadStoredNutrientTargets()
        }
        .onReceive(goalsStore.$state) { _ in
            reloadStoredNutrientTargets()
        }
    }

    private func reloadStoredNutrientTargets() {
        nutrientTargets = NutritionGoalsStore.shared.currentTargets
    }

    private func initializeEditableItems() {
        // Initialize mutable copy of meal items
        if editableMealItems.isEmpty {
            editableMealItems = mealItems
        }

        guard editableItems.isEmpty else { return }

        // Initialize editable state for each meal item
        for item in mealItems {
            editableItems[item.id.uuidString] = MealEditableItem(from: item)
        }
    }

    private func deleteMealItem(_ item: MealItem) {
        editableMealItems.removeAll { $0.id == item.id }
        editableItems.removeValue(forKey: item.id.uuidString)
    }

    /// Create a binding for an editable item at a given ID
    private func editableItemBinding(for itemId: String) -> Binding<MealEditableItem> {
        Binding(
            get: {
                editableItems[itemId] ?? MealEditableItem(
                    servingAmount: 1,
                    servingAmountInput: "1",
                    selectedMeasureId: nil,
                    measures: [],
                    baselineServing: 1
                )
            },
            set: { newValue in
                editableItems[itemId] = newValue
            }
        )
    }

    // MARK: - Meal Items Section
    private var mealItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Items")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if editableMealItems.isEmpty && foods.isEmpty {
                Text("No meal items found")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else if !editableMealItems.isEmpty {
                // Use List for swipe-to-delete support
                List {
                    ForEach(editableMealItems) { item in
                        MealEditableItemRow(
                            item: item,
                            editableItem: editableItemBinding(for: item.id.uuidString),
                            cardColor: cardColor,
                            chipColor: chipColor,
                            onTap: {
                                if let food = foodForMealItemById(item.id.uuidString) {
                                    selectedFood = food
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteMealItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet.sorted(by: >) {
                            if index < editableMealItems.count {
                                let item = editableMealItems[index]
                                deleteMealItem(item)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(minHeight: CGFloat(editableMealItems.count) * 100)
            } else {
                // Fallback to static rows for foods without meal items
                VStack(spacing: 12) {
                    ForEach(mealItemsFromFoodsOrFallback, id: \.id) { item in
                        Button {
                            if let food = foodForMealItem(item) {
                                selectedFood = food
                            }
                        } label: {
                            MealItemRow(item: item, cardColor: cardColor, chipColor: chipColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Macro Summary Card
    private var macroSummaryCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                macroStatRow(title: "Protein", value: totalMacros.protein, unit: "g", color: Color("protein"))
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Fat", value: totalMacros.fat, unit: "g", color: Color("fat"))
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Carbs", value: totalMacros.carbs, unit: "g", color: Color("carbs"))
            }

            Spacer()

            MealMacroRingView(calories: totalMacros.calories, arcs: macroArcs)
                .frame(width: 100, height: 100)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    private func macroStatRow(title: String, value: Double, unit: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(title.capitalized)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Text("\(value.cleanOneDecimal)\(unit)")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Meal Time Selector
    private var mealTimeSelector: some View {
        VStack(spacing: 0) {
            labeledRow("Time", verticalPadding: 10) {
                HStack(spacing: 16) {
                    Menu {
                        ForEach(MealPeriod.allCases) { period in
                            Button(period.title) {
                                selectedMealPeriod = period
                            }
                        }
                    } label: {
                        capsulePill {
                            HStack(spacing: 4) {
                                Text(selectedMealPeriod.title)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .menuIndicator(.hidden)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showMealTimePicker.toggle()
                        }
                    } label: {
                        Text(relativeDayAndTimeString(for: mealTime))
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(chipColor)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

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
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    // MARK: - Daily Goal Share Card
    private var dailyGoalShareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Goal Share")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                MealGoalShareBubble(title: "Protein",
                                percent: proteinGoalPercent,
                                grams: totalMacros.protein,
                                goal: dayLogsVM.proteinGoal,
                                color: Color("protein"))
                MealGoalShareBubble(title: "Fat",
                                percent: fatGoalPercent,
                                grams: totalMacros.fat,
                                goal: dayLogsVM.fatGoal,
                                color: Color("fat"))
                MealGoalShareBubble(title: "Carbs",
                                percent: carbGoalPercent,
                                grams: totalMacros.carbs,
                                goal: dayLogsVM.carbsGoal,
                                color: Color("carbs"))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(cardColor)
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            HStack(spacing: 12) {
                Button(action: {
                    HapticFeedback.generateLigth()
                    isLogging = true
                    onLogMeal(foods, editableMealItems)
                }) {
                    Text(isLogging ? "Logging..." : "Log Meal")
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
                .disabled(isLogging || (editableMealItems.isEmpty && foods.isEmpty))
                .opacity(isLogging ? 0.7 : 1)

                Button(action: {
                    HapticFeedback.generateLigth()
                    onAddToPlate(foods, editableMealItems)
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
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Helper Views
    private func labeledRow(_ title: String,
                            verticalPadding: CGFloat = 10,
                            @ViewBuilder content: () -> some View) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            content()
        }
        .padding(.vertical, verticalPadding)
    }

    private func capsulePill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(chipColor)
            )
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

    private func suggestedMealPeriod(for date: Date) -> MealPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return .breakfast
        case 11..<15:
            return .lunch
        case 15..<21:
            return .dinner
        default:
            return .snack
        }
    }

    // MARK: - Data Helpers
    private var mealItemsFromFoodsOrFallback: [MealItemListDisplay] {
        if !mealItems.isEmpty {
            return mealItems.map {
                MealItemListDisplay(
                    id: $0.id.uuidString,
                    name: $0.name,
                    brand: nil,
                    servingText: servingDescription(for: $0),
                    calories: $0.calories ?? 0,
                    protein: $0.protein ?? 0,
                    carbs: $0.carbs ?? 0,
                    fat: $0.fat ?? 0
                )
            }
        }

        return foods.map { food in
            MealItemListDisplay(
                id: String(food.id),
                name: food.displayName,
                brand: food.brandText,
                servingText: food.servingSizeText,
                calories: food.calories ?? 0,
                protein: food.protein ?? 0,
                carbs: food.carbs ?? 0,
                fat: food.fat ?? 0
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

    private func foodForMealItem(_ item: MealItemListDisplay) -> Food? {
        if let match = foods.first(where: { $0.displayName == item.name }) {
            return match
        }
        return foods.first
    }

    private func foodForMealItemById(_ itemId: String) -> Food? {
        // Try to find a matching food by name from the mealItems
        if let mealItem = mealItems.first(where: { $0.id.uuidString == itemId }) {
            if let match = foods.first(where: { $0.displayName == mealItem.name }) {
                return match
            }
        }
        return foods.first
    }

    // MARK: - Nutrient Sections

    private var totalCarbsSection: some View {
        nutrientSection(title: "Total Carbs", rows: MealNutrientDescriptors.totalCarbRows)
    }

    private var fatTotalsSection: some View {
        nutrientSection(title: "Total Fat", rows: MealNutrientDescriptors.fatRows)
    }

    private var proteinTotalsSection: some View {
        nutrientSection(title: "Total Protein", rows: MealNutrientDescriptors.proteinRows)
    }

    private var vitaminSection: some View {
        nutrientSection(title: "Vitamins", rows: MealNutrientDescriptors.vitaminRows)
    }

    private var mineralSection: some View {
        nutrientSection(title: "Minerals", rows: MealNutrientDescriptors.mineralRows)
    }

    private var otherNutrientSection: some View {
        nutrientSection(title: "Other", rows: MealNutrientDescriptors.otherRows)
    }

    private var goalsLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView("Syncing your targets…")
                .progressViewStyle(CircularProgressViewStyle())
            Text("Hang tight while we fetch your personalized nutrient plan.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    private var missingTargetsCallout: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finish goal setup to unlock detailed targets")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("We'll automatically sync your nutrition plan and show daily percentages once it's ready.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button(action: {
                dayLogsVM.refreshNutritionGoals(forceRefresh: true)
            }) {
                HStack {
                    if dayLogsVM.isRefreshingNutritionGoals {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                    Text(dayLogsVM.isRefreshingNutritionGoals ? "Syncing Targets" : "Sync Now")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(dayLogsVM.isRefreshingNutritionGoals ? 0.4 : 0.15))
                .foregroundColor(.accentColor)
                .cornerRadius(12)
            }
            .disabled(dayLogsVM.isRefreshingNutritionGoals)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    private func nutrientSection(title: String, rows: [MealNutrientRowDescriptor]) -> some View {
        // Filter rows to only show nutrients that exist in the data
        // Zero values ARE shown (e.g., 0g sugar means sugar-free)
        // Only nutrients completely absent from the response are hidden
        let filteredRows = rows.filter { descriptor in
            switch descriptor.source {
            case .macro, .computed:
                // Always show macros and computed values (e.g., net carbs, calories)
                return true
            case .nutrient(let names, _):
                // Show if the nutrient exists in the data (even if value is 0)
                return names.contains { name in
                    aggregatedNutrients[normalizedNutrientKey(name)] != nil
                }
            }
        }

        // Don't render empty sections
        return Group {
            if !filteredRows.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(spacing: 16) {
                        ForEach(filteredRows) { descriptor in
                            nutrientRow(for: descriptor)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(cardColor)
                    )
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func nutrientRow(for descriptor: MealNutrientRowDescriptor) -> some View {
        let value = nutrientValue(for: descriptor)
        let goal = nutrientGoal(for: descriptor)
        let unit = nutrientUnit(for: descriptor)
        let percentage = nutrientPercentage(value: value, goal: goal)
        let ratio = nutrientRatioText(value: value, goal: goal, unit: unit)
        let progress = nutrientProgressValue(value: value, goal: goal)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(ratio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(percentage)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(descriptor.color)
            }

            ProgressView(value: progress)
                .tint(descriptor.color)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
        }
    }

    private func nutrientValue(for descriptor: MealNutrientRowDescriptor) -> Double {
        switch descriptor.source {
        case .macro(let macro):
            switch macro {
            case .protein: return totalMacros.protein
            case .carbs: return totalMacros.carbs
            case .fat: return totalMacros.fat
            }
        case .nutrient(let names, let aggregation):
            let matches = names.compactMap { aggregatedNutrients[normalizedNutrientKey($0)] }
            guard !matches.isEmpty else { return 0 }
            let perServing: Double
            switch aggregation {
            case .first:
                perServing = matches.first?.value ?? 0
            case .sum:
                perServing = matches.reduce(0) { $0 + $1.value }
            }
            let sourceUnit = matches.first?.unit
            let targetUnit = nutrientUnit(for: descriptor)
            return convert(perServing, from: sourceUnit, to: targetUnit)
        case .computed(let computation):
            switch computation {
            case .netCarbs:
                return max(totalMacros.carbs - fiberValue, 0)
            case .calories:
                return totalMacros.calories
            }
        }
    }

    private func nutrientGoal(for descriptor: MealNutrientRowDescriptor) -> Double? {
        var resolvedGoal: Double?
        if let slug = descriptor.slug,
           let details = nutrientTargets[slug] {
            if let target = details.target, target > 0 {
                resolvedGoal = target
            } else if let max = details.max, max > 0 {
                resolvedGoal = max
            } else if let idealMax = details.idealMax, idealMax > 0 {
                resolvedGoal = idealMax
            }
        }
        if let resolvedGoal {
            return convertGoal(resolvedGoal, for: descriptor)
        }

        switch descriptor.source {
        case .macro(let macro):
            switch macro {
            case .protein: return dayLogsVM.proteinGoal
            case .carbs: return dayLogsVM.carbsGoal
            case .fat: return dayLogsVM.fatGoal
            }
        case .computed(let computation):
            switch computation {
            case .calories:
                return dayLogsVM.calorieGoal
            case .netCarbs:
                if let target = nutrientTargets["net_carbs"]?.target {
                    return convertGoal(target, for: descriptor)
                }
                return nil
            }
        default:
            return nil
        }
    }

    private func nutrientUnit(for descriptor: MealNutrientRowDescriptor) -> String {
        if descriptor.defaultUnit.isEmpty,
           let slug = descriptor.slug,
           let unit = nutrientTargets[slug]?.unit,
           !unit.isEmpty {
            return unit
        }
        return descriptor.defaultUnit
    }

    private func nutrientPercentage(value: Double, goal: Double?) -> String {
        guard let goal, goal > 0 else { return "--" }
        let percent = (value / goal) * 100
        return "\(percent.cleanZeroDecimal)%"
    }

    private func nutrientProgressValue(value: Double, goal: Double?) -> Double {
        guard let goal, goal > 0 else { return 0 }
        return min(max(value / goal, 0), 1)
    }

    private func nutrientRatioText(value: Double, goal: Double?, unit: String) -> String {
        let valueText = value.goalShareFormatted
        let goalText = goal.map { $0.goalShareFormatted } ?? "--"
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUnit.isEmpty {
            return "\(valueText)/\(goalText)"
        } else {
            return "\(valueText)/\(goalText) \(trimmedUnit)"
        }
    }

    private func convert(_ value: Double, from sourceUnit: String?, to targetUnit: String) -> Double {
        guard let sourceUnit, !sourceUnit.isEmpty else { return value }
        let src = sourceUnit.lowercased()
        let dst = targetUnit.lowercased()
        if src == dst { return value }

        // mg <-> g conversion
        if src == "mg" && dst == "g" {
            return value / 1000
        }
        if src == "g" && dst == "mg" {
            return value * 1000
        }
        // mcg <-> mg conversion
        if src == "µg" || src == "mcg" {
            if dst == "mg" { return value / 1000 }
            if dst == "g" { return value / 1_000_000 }
        }
        if (src == "mg" || src == "g") && (dst == "µg" || dst == "mcg") {
            if src == "mg" { return value * 1000 }
            if src == "g" { return value * 1_000_000 }
        }
        return value
    }

    private func convertGoal(_ goal: Double, for descriptor: MealNutrientRowDescriptor) -> Double {
        guard let slug = descriptor.slug,
              let storedUnit = nutrientTargets[slug]?.unit,
              !storedUnit.isEmpty else { return goal }
        let src = storedUnit.lowercased()
        let dst = descriptor.defaultUnit.lowercased()
        if src == dst { return goal }

        // Same conversion as convert()
        if src == "mg" && dst == "g" { return goal / 1000 }
        if src == "g" && dst == "mg" { return goal * 1000 }
        if (src == "µg" || src == "mcg") && dst == "mg" { return goal / 1000 }
        if (src == "µg" || src == "mcg") && dst == "g" { return goal / 1_000_000 }
        if src == "mg" && (dst == "µg" || dst == "mcg") { return goal * 1000 }
        if src == "g" && (dst == "µg" || dst == "mcg") { return goal * 1_000_000 }

        return goal
    }
}

// MARK: - Nutrient Row Descriptor

private enum MealMacroType {
    case protein, carbs, fat
}

private enum MealNutrientAggregation {
    case first, sum
}

private enum MealNutrientComputation {
    case netCarbs, calories
}

private enum MealNutrientSource {
    case macro(MealMacroType)
    case nutrient(names: [String], aggregation: MealNutrientAggregation = .first)
    case computed(MealNutrientComputation)
}

private struct MealNutrientRowDescriptor: Identifiable {
    let id = UUID()
    let label: String
    let slug: String?
    let defaultUnit: String
    let source: MealNutrientSource
    let color: Color
}

private enum MealNutrientDescriptors {
    static let proteinColor = Color("protein")
    static let fatColor = Color("fat")
    static let carbColor = Color("carbs")

    static var totalCarbRows: [MealNutrientRowDescriptor] {
        [
            MealNutrientRowDescriptor(label: "Carbs", slug: "carbs", defaultUnit: "g", source: .macro(.carbs), color: carbColor),
            MealNutrientRowDescriptor(label: "Fiber", slug: "fiber", defaultUnit: "g", source: .nutrient(names: ["fiber, total dietary", "dietary fiber"]), color: carbColor),
            MealNutrientRowDescriptor(label: "Net (Non-fiber)", slug: "net_carbs", defaultUnit: "g", source: .computed(.netCarbs), color: carbColor),
            MealNutrientRowDescriptor(label: "Sugars", slug: "sugars", defaultUnit: "g", source: .nutrient(names: ["sugars, total including nlea", "sugars, total", "sugar"]), color: carbColor),
            MealNutrientRowDescriptor(label: "Sugars Added", slug: "added_sugars", defaultUnit: "g", source: .nutrient(names: ["sugars, added", "added sugars"]), color: carbColor)
        ]
    }

    static var fatRows: [MealNutrientRowDescriptor] {
        [
            MealNutrientRowDescriptor(label: "Fat", slug: "fat", defaultUnit: "g", source: .macro(.fat), color: fatColor),
            MealNutrientRowDescriptor(label: "Monounsaturated", slug: "monounsaturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total monounsaturated"]), color: fatColor),
            MealNutrientRowDescriptor(label: "Polyunsaturated", slug: "polyunsaturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total polyunsaturated"]), color: fatColor),
            MealNutrientRowDescriptor(label: "Omega-3", slug: "omega_3_total", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total n-3", "omega 3", "omega-3"]), color: fatColor),
            MealNutrientRowDescriptor(label: "Omega-3 ALA", slug: "omega_3_ala", defaultUnit: "g", source: .nutrient(names: ["18:3 n-3 c,c,c (ala)", "alpha-linolenic acid", "omega-3 ala", "omega 3 ala"]), color: fatColor),
            MealNutrientRowDescriptor(label: "Omega-3 EPA", slug: "omega_3_epa_dha", defaultUnit: "mg", source: .nutrient(names: ["20:5 n-3 (epa)", "22:6 n-3 (dha)", "epa", "dha", "eicosapentaenoic acid", "docosahexaenoic acid", "omega-3 epa + dha"], aggregation: .sum), color: fatColor),
            MealNutrientRowDescriptor(label: "Omega-6", slug: "omega_6", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total n-6", "omega 6", "omega-6"]), color: fatColor),
            MealNutrientRowDescriptor(label: "Saturated", slug: "saturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total saturated"]), color: fatColor),
            MealNutrientRowDescriptor(label: "Trans Fat", slug: "trans_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total trans"]), color: fatColor)
        ]
    }

    static var proteinRows: [MealNutrientRowDescriptor] {
        [
            MealNutrientRowDescriptor(label: "Protein", slug: "protein", defaultUnit: "g", source: .macro(.protein), color: proteinColor),
            MealNutrientRowDescriptor(label: "Cysteine", slug: "cysteine", defaultUnit: "mg", source: .nutrient(names: ["cysteine", "cystine"]), color: proteinColor),
            MealNutrientRowDescriptor(label: "Histidine", slug: "histidine", defaultUnit: "mg", source: .nutrient(names: ["histidine"]), color: proteinColor),
            MealNutrientRowDescriptor(label: "Isoleucine", slug: "isoleucine", defaultUnit: "mg", source: .nutrient(names: ["isoleucine"]), color: proteinColor),
            MealNutrientRowDescriptor(label: "Leucine", slug: "leucine", defaultUnit: "mg", source: .nutrient(names: ["leucine"]), color: proteinColor),
            MealNutrientRowDescriptor(label: "Lysine", slug: "lysine", defaultUnit: "mg", source: .nutrient(names: ["lysine"]), color: proteinColor),
            MealNutrientRowDescriptor(label: "Methionine", slug: "methionine", defaultUnit: "mg", source: .nutrient(names: ["methionine"]), color: proteinColor),
            MealNutrientRowDescriptor(label: "Phenylalanine", slug: "phenylalanine", defaultUnit: "mg", source: .nutrient(names: ["phenylalanine"]), color: proteinColor),
            MealNutrientRowDescriptor(label: "Threonine", slug: "threonine", defaultUnit: "mg", source: .nutrient(names: ["threonine"]), color: proteinColor),
            MealNutrientRowDescriptor(label: "Tryptophan", slug: "tryptophan", defaultUnit: "mg", source: .nutrient(names: ["tryptophan"]), color: proteinColor),
            MealNutrientRowDescriptor(label: "Tyrosine", slug: "tyrosine", defaultUnit: "mg", source: .nutrient(names: ["tyrosine"]), color: proteinColor),
            MealNutrientRowDescriptor(label: "Valine", slug: "valine", defaultUnit: "mg", source: .nutrient(names: ["valine"]), color: proteinColor)
        ]
    }

    static var vitaminRows: [MealNutrientRowDescriptor] {
        [
            MealNutrientRowDescriptor(label: "B1, Thiamine", slug: "vitamin_b1_thiamin", defaultUnit: "mg", source: .nutrient(names: ["thiamin", "vitamin b-1"]), color: .orange),
            MealNutrientRowDescriptor(label: "B2, Riboflavin", slug: "vitamin_b2_riboflavin", defaultUnit: "mg", source: .nutrient(names: ["riboflavin", "vitamin b-2"]), color: .orange),
            MealNutrientRowDescriptor(label: "B3, Niacin", slug: "vitamin_b3_niacin", defaultUnit: "mg", source: .nutrient(names: ["niacin", "vitamin b-3"]), color: .orange),
            MealNutrientRowDescriptor(label: "B6, Pyridoxine", slug: "vitamin_b6_pyridoxine", defaultUnit: "mg", source: .nutrient(names: ["vitamin b-6", "pyridoxine", "vitamin b6"]), color: .orange),
            MealNutrientRowDescriptor(label: "B5, Pantothenic Acid", slug: "vitamin_b5_pantothenic_acid", defaultUnit: "mg", source: .nutrient(names: ["pantothenic acid"]), color: .orange),
            MealNutrientRowDescriptor(label: "B12, Cobalamin", slug: "vitamin_b12_cobalamin", defaultUnit: "mcg", source: .nutrient(names: ["vitamin b-12", "cobalamin"]), color: .orange),
            MealNutrientRowDescriptor(label: "Biotin", slug: "biotin", defaultUnit: "mcg", source: .nutrient(names: ["biotin"]), color: .orange),
            MealNutrientRowDescriptor(label: "Folate", slug: "folate", defaultUnit: "mcg", source: .nutrient(names: ["folate, total", "folic acid"]), color: .orange),
            MealNutrientRowDescriptor(label: "Vitamin A", slug: "vitamin_a", defaultUnit: "mcg", source: .nutrient(names: ["vitamin a, rae", "vitamin a"]), color: .orange),
            MealNutrientRowDescriptor(label: "Vitamin C", slug: "vitamin_c", defaultUnit: "mg", source: .nutrient(names: ["vitamin c, total ascorbic acid", "vitamin c"]), color: .orange),
            MealNutrientRowDescriptor(label: "Vitamin D", slug: "vitamin_d", defaultUnit: "IU", source: .nutrient(names: ["vitamin d (d2 + d3)", "vitamin d"]), color: .orange),
            MealNutrientRowDescriptor(label: "Vitamin E", slug: "vitamin_e", defaultUnit: "mg", source: .nutrient(names: ["vitamin e (alpha-tocopherol)", "vitamin e"]), color: .orange),
            MealNutrientRowDescriptor(label: "Vitamin K", slug: "vitamin_k", defaultUnit: "mcg", source: .nutrient(names: ["vitamin k (phylloquinone)", "vitamin k"]), color: .orange)
        ]
    }

    static var mineralRows: [MealNutrientRowDescriptor] {
        [
            MealNutrientRowDescriptor(label: "Calcium", slug: "calcium", defaultUnit: "mg", source: .nutrient(names: ["calcium, ca"]), color: .blue),
            MealNutrientRowDescriptor(label: "Copper", slug: "copper", defaultUnit: "mcg", source: .nutrient(names: ["copper, cu"]), color: .blue),
            MealNutrientRowDescriptor(label: "Iron", slug: "iron", defaultUnit: "mg", source: .nutrient(names: ["iron, fe"]), color: .blue),
            MealNutrientRowDescriptor(label: "Magnesium", slug: "magnesium", defaultUnit: "mg", source: .nutrient(names: ["magnesium, mg"]), color: .blue),
            MealNutrientRowDescriptor(label: "Manganese", slug: "manganese", defaultUnit: "mg", source: .nutrient(names: ["manganese, mn"]), color: .blue),
            MealNutrientRowDescriptor(label: "Phosphorus", slug: "phosphorus", defaultUnit: "mg", source: .nutrient(names: ["phosphorus, p"]), color: .blue),
            MealNutrientRowDescriptor(label: "Potassium", slug: "potassium", defaultUnit: "mg", source: .nutrient(names: ["potassium, k"]), color: .blue),
            MealNutrientRowDescriptor(label: "Selenium", slug: "selenium", defaultUnit: "mcg", source: .nutrient(names: ["selenium, se"]), color: .blue),
            MealNutrientRowDescriptor(label: "Sodium", slug: "sodium", defaultUnit: "mg", source: .nutrient(names: ["sodium, na"]), color: .blue),
            MealNutrientRowDescriptor(label: "Zinc", slug: "zinc", defaultUnit: "mg", source: .nutrient(names: ["zinc, zn"]), color: .blue)
        ]
    }

    static var otherRows: [MealNutrientRowDescriptor] {
        [
            MealNutrientRowDescriptor(label: "Calories", slug: "calories", defaultUnit: "kcal", source: .computed(.calories), color: .purple),
            MealNutrientRowDescriptor(label: "Alcohol", slug: "alcohol", defaultUnit: "g", source: .nutrient(names: ["alcohol, ethyl"]), color: .purple),
            MealNutrientRowDescriptor(label: "Caffeine", slug: "caffeine", defaultUnit: "mg", source: .nutrient(names: ["caffeine"]), color: .purple),
            MealNutrientRowDescriptor(label: "Cholesterol", slug: "cholesterol", defaultUnit: "mg", source: .nutrient(names: ["cholesterol"]), color: .purple),
            MealNutrientRowDescriptor(label: "Choline", slug: "choline", defaultUnit: "mg", source: .nutrient(names: ["choline, total"]), color: .purple),
            MealNutrientRowDescriptor(label: "Water", slug: "water", defaultUnit: "ml", source: .nutrient(names: ["water"]), color: .purple)
        ]
    }
}

// MARK: - Supporting Types

private struct MealItemListDisplay: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let servingText: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

private struct MealItemRow: View {
    let item: MealItemListDisplay
    let cardColor: Color
    let chipColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name.isEmpty ? "Meal Item" : item.name)
                        .font(.system(size: 15))
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    if let brand = item.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 12)

                if let serving = item.servingText, !serving.isEmpty {
                    Text(serving)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(chipColor)
                        )
                        .fixedSize()
                }
            }

            HStack(spacing: 10) {
                Label("\(Int(item.calories.rounded()))cal", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(macroLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardColor)
        )
    }

    private var macroLine: String {
        let protein = Int(item.protein.rounded())
        let carbs = Int(item.carbs.rounded())
        let fat = Int(item.fat.rounded())
        return "P \(protein)g C \(carbs)g F \(fat)g"
    }
}

private struct MealMacroRingView: View {
    let calories: Double
    let arcs: [MealMacroArc]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 8)

            ForEach(arcs.indices, id: \.self) { index in
                let arc = arcs[index]
                Circle()
                    .trim(from: CGFloat(arc.start), to: CGFloat(arc.end))
                    .stroke(arc.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: -4) {
                Text(String(format: "%.0f", calories))
                    .font(.system(size: 20, weight: .medium))
                Text("cals")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct MealMacroArc {
    let start: Double
    let end: Double
    let color: Color
}

private struct MealGoalShareBubble: View {
    let title: String
    let percent: Double
    let grams: Double
    let goal: Double
    let color: Color

    private var progress: Double {
        min(max(percent / 100, 0), 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(percent.rounded()))%")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(width: 76, height: 76)
            Text("\(grams.goalShareFormatted) / \(goal.goalShareFormatted)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Editable Item State

private struct MealEditableItem {
    var servingAmount: Double
    var servingAmountInput: String
    var selectedMeasureId: UUID?
    let measures: [MealItemMeasure]
    let baselineServing: Double
    let baselineMeasureId: UUID?

    /// The currently selected measure
    var selectedMeasure: MealItemMeasure? {
        if let id = selectedMeasureId,
           let match = measures.first(where: { $0.id == id }) {
            return match
        }
        if let baselineId = baselineMeasureId,
           let match = measures.first(where: { $0.id == baselineId }) {
            return match
        }
        return measures.first
    }

    /// Whether there are multiple measure options to choose from
    var hasMeasureOptions: Bool {
        measures.count > 1
    }

    /// Scaling factor based on serving amount and measure change
    var scalingFactor: Double {
        guard baselineServing > 0 else { return servingAmount }
        if let baselineWeight = measures.first(where: { $0.id == baselineMeasureId })?.gramWeight,
           baselineWeight > 0,
           let selectedWeight = selectedMeasure?.gramWeight,
           selectedWeight > 0 {
            return (servingAmount * selectedWeight) / (baselineServing * baselineWeight)
        }
        return servingAmount / baselineServing
    }

    /// Initialize from a MealItem object
    init(from mealItem: MealItem) {
        self.servingAmount = mealItem.serving
        self.servingAmountInput = MealEditableItem.formatServing(mealItem.serving)
        self.measures = mealItem.measures
        self.baselineServing = mealItem.baselineServing
        self.baselineMeasureId = mealItem.measures.first?.id
        self.selectedMeasureId = mealItem.selectedMeasureId ?? mealItem.measures.first?.id
    }

    /// Manual initializer
    init(servingAmount: Double, servingAmountInput: String, selectedMeasureId: UUID?, measures: [MealItemMeasure], baselineServing: Double) {
        self.servingAmount = servingAmount
        self.servingAmountInput = servingAmountInput
        self.selectedMeasureId = selectedMeasureId
        self.measures = measures
        self.baselineServing = baselineServing
        self.baselineMeasureId = measures.first?.id
    }

    /// Format serving amount for display
    static func formatServing(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.2f", value)
                .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
        }
    }

    /// Parse serving input string to Double
    static func parseServing(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Handle fractions like "1/2"
        if let slashIndex = trimmed.firstIndex(of: "/") {
            let numeratorStr = String(trimmed[..<slashIndex])
            let denominatorStr = String(trimmed[trimmed.index(after: slashIndex)...])
            if let num = Double(numeratorStr.trimmingCharacters(in: .whitespaces)),
               let denom = Double(denominatorStr.trimmingCharacters(in: .whitespaces)),
               denom != 0 {
                return num / denom
            }
        }

        return Double(trimmed)
    }
}

// MARK: - Editable Item Row

private struct MealEditableItemRow: View {
    let item: MealItem
    @Binding var editableItem: MealEditableItem
    let cardColor: Color
    let chipColor: Color
    var onTap: () -> Void = {}

    /// Scaled calories based on serving adjustments
    private var scaledCalories: Double {
        item.calories * editableItem.scalingFactor
    }

    /// Scaled protein based on serving adjustments
    private var scaledProtein: Double {
        item.protein * editableItem.scalingFactor
    }

    /// Scaled carbs based on serving adjustments
    private var scaledCarbs: Double {
        item.carbs * editableItem.scalingFactor
    }

    /// Scaled fat based on serving adjustments
    private var scaledFat: Double {
        item.fat * editableItem.scalingFactor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name + serving controls on same row
            HStack(alignment: .top, spacing: 12) {
                // Food name (tappable)
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name.isEmpty ? "Meal Item" : item.name)
                            .font(.system(size: 15))
                            .fontWeight(.regular)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                // Serving controls on the right
                servingControls
            }

            // Macro summary row
            HStack(spacing: 10) {
                Label("\(Int(scaledCalories.rounded()))cal", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(macroLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardColor)
        )
    }

    private var servingControls: some View {
        HStack(spacing: 6) {
            // Amount input field
            TextField("1", text: servingAmountBinding)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.center)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .frame(width: 50)
                .background(
                    Capsule().fill(chipColor)
                )
                .font(.system(size: 15))

            // Unit picker or static label
            if editableItem.hasMeasureOptions {
                measureMenu
            } else {
                // Show static unit label
                Text(unitLabel(for: editableItem.selectedMeasure))
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule().fill(chipColor)
                    )
            }
        }
        .fixedSize()
    }

    private var measureMenu: some View {
        Menu {
            ForEach(editableItem.measures) { measure in
                Button(action: { selectMeasure(measure) }) {
                    HStack {
                        Text(unitLabel(for: measure))
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        Spacer()
                        if measure.id == editableItem.selectedMeasureId {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(unitLabel(for: editableItem.selectedMeasure))
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule().fill(chipColor)
            )
        }
        .menuStyle(.borderlessButton)
    }

    private var servingAmountBinding: Binding<String> {
        Binding(
            get: { editableItem.servingAmountInput },
            set: { newValue in
                editableItem.servingAmountInput = newValue
                if let parsed = MealEditableItem.parseServing(newValue),
                   abs(parsed - editableItem.servingAmount) > 0.0001 {
                    editableItem.servingAmount = parsed
                }
            }
        )
    }

    private func selectMeasure(_ measure: MealItemMeasure) {
        editableItem.selectedMeasureId = measure.id
    }

    private func unitLabel(for measure: MealItemMeasure?) -> String {
        guard let measure = measure else {
            return item.servingUnit ?? "serving"
        }
        // Prefer description if it's more informative than the unit
        if !measure.description.isEmpty && measure.description != measure.unit {
            return measure.description
        }
        return measure.unit.isEmpty ? "serving" : measure.unit
    }

    private var macroLine: String {
        let protein = Int(scaledProtein.rounded())
        let carbs = Int(scaledCarbs.rounded())
        let fat = Int(scaledFat.rounded())
        return "P \(protein)g C \(carbs)g F \(fat)g"
    }
}

