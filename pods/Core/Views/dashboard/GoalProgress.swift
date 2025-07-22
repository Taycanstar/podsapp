//
//  GoalProgress.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/25.
//

import SwiftUI
import UIKit

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

// Remove the complex MacroInputTextField and replace with simpler approach
// Add state for inline picker

/// TextField that can switch between number pad and wheel picker without dismissing keyboard
struct MacroInputTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var percent: Double
    @Binding fileprivate var inputMode: MacroInputMode
    fileprivate let macro: MacroType
    let placeholder: String = "0"
    var onEditingChanged: (Bool) -> Void = { _ in }
    var onPercentChange: (Double) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.textAlignment = .right
        tf.placeholder = placeholder
        tf.keyboardType = .numberPad
        tf.delegate = context.coordinator

        // Create toolbar with Grams/% segmented control and Done button
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        
        let segmentedControl = UISegmentedControl(items: ["Grams", "%"])
        segmentedControl.selectedSegmentIndex = inputMode == .grams ? 0 : 1
        segmentedControl.addTarget(context.coordinator, action: #selector(context.coordinator.segmentChanged(_:)), for: .valueChanged)
        
        let segmentItem = UIBarButtonItem(customView: segmentedControl)
        let flexSpace1 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let flexSpace2 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(context.coordinator.donePressed))
        
        toolbar.items = [flexSpace1, segmentItem, flexSpace2, doneButton]
        tf.inputAccessoryView = toolbar
        
        // Store references
        context.coordinator.textField = tf
        context.coordinator.segmentedControl = segmentedControl
        
        // Set initial input view
        context.coordinator.updateInputView()
        
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Update text based on current mode
        if inputMode == .percent {
            uiView.text = String(format: "%.0f", percent)
        } else {
            uiView.text = text
        }
        
        // Update segmented control
        context.coordinator.segmentedControl?.selectedSegmentIndex = inputMode == .grams ? 0 : 1
        
        // Update input view if mode changed
        context.coordinator.updateInputView()
    }

    class Coordinator: NSObject, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
        let parent: MacroInputTextField
        weak var textField: UITextField?
        weak var segmentedControl: UISegmentedControl?
        private var pickerView: UIPickerView?
        
        init(_ parent: MacroInputTextField) { self.parent = parent }
        
        @objc func donePressed() {
            textField?.resignFirstResponder()
        }
        
        @objc func segmentChanged(_ sender: UISegmentedControl) {
            let newMode: MacroInputMode = sender.selectedSegmentIndex == 0 ? .grams : .percent
            print("🔄 Segment changed to: \(newMode)")
            parent.inputMode = newMode
            
            // Update text field content immediately
            if newMode == .percent {
                let currentPercent = parent.percent
                textField?.text = String(format: "%.0f", currentPercent)
                print("📱 Set text to percentage: \(currentPercent)%")
            } else {
                textField?.text = parent.text
                print("📱 Set text to grams: \(parent.text)")
            }
            
            // Force update input view
            updateInputView()
        }
        
        func updateInputView() {
            guard let tf = textField else { 
                print("❌ No textField reference")
                return 
            }
            
            print("🔄 Updating input view for mode: \(parent.inputMode)")
            
            if parent.inputMode == .percent {
                // Create picker if needed
                if pickerView == nil {
                    print("📱 Creating new picker view")
                    pickerView = UIPickerView()
                    pickerView?.delegate = self
                    pickerView?.dataSource = self
                } else {
                    print("📱 Reusing existing picker view")
                }
                
                tf.inputView = pickerView
                pickerView?.selectRow(Int(parent.percent), inComponent: 0, animated: false)
                print("📱 Set input view to picker, selected row: \(Int(parent.percent))")
            } else {
                print("📱 Setting input view to nil (number pad)")
                tf.inputView = nil
                tf.keyboardType = .numberPad
            }
            
            // Reload input view without dismissing keyboard
            if tf.isFirstResponder {
                print("📱 Reloading input views (keyboard is active)")
                tf.reloadInputViews()
            } else {
                print("📱 TextField not first responder, input view will change on next focus")
            }
        }
        
        // UITextFieldDelegate
        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onEditingChanged(true)
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onEditingChanged(false)
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if parent.inputMode == .grams {
                let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string
                parent.text = newText
                
                // Update percentage when grams change
                if let grams = Double(newText), grams > 0 {
                    let totalCals = max(Double(parent.text) ?? 1, 1) // This should be total calorie goal, need to pass it
                    let calsPerGram: Double
                    switch parent.macro {
                    case .protein, .carbs: calsPerGram = 4.0
                    case .fat: calsPerGram = 9.0
                    }
                    // Calculate percentage of total calories
                    let caloriesFromMacro = grams * calsPerGram
                    parent.percent = (caloriesFromMacro / totalCals) * 100
                }
            }
            return parent.inputMode == .grams
        }
        
        // UIPickerViewDelegate & DataSource
        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent c: Int) -> Int { 101 }
        func pickerView(_ picker: UIPickerView, titleForRow row: Int, forComponent c: Int) -> String? { "\(row)%" }
        func pickerView(_ picker: UIPickerView, didSelectRow row: Int, inComponent c: Int) {
            parent.percent = Double(row)
            parent.onPercentChange(Double(row))
            textField?.text = String(format: "%.0f", parent.percent)
        }
    }
}

