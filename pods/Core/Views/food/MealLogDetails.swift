//
//  MealLogDetails.swift
//  pods
//
//  Created by Dimi Nunez on 7/29/25.
//

import SwiftUI

struct MealLogDetails: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isTabBarVisible) private var isTabBarVisible
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
    
    // Editable macronutrients
    @State private var editedCalories: String = ""
    @State private var editedProtein: String = ""
    @State private var editedCarbs: String = ""
    @State private var editedFat: String = ""
    
    var meal: MealSummary? {
        log.meal
    }
    
    init(log: CombinedLog) {
        self.log = log
        self._editedServings = State(initialValue: Double(log.servingsConsumed ?? 1))
        self._editedDate = State(initialValue: log.scheduledAt ?? Date())
        self._editedMealType = State(initialValue: log.mealType ?? "Lunch")
        
        // Initialize macronutrient values
        let servings = Double(log.servingsConsumed ?? 1)
        if let meal = log.meal {
            // Scale by servings and convert to strings
            self._editedCalories = State(initialValue: String(format: "%g", meal.calories * servings))
            self._editedProtein = State(initialValue: String(format: "%g", (meal.protein ?? 0) * servings))
            self._editedCarbs = State(initialValue: String(format: "%g", (meal.carbs ?? 0) * servings))
            self._editedFat = State(initialValue: String(format: "%g", (meal.fat ?? 0) * servings))
        } else {
            self._editedCalories = State(initialValue: "0")
            self._editedProtein = State(initialValue: "0")
            self._editedCarbs = State(initialValue: "0")
            self._editedFat = State(initialValue: "0")
        }
    }
    
    // Helper to get nutrient value scaled by servings
    private func nutrientValue(_ value: Double?) -> String {
        guard let value = value else { return "0" }
        let scaledValue = value * editedServings
        return String(format: "%g", scaledValue)
    }
    
    @State private var showMoreNutrients: Bool = false
    
    // List of additional nutrients to show (matching FoodLogDetails pattern)
    private var additionalNutrients: [String] {
        [
            "Saturated Fat (g)",
            "Polyunsaturated Fat (g)",
            "Monounsaturated Fat (g)",
            "Trans Fat (g)",
            "Cholesterol (mg)",
            "Sodium (mg)",
            "Potassium (mg)",
            "Sugar (g)",
            "Fiber (g)",
            "Vitamin A (%)",
            "Vitamin C (%)",
            "Calcium (%)",
            "Iron (%)",
            "Calories per serving",
            "Protein per serving (g)",
            "Carbs per serving (g)",
            "Fat per serving (g)"
        ]
    }
    
    // Calculate nutrient values - show actual values for available nutrients, "0" for unavailable
    private func calculateNutrientValue(for label: String) -> String {
        guard let meal = meal else { return "0" }
        
        switch label {
        case "Calories per serving":
            return String(format: "%g", meal.calories)
        case "Protein per serving (g)":
            return String(format: "%g", meal.protein ?? 0)
        case "Carbs per serving (g)":
            return String(format: "%g", meal.carbs ?? 0)
        case "Fat per serving (g)":
            return String(format: "%g", meal.fat ?? 0)
        default:
            // For nutrients we don't have data for, return "0"
            return "0"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Basic meal info card
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("iosnp"))
                    VStack(spacing: 0) {
                        // Title
                        HStack {
                            Text(meal?.title ?? "Meal")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        Divider().padding(.leading, 16)
                        
                        // Description
                        if let description = meal?.description, !description.isEmpty {
                            HStack {
                                Text("Description")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(description)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            Divider().padding(.leading, 16)
                        }
                        
                        // Original Servings
                        HStack {
                            Text("Original Servings")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(String(format: "%.1f", meal?.servings ?? 1.0))
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
                        
                        // Date - EDITABLE FIELD
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
                                TextField("0", text: $editedCalories)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            Divider().padding(.leading, 16)
                            
                            // Protein
                            HStack {
                                Text("Protein (g)")
                                Spacer()
                                TextField("0", text: $editedProtein)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            Divider().padding(.leading, 16)
                            
                            // Carbs
                            HStack {
                                Text("Carbs (g)")
                                Spacer()
                                TextField("0", text: $editedCarbs)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            Divider().padding(.leading, 16)
                            
                            // Fat
                            HStack {
                                Text("Total Fat (g)")
                                Spacer()
                                TextField("0", text: $editedFat)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Show More Nutrients button (matching FoodLogDetails)
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
                                ForEach(additionalNutrients, id: \.self) { label in
                                    HStack {
                                        Text(label)
                                        Spacer()
                                        Text(calculateNutrientValue(for: label))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 16)
                                    
                                    if label != additionalNutrients.last {
                                        Divider().padding(.leading, 16)
                                    }
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
        .onAppear {
            // Hide tab bar when meal log details appears
            isTabBarVisible.wrappedValue = false
        }
        .onDisappear {
            // Restore tab bar when meal log details disappears
            isTabBarVisible.wrappedValue = true
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Recipe Details").font(.headline)
            }
            
            // Show 
            // Done button when there are changes
            if hasChanges {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: updateMealLog) {
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
            
            // Keyboard toolbar
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
            }
        }
        .onChange(of: editedServings) { _ in checkForChanges() }
        .onChange(of: editedDate) { _ in checkForChanges() }
        .onChange(of: editedMealType) { _ in checkForChanges() }
        .onChange(of: editedCalories) { _ in checkForChanges() }
        .onChange(of: editedProtein) { _ in checkForChanges() }
        .onChange(of: editedCarbs) { _ in checkForChanges() }
        .onChange(of: editedFat) { _ in checkForChanges() }
        
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
        let originalServings = Double(log.servingsConsumed ?? 1)
        let originalDate = log.scheduledAt ?? Date()
        let originalMealType = log.mealType ?? "Lunch"
        
        // Get original nutrient values
        let servings = Double(log.servingsConsumed ?? 1)
        let originalCalories = String(format: "%g", (meal?.calories ?? 0) * servings)
        let originalProtein = String(format: "%g", (meal?.protein ?? 0) * servings)
        let originalCarbs = String(format: "%g", (meal?.carbs ?? 0) * servings)
        let originalFat = String(format: "%g", (meal?.fat ?? 0) * servings)
        
        let servingsChanged = editedServings != originalServings
        let dateChanged = abs(editedDate.timeIntervalSince(originalDate)) > 60
        let mealTypeChanged = editedMealType != originalMealType
        let caloriesChanged = editedCalories != originalCalories
        let proteinChanged = editedProtein != originalProtein
        let carbsChanged = editedCarbs != originalCarbs
        let fatChanged = editedFat != originalFat
        
        hasChanges = servingsChanged || dateChanged || mealTypeChanged || 
                    caloriesChanged || proteinChanged || carbsChanged || fatChanged
        
        print("🔍 Checking for changes:")
        print("   Original servings: \(originalServings), Edited: \(editedServings), Changed: \(servingsChanged)")
        print("   Original date: \(originalDate), Edited: \(editedDate), Changed: \(dateChanged)")
        print("   Original meal type: \(originalMealType), Edited: \(editedMealType), Changed: \(mealTypeChanged)")
        print("   Original calories: \(originalCalories), Edited: \(editedCalories), Changed: \(caloriesChanged)")
        print("   Original protein: \(originalProtein), Edited: \(editedProtein), Changed: \(proteinChanged)")
        print("   Original carbs: \(originalCarbs), Edited: \(editedCarbs), Changed: \(carbsChanged)")
        print("   Original fat: \(originalFat), Edited: \(editedFat), Changed: \(fatChanged)")
        print("   Has changes: \(hasChanges)")
    }
    
    private func updateMealLog() {
        guard let mealLogId = log.mealLogId else { 
            print("❌ No mealLogId found in log")
            return 
        }
        
        print("🍽️ Updating meal log with ID: \(mealLogId)")
        print("📊 Servings: \(editedServings), Date: \(editedDate), MealType: \(editedMealType)")
        
        isUpdating = true
        
        dayLogsVM.updateMealLog(
            log: log,
            servings: editedServings,
            date: editedDate,
            mealType: editedMealType
        ) { result in
            DispatchQueue.main.async {
                print("🔄 Received update meal log result")
                self.isUpdating = false
                
                switch result {
                case .success:
                    print("✅ Successfully updated meal log")
                    self.hasChanges = false
                    self.dismiss()
                    
                case .failure(let error):
                    print("❌ Failed to update meal log: \(error.localizedDescription)")
                    // Show error to user - you might want to add an alert state for this
                }
            }
        }
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    let mockMeal = MealSummary(
        mealLogId: 1,
        mealId: 123,
        title: "Sample Meal",
        description: "A delicious and nutritious meal",
        image: nil,
        calories: 450.0,
        servings: 1.0,
        protein: 25.0,
        carbs: 50.0,
        fat: 15.0,
        scheduledAt: Date()
    )
    
    let mockLog = CombinedLog(
        type: .meal,
        status: "success",
        calories: 450.0,
        message: "Sample Meal – Lunch",
        foodLogId: nil,
        food: nil,
        mealType: "Lunch",
        mealLogId: 1,
        meal: mockMeal,
        mealTime: "Lunch",
        scheduledAt: Date(),
        recipeLogId: nil,
        recipe: nil,
        servingsConsumed: 1,
        activityId: nil,
        activity: nil,
        logDate: nil,
        dayOfWeek: nil,
        isOptimistic: false
    )
    
    return MealLogDetails(log: mockLog)
        .environmentObject(FoodManager())
        .environmentObject(DayLogsViewModel())
}