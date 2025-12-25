//
//  EditLogSheet.swift
//  pods
//
//  Created by Dimi Nunez on 12/24/25.
//

import SwiftUI

/// Sheet for editing log quantity and time.
/// Supports both food logs and recipe logs.
struct EditLogSheet: View {
    let log: CombinedLog
    var onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var proFeatureGate: ProFeatureGate

    // Editable state
    @State private var editedServings: Double
    @State private var editedDate: Date
    @State private var editedMealType: String
    @State private var isUpdating = false
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var backgroundColor: Color {
        Color(UIColor.systemGroupedBackground)
    }

    private var cardColor: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color(UIColor.secondarySystemGroupedBackground)
    }

    private var logTitle: String {
        switch log.type {
        case .food:
            return log.food?.displayName ?? "Food"
        case .recipe:
            return log.recipe?.title ?? "Recipe"
        case .meal:
            return log.meal?.title ?? "Meal"
        default:
            return "Log"
        }
    }

    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]

    init(log: CombinedLog, onSave: (() -> Void)? = nil) {
        self.log = log
        self.onSave = onSave

        // Initialize servings based on log type
        let initialServings: Double
        switch log.type {
        case .food:
            let rawServings = log.food?.numberOfServings ?? 1.0
            initialServings = rawServings > 0 ? rawServings : 1.0
        case .recipe:
            initialServings = Double(log.servingsConsumed ?? 1)
        case .meal:
            initialServings = Double(log.servingsConsumed ?? 1)
        default:
            initialServings = 1.0
        }

        self._editedServings = State(initialValue: initialServings)
        self._editedDate = State(initialValue: log.scheduledAt ?? Date())
        self._editedMealType = State(initialValue: log.mealType ?? "Lunch")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Log info section
                    VStack(spacing: 0) {
                        // Title
                        HStack {
                            Text(logTitle)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().padding(.leading, 16)

                        // Number of Servings - EDITABLE
                        HStack {
                            Text("Number of Servings")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            HStack(spacing: 12) {
                                Button {
                                    if editedServings > 0.5 {
                                        editedServings -= 0.5
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)

                                Text(String(format: "%.1f", editedServings))
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(minWidth: 40)
                                    .multilineTextAlignment(.center)

                                Button {
                                    if editedServings < 99 {
                                        editedServings += 0.5
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().padding(.leading, 16)

                        // Meal Type
                        HStack {
                            Text("Meal")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Menu {
                                ForEach(mealTypes, id: \.self) { type in
                                    Button {
                                        editedMealType = type
                                    } label: {
                                        if type == editedMealType {
                                            Label(type, systemImage: "checkmark")
                                        } else {
                                            Text(type)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(editedMealType)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color("iosbtn"))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().padding(.leading, 16)

                        // Date
                        HStack {
                            Text("Date")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Button {
                                showDatePicker = true
                            } label: {
                                Text(editedDate, style: .date)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color("iosbtn"))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().padding(.leading, 16)

                        // Time
                        HStack {
                            Text("Time")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Button {
                                showTimePicker = true
                            } label: {
                                Text(editedDate, style: .time)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color("iosbtn"))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardColor)
                    )
                    .padding(.horizontal)

                    Spacer().frame(height: 20)
                }
                .padding(.top, 16)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Edit Log")
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
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isUpdating)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    VStack {
                        DatePicker("Select Date",
                                   selection: $editedDate,
                                   displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                            .padding()
                        Spacer()
                    }
                    .navigationTitle("Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showTimePicker) {
                NavigationView {
                    VStack {
                        DatePicker("Select Time",
                                   selection: $editedDate,
                                   displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showTimePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveChanges() {
        isUpdating = true

        switch log.type {
        case .food:
            updateFoodLog()
        case .recipe:
            updateRecipeLog()
        case .meal:
            updateMealLog()
        default:
            isUpdating = false
            dismiss()
        }
    }

    private func updateFoodLog() {
        guard log.foodLogId != nil else {
            isUpdating = false
            return
        }

        // Get current nutrition values from the log
        let calories = (log.food?.calories ?? 0) * editedServings
        let protein = (log.food?.protein ?? 0) * editedServings
        let carbs = (log.food?.carbs ?? 0) * editedServings
        let fat = (log.food?.fat ?? 0) * editedServings

        dayLogsVM.updateLog(
            log: log,
            servings: editedServings,
            date: editedDate,
            mealType: editedMealType,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        ) { result in
            isUpdating = false

            switch result {
            case .success:
                onSave?()
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func updateRecipeLog() {
        guard log.recipeLogId != nil else {
            isUpdating = false
            return
        }

        // Get current nutrition values from the log
        let calories = (log.recipe?.calories ?? 0) * editedServings
        let protein = (log.recipe?.protein ?? 0) * editedServings
        let carbs = (log.recipe?.carbs ?? 0) * editedServings
        let fat = (log.recipe?.fat ?? 0) * editedServings

        dayLogsVM.updateRecipeLog(
            log: log,
            servings: editedServings,
            date: editedDate,
            mealType: editedMealType,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        ) { result in
            isUpdating = false

            switch result {
            case .success:
                onSave?()
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func updateMealLog() {
        guard log.mealLogId != nil else {
            isUpdating = false
            return
        }

        // Get current nutrition values from the log
        let calories = (log.meal?.calories ?? 0) * editedServings
        let protein = (log.meal?.protein ?? 0) * editedServings
        let carbs = (log.meal?.carbs ?? 0) * editedServings
        let fat = (log.meal?.fat ?? 0) * editedServings

        dayLogsVM.updateMealLog(
            log: log,
            servings: editedServings,
            date: editedDate,
            mealType: editedMealType,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        ) { result in
            isUpdating = false

            switch result {
            case .success:
                onSave?()
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    let mockLog = CombinedLog(
        type: .food,
        status: "success",
        calories: 180,
        message: "Sample Food – Lunch",
        foodLogId: 1,
        food: LoggedFoodItem(
            foodLogId: 1,
            fdcId: 1,
            displayName: "Sample Food",
            calories: 120,
            servingSizeText: "1 cup",
            numberOfServings: 1.5,
            brandText: "Sample Brand",
            protein: 5,
            carbs: 20,
            fat: 2,
            healthAnalysis: nil,
            foodNutrients: nil,
            aiInsight: nil,
            nutritionScore: nil
        ),
        mealType: "Lunch",
        mealLogId: nil,
        meal: nil,
        mealTime: nil,
        scheduledAt: Date(),
        recipeLogId: nil,
        recipe: nil,
        servingsConsumed: nil
    )

    EditLogSheet(log: mockLog)
        .environmentObject(DayLogsViewModel())
        .environmentObject(FoodManager())
}