struct GoalProgress: View {
    @EnvironmentObject var vm: DayLogsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isTabBarVisible) private var isTabBarVisible
    
    // State to hold temporary values while editing
    @State private var calorieGoal: String = ""
    @State private var proteinGoal: String = ""
    @State private var carbsGoal: String = ""
    @State private var fatGoal: String = ""
    
    @State private var isSubmitting = false
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var editingMacro: MacroType? = nil
    @State private var macroInputMode: [MacroType: MacroInputMode] = [
        .protein: .grams,
        .carbs: .grams,
        .fat: .grams
    ]
    @State private var proteinPercentValue: Double = 0
    @State private var carbsPercentValue: Double = 0
    @State private var fatPercentValue: Double = 0
    
    // State for macro picker sheet
    @State private var showMacroPickerSheet = false

    // Computed properties for goal macro calories
    private var proteinCals: Double {
        vm.proteinGoal * 4
    }
    
    private var carbCals: Double {
        vm.carbsGoal * 4
    }
    
    private var fatCals: Double {
        vm.fatGoal * 9
    }
    
    private var macroCals: Double {
        proteinCals + carbCals + fatCals
    }
    
    // Calculate percentages for ring segments based on goal calories
    private var totalGoalCalories: Double {
        max(vm.calorieGoal, 1)
    }
    
    // Helper function to ensure percentages add up to exactly 100%
    private func adjustedPercentages() -> (protein: Double, carbs: Double, fat: Double) {
        // Calculate exact percentages first
        let exactProtein = proteinCals / totalGoalCalories
        let exactCarbs = carbCals / totalGoalCalories
        let exactFat = fatCals / totalGoalCalories
        
        // Round to integers for display
        var roundedProtein = round(exactProtein * 100)
        var roundedCarbs = round(exactCarbs * 100)
        var roundedFat = round(exactFat * 100)
        
        // Calculate total and difference from 100
        let total = roundedProtein + roundedCarbs + roundedFat
        let difference = 100 - total
        
        // Apply largest remainder method to distribute the difference
        if difference != 0 {
            // Calculate remainders after rounding
            let proteinRemainder = (exactProtein * 100) - roundedProtein
            let carbsRemainder = (exactCarbs * 100) - roundedCarbs
            let fatRemainder = (exactFat * 100) - roundedFat
            
            // Create array of (remainder, index) pairs and sort by remainder descending
            var remainders = [
                (proteinRemainder, 0), // 0 = protein
                (carbsRemainder, 1),   // 1 = carbs
                (fatRemainder, 2)      // 2 = fat
            ]
            remainders.sort { $0.0 > $1.0 }
            
            // Distribute the difference to macros with largest remainders
            for i in 0..<abs(Int(difference)) {
                let macroIndex = remainders[i % 3].1
                if difference > 0 {
                    // Add 1% to largest remainders
                    switch macroIndex {
                    case 0: roundedProtein += 1
                    case 1: roundedCarbs += 1
                    case 2: roundedFat += 1
                    default: break
                    }
                } else {
                    // Subtract 1% from largest remainders
                    switch macroIndex {
                    case 0: roundedProtein -= 1
                    case 1: roundedCarbs -= 1
                    case 2: roundedFat -= 1
                    default: break
                    }
                }
            }
        }
        
        // Return as decimals (0.0 to 1.0) for ring segments
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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Calories section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Calories")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("iosnp"))
                        
                        HStack {
                            TextField("Daily target", text: $calorieGoal)
                                .keyboardType(.numberPad)
                                .padding()
                        }
                    }
                    .frame(height: 56)
                }
                .padding(.horizontal)
                
                // Macronutrients section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Macronutrients")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("iosnp"))
                        
                        VStack(spacing: 0) {
                            HStack {
                                Text("Protein (g)")
                                Text(String(format: "%d%%", Int(proteinPercent * 100)))
                                    .foregroundColor(.blue)
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Text(proteinGoal)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .padding(.vertical, 8)
                                    .background(Color.clear)
                                    .onTapGesture {
                                        showMacroPickerSheet = true
                                    }
                            }
                            .padding()
                            .onTapGesture {
                                showMacroPickerSheet = true
                            }
                            
                            Divider()
                                .padding(.leading)
                            
                            HStack {
                                Text("Carbs (g)")
                                Text(String(format: "%d%%", Int(carbPercent * 100)))
                                    .foregroundColor(Color("darkYellow"))
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Text(carbsGoal)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .padding(.vertical, 8)
                                    .background(Color.clear)
                                    .onTapGesture {
                                        showMacroPickerSheet = true
                                    }
                            }
                            .padding()
                            .onTapGesture {
                                showMacroPickerSheet = true
                            }
                            
                            Divider()
                                .padding(.leading)
                            
                            HStack {
                                Text("Fat (g)")
                                Text(String(format: "%d%%", Int(fatPercent * 100)))
                                    .foregroundColor(.pink)
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Text(fatGoal)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .padding(.vertical, 8)
                                    .background(Color.clear)
                                    .onTapGesture {
                                        showMacroPickerSheet = true
                                    }
                            }
                            .padding()
                            .onTapGesture {
                                showMacroPickerSheet = true
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .sheet(isPresented: $showMacroPickerSheet) {
                    MacroPickerSheet(
                        proteinGoal: $proteinGoal,
                        carbsGoal: $carbsGoal,
                        fatGoal: $fatGoal,
                        calorieGoal: $calorieGoal,
                        isPresented: $showMacroPickerSheet
                    )
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
                }
                
                // Goal breakdown donut ring
                VStack(alignment: .leading, spacing: 16) {
                    Text("Goal Breakdown")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 20) {
                        ZStack {
                            // Background track (light gray for unfilled portion)
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                            
                            // Protein segment (starts at 0)
                            RingSegment(
                                start: 0,
                                percent: proteinPercent,
                                color: .blue
                            )
                            
                            // Carbs segment (starts after protein)
                            RingSegment(
                                start: proteinPercent,
                                percent: carbPercent,
                                color: Color("darkYellow")
                            )
                            
                            // Fat segment (starts after protein + carbs)
                            RingSegment(
                                start: proteinPercent + carbPercent,
                                percent: fatPercent,
                                color: .pink
                            )
                            
                            // Center label
                            VStack(spacing: 0) {
                                Text("\(Int(macroCals))/\(Int(vm.calorieGoal))")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.primary)
                                
                                Text("cals")
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 120, height: 120)
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        // Macro legend
                        HStack(spacing: 30) {
                            // Protein
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.blue)
                                        .frame(width: 14, height: 14)
                                    Text("Protein")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                Text("\(Int(proteinCals)) cals")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Carbs
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color("darkYellow"))
                                        .frame(width: 14, height: 14)
                                    Text("Carbs")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                Text("\(Int(carbCals)) cals")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Fat
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.pink)
                                        .frame(width: 14, height: 14)
                                    Text("Fat")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                Text("\(Int(fatCals)) cals")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 40)
                
                // Generate goals button
                Button(action: {
                    if isGenerating {
                        return
                    }
                    generateGoals()
                }) {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    } else {
                        Text("Generate Personalized Goals")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("background"))
                            .foregroundColor(Color("bg"))
                            .cornerRadius(12)
                    }
                }
                .disabled(isGenerating)
                .padding(.horizontal)
            }
            .padding(.top, 16)
        }
        .background(Color("iosbg").ignoresSafeArea())
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationTitle("Update Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if !isSubmitting {
                        saveGoals()
                    }
                }) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSubmitting)
            }
        }
        .onAppear {
            // Hide tab bar when this view appears
            isTabBarVisible.wrappedValue = false
            
            // Load values directly from UserDefaults to ensure we get the most up-to-date saved values
            // This prevents showing default values after app restart
            loadGoalsFromUserDefaults()
            
            // Initialize percentage values based on current goals
            proteinPercentValue = proteinPercent * 100
            carbsPercentValue = carbPercent * 100
            fatPercentValue = fatPercent * 100
        }
        .onDisappear {
            // Show tab bar when this view disappears
            isTabBarVisible.wrappedValue = true
        }
    }
    
    // Update goals from input fields and refresh the ring
    private func updateGoalsFromInputs() {
        if let protein = Double(proteinGoal) {
            vm.proteinGoal = protein
        }
        if let carbs = Double(carbsGoal) {
            vm.carbsGoal = carbs
        }
        if let fat = Double(fatGoal) {
            vm.fatGoal = fat
        }
        
        // Force UI refresh by triggering a state update
        // The computed properties will automatically recalculate
        print("🔄 Updated goals from inputs - Protein: \(vm.proteinGoal)g, Carbs: \(vm.carbsGoal)g, Fat: \(vm.fatGoal)g")
    }
    
    // Hide keyboard helper
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // Load goals directly from UserDefaults instead of relying on ViewModel
    private func loadGoalsFromUserDefaults() {
        // Try to load from the nutritionGoalsData key first (most up-to-date)
        if let data = UserDefaults.standard.data(forKey: "nutritionGoalsData"),
           let goals = try? JSONDecoder().decode(NutritionGoals.self, from: data) {
            
            print("✅ GoalProgress: Loaded goals from UserDefaults nutritionGoalsData")
            calorieGoal = String(Int(goals.calories))
            proteinGoal = String(Int(goals.protein))
            carbsGoal = String(Int(goals.carbs))
            fatGoal = String(Int(goals.fat))
            
            // Also update the ViewModel to ensure consistency
            vm.calorieGoal = goals.calories
            vm.proteinGoal = goals.protein
            vm.carbsGoal = goals.carbs
            vm.fatGoal = goals.fat
            
        } else {
            // Fallback to UserGoalsManager if nutritionGoalsData is not available
            let userGoals = UserGoalsManager.shared.dailyGoals
            print("⚠️ GoalProgress: Fallback to UserGoalsManager defaults")
            
            calorieGoal = String(userGoals.calories)
            proteinGoal = String(userGoals.protein)
            carbsGoal = String(userGoals.carbs)
            fatGoal = String(userGoals.fat)
            
            // Also update the ViewModel to ensure consistency
            vm.calorieGoal = Double(userGoals.calories)
            vm.proteinGoal = Double(userGoals.protein)
            vm.carbsGoal = Double(userGoals.carbs)
            vm.fatGoal = Double(userGoals.fat)
        }
        
        // Recalculate remaining calories to ensure UI consistency
        vm.remainingCalories = max(0, vm.calorieGoal - vm.totalCalories)
        
        print("📊 GoalProgress: Loaded values - Calories: \(calorieGoal), Protein: \(proteinGoal)g, Carbs: \(carbsGoal)g, Fat: \(fatGoal)g")
    }
    
    // Save goals to backend
    private func saveGoals() {
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
        
        NetworkManagerTwo.shared.updateNutritionGoals(
            userEmail: vm.email,
            caloriesGoal: calories,
            proteinGoal: protein,
            carbsGoal: carbs,
            fatGoal: fat
        ) { result in
            isSubmitting = false
            
            switch result {
            case .success(let response):
                // Update view model with new values
                vm.calorieGoal = response.goals.calories
                vm.proteinGoal = response.goals.protein
                vm.carbsGoal = response.goals.carbs
                vm.fatGoal = response.goals.fat
                
                // Manually update the remaining calories to refresh the UI
                vm.remainingCalories = max(0, response.goals.calories - vm.totalCalories)
                
                // Save to UserDefaults for persistence
                let nutritionGoals = NutritionGoals(
                    calories: response.goals.calories,
                    protein: response.goals.protein,
                    carbs: response.goals.carbs,
                    fat: response.goals.fat
                )
                
                if let encoded = try? JSONEncoder().encode(nutritionGoals) {
                    UserDefaults.standard.set(encoded, forKey: "nutritionGoalsData")
                    print("✅ Saved updated nutrition goals to UserDefaults")
                }
                
                // Also update the daily calorie goal for backward compatibility
                UserDefaults.standard.set(response.goals.calories, forKey: "dailyCalorieGoal")
                
                // Update UserGoalsManager for other parts of the app
                UserGoalsManager.shared.dailyGoals = DailyGoals(
                    calories: Int(response.goals.calories),
                    protein: Int(response.goals.protein),
                    carbs: Int(response.goals.carbs),
                    fat: Int(response.goals.fat)
                )
                
                // Post notification to refresh dashboard and other views
                NotificationCenter.default.post(name: NSNotification.Name("LogsChangedNotification"), object: nil)
                print("🔄 Posted LogsChangedNotification after goal update")
                
                // Dismiss the view
                dismiss()
                
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
    
    // Generate goals using AI
    private func generateGoals() {
        isGenerating = true
        
        NetworkManagerTwo.shared.generateNutritionGoals(
            userEmail: vm.email
        ) { result in
            isGenerating = false
            
            switch result {
            case .success(let response):
                // Update input fields with the generated values
                calorieGoal = String(Int(response.goals.calories))
                proteinGoal = String(Int(response.goals.protein))
                carbsGoal = String(Int(response.goals.carbs))
                fatGoal = String(Int(response.goals.fat))
                
                // Update view model with new values
                vm.calorieGoal = response.goals.calories
                vm.proteinGoal = response.goals.protein
                vm.carbsGoal = response.goals.carbs
                vm.fatGoal = response.goals.fat
                
                // Manually update the remaining calories to refresh the UI
                vm.remainingCalories = max(0, response.goals.calories - vm.totalCalories)
                
                // Save to UserDefaults for persistence
                let nutritionGoals = NutritionGoals(
                    calories: response.goals.calories,
                    protein: response.goals.protein,
                    carbs: response.goals.carbs,
                    fat: response.goals.fat
                )
                
                if let encoded = try? JSONEncoder().encode(nutritionGoals) {
                    UserDefaults.standard.set(encoded, forKey: "nutritionGoalsData")
                    print("✅ Saved generated nutrition goals to UserDefaults")
                }
                
                // Also update the daily calorie goal for backward compatibility
                UserDefaults.standard.set(response.goals.calories, forKey: "dailyCalorieGoal")
                
                // Update UserGoalsManager for other parts of the app
                UserGoalsManager.shared.dailyGoals = DailyGoals(
                    calories: Int(response.goals.calories),
                    protein: Int(response.goals.protein),
                    carbs: Int(response.goals.carbs),
                    fat: Int(response.goals.fat)
                )
                
                // Post notification to refresh dashboard and other views
                NotificationCenter.default.post(name: NSNotification.Name("LogsChangedNotification"), object: nil)
                print("🔄 Posted LogsChangedNotification after goal generation")
                
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

// MyFitnessPal-style MacroPickerSheet
struct MacroPickerSheet: View {
    @Binding var proteinGoal: String
    @Binding var carbsGoal: String
    @Binding var fatGoal: String
    @Binding var calorieGoal: String
    @Binding var isPresented: Bool
    
    @State private var inputMode: MacroInputMode = .grams
    @State private var proteinValue: Double = 0
    @State private var carbsValue: Double = 0
    @State private var fatValue: Double = 0
    
    private var totalCalories: Double {
        max(Double(calorieGoal) ?? 2000, 1)
    }
    
    // Helper function to ensure percentages add up to exactly 100% in picker
    private func adjustedPickerPercentages() -> (protein: Double, carbs: Double, fat: Double) {
        // Calculate exact percentages first
        let exactProtein = (proteinValue * 4) / totalCalories * 100
        let exactCarbs = (carbsValue * 4) / totalCalories * 100
        let exactFat = (fatValue * 9) / totalCalories * 100
        
        // Round to integers for display
        var roundedProtein = round(exactProtein)
        var roundedCarbs = round(exactCarbs)
        var roundedFat = round(exactFat)
        
        // Calculate total and difference from 100
        let total = roundedProtein + roundedCarbs + roundedFat
        let difference = 100 - total
        
        // Apply largest remainder method to distribute the difference
        if difference != 0 {
            // Calculate remainders after rounding
            let proteinRemainder = exactProtein - roundedProtein
            let carbsRemainder = exactCarbs - roundedCarbs
            let fatRemainder = exactFat - roundedFat
            
            // Create array of (remainder, index) pairs and sort by remainder descending
            var remainders = [
                (proteinRemainder, 0), // 0 = protein
                (carbsRemainder, 1),   // 1 = carbs
                (fatRemainder, 2)      // 2 = fat
            ]
            remainders.sort { $0.0 > $1.0 }
            
            // Distribute the difference to macros with largest remainders
            for i in 0..<abs(Int(difference)) {
                let macroIndex = remainders[i % 3].1
                if difference > 0 {
                    // Add 1% to largest remainders
                    switch macroIndex {
                    case 0: roundedProtein += 1
                    case 1: roundedCarbs += 1
                    case 2: roundedFat += 1
                    default: break
                    }
                } else {
                    // Subtract 1% from largest remainders
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
    
    private var calorieDiscrepancy: Double {
        totalMacroCalories - totalCalories
    }
    
    // Validation for % mode
    private var percentagesValid: Bool {
        if inputMode == .percent {
            let total = proteinPercent + carbsPercent + fatPercent
            return abs(total - 100) < 1.0 // Allow 1% tolerance for rounding
        }
        return true // Grams mode is always valid
    }
    
    // Helper function for percent row labels
    private func percentLabel(_ value: Int, selected: Int) -> String {
        selected == value ? "\(value) %" : "\(value)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header bar (no NavigationView)
            HStack {
                // Left: X button
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Center: Segmented control
                Picker("Input Mode", selection: $inputMode) {
                    Text("%").tag(MacroInputMode.percent)
                    Text("Grams").tag(MacroInputMode.grams)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 150)
                
                Spacer()
                
                // Right: Checkmark button
                Button(action: {
                    // Update the main view values
                    proteinGoal = String(Int(proteinValue))
                    carbsGoal = String(Int(carbsValue))
                    fatGoal = String(Int(fatValue))
                    isPresented = false
                }) {
                    Image(systemName: "checkmark")
                        .font(.title2)
                        .foregroundColor(percentagesValid ? .primary : .gray)
                }
                .disabled(!percentagesValid)
            }
            .padding()
            
            // Macro labels (showing opposite of current mode)
            HStack(spacing: 0) {
                // Carbs
                VStack(spacing: 4) {
                    Text("Carbs")
                        .font(.caption)
                        .foregroundColor(Color("darkYellow"))
                    
                    if inputMode == .percent {
                        Text("\(Int(carbsValue)) g")
                            .font(.headline)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(Int(carbsPercent)) %")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Protein
                VStack(spacing: 4) {
                    Text("Protein")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if inputMode == .percent {
                        Text("\(Int(proteinValue)) g")
                            .font(.headline)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(Int(proteinPercent)) %")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Fat
                VStack(spacing: 4) {
                    Text("Fat")
                        .font(.caption)
                        .foregroundColor(.pink)
                    
                    if inputMode == .percent {
                        Text("\(Int(fatValue)) g")
                            .font(.headline)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(Int(fatPercent)) %")
                            .font(.headline)
                            .fontWeight(.semibold)
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
                                let percent = Double(newValue)
                                carbsValue = (percent * totalCalories) / 4.0 / 100
                            }
                        }
                    )) {
                        ForEach(0...500, id: \.self) { value in
                            if inputMode == .percent {
                                Text(percentLabel(value, selected: Int(carbsPercent)))
                                    .font(.title3)
                                    .tag(value)
                            } else {
                                Text("\(value)")
                                    .font(.title3)
                                    .tag(value)
                            }
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
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
                                let percent = Double(newValue)
                                proteinValue = (percent * totalCalories) / 4.0 / 100
                            }
                        }
                    )) {
                        ForEach(0...500, id: \.self) { value in
                            if inputMode == .percent {
                                Text(percentLabel(value, selected: Int(proteinPercent)))
                                    .font(.title3)
                                    .tag(value)
                            } else {
                                Text("\(value)")
                                    .font(.title3)
                                    .tag(value)
                            }
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
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
                                let percent = Double(newValue)
                                fatValue = (percent * totalCalories) / 9.0 / 100
                            }
                        }
                    )) {
                        ForEach(0...300, id: \.self) { value in
                            if inputMode == .percent {
                                Text(percentLabel(value, selected: Int(fatPercent)))
                                    .font(.title3)
                                    .tag(value)
                            } else {
                                Text("\(value)")
                                    .font(.title3)
                                    .tag(value)
                            }
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            // Validation message for % mode
            if inputMode == .percent && !percentagesValid {
                Text("Macronutrients must equal 100 %")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
            
            // Small calorie discrepancy info at bottom
            if abs(calorieDiscrepancy) > 1 {
                VStack(spacing: 2) {
                    Text("Calculated: \(Int(totalMacroCalories)) cal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Target: \(Int(totalCalories)) cal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .onAppear {
            // Initialize values from current goals (fix fat defaulting to 0)
            proteinValue = max(Double(proteinGoal) ?? 0, 0)
            carbsValue = max(Double(carbsGoal) ?? 0, 0) 
            fatValue = max(Double(fatGoal) ?? 0, 0)
        }
    }
}

#Preview {
    GoalProgress()
        .environmentObject(DayLogsViewModel())
}
