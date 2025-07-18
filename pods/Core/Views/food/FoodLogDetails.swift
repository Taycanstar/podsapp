//
//  FoodLogDetails.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/25.
//

import SwiftUI

struct FoodLogDetails: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    let log: CombinedLog
    
    // Editable state
    @State private var editedServings: Double
    @State private var editedDate: Date
    @State private var editedMealType: String
    @State private var hasChanges: Bool = false
    @State private var isUpdating: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var showTimePicker: Bool = false
    

    
    var food: Food {
        log.food?.asFood ?? Food(fdcId: 0, description: "Unknown", brandOwner: nil, brandName: nil, servingSize: nil, numberOfServings: nil, servingSizeUnit: nil, householdServingFullText: nil, foodNutrients: [], foodMeasures: [])
    }
    
    init(log: CombinedLog) {
        self.log = log
        self._editedServings = State(initialValue: log.food?.numberOfServings ?? 1.0)
        self._editedDate = State(initialValue: log.scheduledAt ?? Date())
        self._editedMealType = State(initialValue: log.mealType ?? "Lunch")
    }
    
    // Helper to get nutrient value by name (scaled by servings)
    private func nutrientValue(_ name: String) -> String {
        if let value = food.foodNutrients.first(where: { $0.nutrientName == name })?.value {
            let scaledValue = value * editedServings
            return String(format: "%g", scaledValue)
        }
        return "0"
    }
    
    // Helper to get nutrient value with unit (scaled by servings)
    private func nutrientValueWithUnit(_ name: String, defaultUnit: String) -> String {
        if let nutrient = food.foodNutrients.first(where: { $0.nutrientName == name }) {
            let value = nutrient.value ?? 0
            let scaledValue = value * editedServings
            let unit = nutrient.unitName ?? defaultUnit
            return "\(String(format: "%g", scaledValue)) \(unit)"
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
                        // Number of Servings - EDITABLE
                        HStack {
                            Text("Number of Servings")
                                .foregroundColor(.primary)
                            Spacer()
                            TextField("Servings", value: $editedServings, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button("Done") {
                                            hideKeyboard()
                                        }
                                    }
                                }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        Divider().padding(.leading, 16)
                        // Date - NEW EDITABLE FIELD
                        HStack {
                            Text("Date")
                                .foregroundColor(.primary)
                            Spacer()
                            HStack(spacing: 8) {
                                Button(action: {
                                    showDatePicker = true
                                }) {
                                    Text(editedDate, style: .date)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color("iosbtn"))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    showTimePicker = true
                                }) {
                                    Text(editedDate, style: .time)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color("iosbtn"))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
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
            
            // Show Done button when there are changes
            if hasChanges {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: updateFoodLog) {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Done")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isUpdating)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: editedServings) { _ in checkForChanges() }
        .onChange(of: editedDate) { _ in checkForChanges() }
        .onChange(of: editedMealType) { _ in checkForChanges() }

        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                VStack {
                    DatePicker("Select Date", 
                             selection: $editedDate, 
                             displayedComponents: [.date])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    Spacer()
                }
                .padding()
                .navigationTitle("Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            // Reset to original date
                            editedDate = log.scheduledAt ?? Date()
                            showDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
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
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            // Reset to original date
                            editedDate = log.scheduledAt ?? Date()
                            showTimePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    // Helper functions
    private func checkForChanges() {
        let originalServings = log.food?.numberOfServings ?? 1.0
        let originalDate = log.scheduledAt ?? Date()
        let originalMealType = log.mealType ?? "Lunch"
        
        hasChanges = (editedServings != originalServings) || 
                    (abs(editedDate.timeIntervalSince(originalDate)) > 60) || // More than 1 minute difference
                    (editedMealType != originalMealType)
    }
    
    private func updateFoodLog() {
        guard let foodLogId = log.foodLogId else { return }
        
        isUpdating = true
        
        // Use the new DayLogsViewModel.updateLog function
        dayLogsVM.updateLog(
            log: log,
            servings: editedServings,
            date: editedDate,
            mealType: editedMealType
        ) { result in
            isUpdating = false
            
            switch result {
            case .success:
                print("✅ Successfully updated food log")
                hasChanges = false
                dismiss()
                
            case .failure(let error):
                print("❌ Failed to update food log: \(error)")
                // Show error to user - you might want to add an alert state for this
            }
        }
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
    let mockLog = CombinedLog(
        type: .food,
        status: "success",
        calories: 180, // 120 * 1.5 servings
        message: "Sample Food – Lunch",
        foodLogId: 1,
        food: LoggedFoodItem(
            fdcId: 1,
            displayName: "Sample Food",
            calories: 120,
            servingSizeText: "1 cup",
            numberOfServings: 1.5,
            brandText: "Sample Brand",
            protein: 5,
            carbs: 20,
            fat: 2
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
    
    return FoodLogDetails(log: mockLog)
        .environmentObject(FoodManager())
        .environmentObject(DayLogsViewModel())
}




