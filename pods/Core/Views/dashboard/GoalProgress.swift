//
//  GoalProgress.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/25.
//

import SwiftUI

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
    @State private var focusedField: String? = nil
    
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
    
    private var proteinPercent: Double {
        proteinCals / totalGoalCalories
    }
    
    private var carbPercent: Double {
        carbCals / totalGoalCalories
    }
    
    private var fatPercent: Double {
        fatCals / totalGoalCalories
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
                                Spacer()
                                TextField("0", text: $proteinGoal)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .onTapGesture {
                                        focusedField = "protein"
                                    }
                            }
                            .padding()
                            
                            Divider()
                                .padding(.leading)
                            
                            HStack {
                                Text("Carbs (g)")
                                Spacer()
                                TextField("0", text: $carbsGoal)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .onTapGesture {
                                        focusedField = "carbs"
                                    }
                            }
                            .padding()
                            
                            Divider()
                                .padding(.leading)
                            
                            HStack {
                                Text("Fat (g)")
                                Spacer()
                                TextField("0", text: $fatGoal)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .onTapGesture {
                                        focusedField = "fat"
                                    }
                                    .toolbar {
                                        ToolbarItemGroup(placement: .keyboard) {
                                            Button("Clear") {
                                                clearFocusedInput()
                                            }
                                            Spacer()
                                            Button("Done") {
                                                updateGoalsFromInputs()
                                                hideKeyboard()
                                            }
                                        }
                                    }
                            }
                            .padding()
                        }
                    }
                }
                .padding(.horizontal)
                
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
    
    // Clear the currently focused input field
    private func clearFocusedInput() {
        switch focusedField {
        case "protein":
            proteinGoal = ""
        case "carbs":
            carbsGoal = ""
        case "fat":
            fatGoal = ""
        default:
            fatGoal = "" // fallback
        }
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

#Preview {
    GoalProgress()
        .environmentObject(DayLogsViewModel())
}
