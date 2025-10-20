//
//  FoodLogDetails.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/25.
//

import SwiftUI

struct FoodLogDetails: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isTabBarVisible) private var isTabBarVisible
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @EnvironmentObject var proFeatureGate: ProFeatureGate
    let log: CombinedLog
    
    // Editable state
    @State private var editedServings: Double
    @State private var editedDate: Date
    @State private var editedMealType: String
    @State private var hasChanges: Bool = false
    @State private var isUpdating: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var showTimePicker: Bool = false
    @State private var showScheduleSheet = false
    @State private var scheduleAlert: ScheduleAlert?
    
    // Editable macronutrients
    @State private var editedCalories: String = ""
    @State private var editedProtein: String = ""
    @State private var editedCarbs: String = ""
    @State private var editedFat: String = ""
    

    
    var food: Food {
        log.food?.asFood ?? Food(fdcId: 0, description: "Unknown", brandOwner: nil, brandName: nil, servingSize: nil, numberOfServings: nil, servingSizeUnit: nil, householdServingFullText: nil, foodNutrients: [], foodMeasures: [])
    }
    
    init(log: CombinedLog) {
        self.log = log
        let rawServings = log.food?.numberOfServings ?? 1.0
        let initialServings = rawServings > 0 ? rawServings : 1.0
        self._editedServings = State(initialValue: initialServings)
        self._editedDate = State(initialValue: log.scheduledAt ?? Date())
        self._editedMealType = State(initialValue: log.mealType ?? "Lunch")
        
        // Initialize macronutrient values
        let food = log.food?.asFood ?? Food(fdcId: 0, description: "Unknown", brandOwner: nil, brandName: nil, servingSize: nil, numberOfServings: nil, servingSizeUnit: nil, householdServingFullText: nil, foodNutrients: [], foodMeasures: [])
        let servings = initialServings
        
        // Resolve per-serving nutrient values with fallbacks to the original log payload
        let caloriesPerServing = FoodLogDetails.resolvePerServingValue(
            primaryName: "Energy",
            alternativeMatch: { $0.nutrientName.lowercased().contains("energy") },
            in: food,
            fallback: log.food?.calories
        )
        let proteinPerServing = FoodLogDetails.resolvePerServingValue(
            primaryName: "Protein",
            alternativeMatch: { $0.nutrientName.lowercased().contains("protein") },
            in: food,
            fallback: log.food?.protein
        )
        let carbsPerServing = FoodLogDetails.resolvePerServingValue(
            primaryName: "Carbohydrate, by difference",
            alternativeMatch: { $0.nutrientName.lowercased().contains("carb") },
            in: food,
            fallback: log.food?.carbs
        )
        let fatPerServing = FoodLogDetails.resolvePerServingValue(
            primaryName: "Total lipid (fat)",
            alternativeMatch: { $0.nutrientName.lowercased().contains("fat") || $0.nutrientName.lowercased().contains("lipid") },
            in: food,
            fallback: log.food?.fat
        )
        
        // Scale by servings and convert to strings
        self._editedCalories = State(initialValue: FoodLogDetails.formatValue(caloriesPerServing * servings))
        self._editedProtein = State(initialValue: FoodLogDetails.formatValue(proteinPerServing * servings))
        self._editedCarbs = State(initialValue: FoodLogDetails.formatValue(carbsPerServing * servings))
        self._editedFat = State(initialValue: FoodLogDetails.formatValue(fatPerServing * servings))
    }

    // Helper to get nutrient value by name (scaled by servings)
    private func nutrientValue(_ name: String) -> String {
        let value = FoodLogDetails.resolvePerServingValue(
            primaryName: name,
            alternativeMatch: { $0.nutrientName.lowercased() == name.lowercased() },
            in: food,
            fallback: fallbackForNutrient(named: name)
        )
        return FoodLogDetails.formatValue(value * editedServings)
    }

    // Helper to get nutrient value with unit (scaled by servings)
    private func nutrientValueWithUnit(_ name: String, defaultUnit: String) -> String {
        if let nutrient = food.foodNutrients.first(where: { $0.nutrientName == name }) {
            let value = (nutrient.value ?? 0) * editedServings
            let unit = nutrient.unitName ?? defaultUnit
            return "\(FoodLogDetails.formatValue(value)) \(unit)"
        }
        let fallback = FoodLogDetails.resolvePerServingValue(
            primaryName: name,
            alternativeMatch: { $0.nutrientName.lowercased() == name.lowercased() },
            in: food,
            fallback: fallbackForNutrient(named: name)
        )
        return "\(FoodLogDetails.formatValue(fallback * editedServings)) \(defaultUnit)"
    }
    
    @State private var showMoreNutrients: Bool = false

    private static func resolvePerServingValue(
        primaryName: String,
        alternativeMatch: ((Nutrient) -> Bool)? = nil,
        in food: Food,
        fallback: Double?
    ) -> Double {
        if let exact = food.foodNutrients.first(where: { $0.nutrientName == primaryName })?.value, exact > 0 {
            return exact
        }

        if let matcher = alternativeMatch,
           let match = food.foodNutrients.first(where: matcher)?.value,
           match > 0 {
            return match
        }

        return fallback ?? 0
    }

    private static func formatValue(_ value: Double) -> String {
        String(format: "%g", value)
    }

    private func fallbackForNutrient(named name: String) -> Double? {
        switch name {
        case "Energy":
            return log.food?.calories
        case "Protein":
            return log.food?.protein
        case "Carbohydrate, by difference":
            return log.food?.carbs
        case "Total lipid (fat)":
            return log.food?.fat
        default:
            return nil
        }
    }
    
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
        .sheet(isPresented: Binding(
            get: { proFeatureGate.showUpgradeSheet && proFeatureGate.blockedFeature != .workouts },
            set: { if !$0 { proFeatureGate.dismissUpgradeSheet() } }
        )) {
            if proFeatureGate.blockedFeature == .foodScans {
                LogProUpgradeSheet(
                    usageSummary: proFeatureGate.usageSummary,
                    onDismiss: { proFeatureGate.dismissUpgradeSheet() }
                )
            } else {
                HumuliProUpgradeSheet(
                    feature: proFeatureGate.blockedFeature,
                    usageSummary: proFeatureGate.usageSummary,
                    onDismiss: { proFeatureGate.dismissUpgradeSheet() }
                )
            }
        }
        .background(Color("iosbg"))
        .onAppear {
            // Hide tab bar when food log details appears
            isTabBarVisible.wrappedValue = false
        }
        .onDisappear {
            // Restore tab bar when food log details disappears
            isTabBarVisible.wrappedValue = true
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Log Details").font(.headline)
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
        .toolbar {
            if log.foodLogId != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        triggerSchedule()
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showScheduleSheet) {
            ScheduleMealSheet(initialMealType: editedMealType) { selection in
                scheduleLog(selection: selection)
            }
        }
        .alert(item: $scheduleAlert) { alert in
            switch alert {
            case .success(let message):
                return Alert(title: Text("Scheduled"), message: Text(message), dismissButton: .default(Text("OK")))
            case .failure(let message):
                return Alert(title: Text("Error"), message: Text(message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var currentUserEmail: String? {
        let email = UserDefaults.standard.string(forKey: "userEmail")
        return email?.isEmpty == false ? email : nil
    }
    
    // Helper functions
    private func checkForChanges() {
        let originalServings = log.food?.numberOfServings ?? 1.0
        let originalDate = log.scheduledAt ?? Date()
        let originalMealType = log.mealType ?? "Lunch"
        
        // Get original nutrient values
        let servings = log.food?.numberOfServings ?? 1.0
        let originalCalories = String(format: "%g", (food.foodNutrients.first(where: { $0.nutrientName == "Energy" })?.value ?? 0) * servings)
        let originalProtein = String(format: "%g", (food.foodNutrients.first(where: { $0.nutrientName == "Protein" })?.value ?? 0) * servings)
        let originalCarbs = String(format: "%g", (food.foodNutrients.first(where: { $0.nutrientName == "Carbohydrate, by difference" })?.value ?? 0) * servings)
        let originalFat = String(format: "%g", (food.foodNutrients.first(where: { $0.nutrientName == "Total lipid (fat)" })?.value ?? 0) * servings)
        
        hasChanges = (editedServings != originalServings) || 
                    (abs(editedDate.timeIntervalSince(originalDate)) > 60) || // More than 1 minute difference
                    (editedMealType != originalMealType) ||
                    (editedCalories != originalCalories) ||
                    (editedProtein != originalProtein) ||
                    (editedCarbs != originalCarbs) ||
                    (editedFat != originalFat)
    }
    
    private func updateFoodLog() {
        guard let foodLogId = log.foodLogId else { return }
        
        isUpdating = true
        
        // Convert string values to doubles with fallback
        let caloriesValue = Double(editedCalories.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let proteinValue = Double(editedProtein.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let carbsValue = Double(editedCarbs.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let fatValue = Double(editedFat.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        
        print("🔢 Converting values: calories='\(editedCalories)' -> \(caloriesValue), protein='\(editedProtein)' -> \(proteinValue), carbs='\(editedCarbs)' -> \(carbsValue), fat='\(editedFat)' -> \(fatValue)")
        
        // Use the new DayLogsViewModel.updateLog function
        dayLogsVM.updateLog(
            log: log,
            servings: editedServings,
            date: editedDate,
            mealType: editedMealType,
            calories: caloriesValue,
            protein: proteinValue,
            carbs: carbsValue,
            fat: fatValue
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

extension FoodLogDetails {
    private func triggerSchedule() {
        guard let email = currentUserEmail else { return }
        proFeatureGate.requirePro(for: .scheduledLogging, userEmail: email) {
            Task {
                await proFeatureGate.refreshUsageSummary(for: email)
            }
            showScheduleSheet = true
        }
    }
    
    private func scheduleLog(selection: ScheduleMealSelection) {
        guard let logId = log.foodLogId else { return }
        guard let email = currentUserEmail else { return }
        NetworkManager().scheduleMealLog(
            logId: logId,
            logType: "food",
            scheduleType: selection.scheduleType.rawValue,
            targetDate: selection.targetDate,
            mealType: selection.mealType,
            userEmail: email
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let calendar = Calendar.current
                    if calendar.isDate(response.targetDate, inSameDayAs: dayLogsVM.selectedDate) {
                        dayLogsVM.loadLogs(for: dayLogsVM.selectedDate, force: true)
                    }

                    self.scheduleAlert = .success("This meal will appear in your scheduled previews for the selected day.")
                case .failure(let error):
                    self.scheduleAlert = .failure(error.localizedDescription)
                }
            }
        }
    }
    
    private enum ScheduleAlert: Identifiable {
        case success(String)
        case failure(String)
        
        var id: String {
            switch self {
            case .success(let message): return "success_\(message)"
            case .failure(let message): return "failure_\(message)"
            }
        }
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
            foodNutrients: nil
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
    
    FoodLogDetails(log: mockLog)
        .environmentObject(FoodManager())
        .environmentObject(DayLogsViewModel())
}
