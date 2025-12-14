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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel

    @State private var selectedFood: Food?
    @State private var selectedMealPeriod: MealPeriod = .lunch
    @State private var mealTime: Date = Date()
    @State private var showMealTimePicker = false
    @State private var isLogging = false

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
        for item in mealItems {
            cals += item.calories ?? 0
            protein += item.protein ?? 0
            carbs += item.carbs ?? 0
            fat += item.fat ?? 0
        }
        // Fallback to foods if mealItems is empty
        if mealItems.isEmpty {
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

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    mealItemsSection
                    macroSummaryCard
                    mealTimeSelector
                    dailyGoalShareCard
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
        .sheet(isPresented: Binding<Bool>(
            get: { selectedFood != nil },
            set: { if !$0 { selectedFood = nil } }
        )) {
            if let food = selectedFood {
                FoodSummaryView(food: food)
            }
        }
        .onAppear {
            // Set meal period based on current time
            selectedMealPeriod = suggestedMealPeriod(for: Date())
        }
    }

    // MARK: - Meal Items Section
    private var mealItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Items")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if mealItems.isEmpty && foods.isEmpty {
                Text("No meal items found")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
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
                    onLogMeal(foods)
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
                .disabled(isLogging || (mealItems.isEmpty && foods.isEmpty))
                .opacity(isLogging ? 0.7 : 1)

                Button(action: {
                    HapticFeedback.generateLigth()
                    onAddToPlate(foods)
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
                        .font(.body)
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
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .frame(height: 36)
                        .background(
                            Capsule().fill(chipColor)
                        )
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


