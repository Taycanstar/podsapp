//
//  GoalProgress.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/25.
//

import SwiftUI

struct GoalProgress: View {
    @EnvironmentObject var vm: DayLogsViewModel
    @Environment(\.dismiss) private var dismiss
    
    // State to hold temporary values while editing
    @State private var calorieGoal: String = ""
    @State private var proteinGoal: String = ""
    @State private var carbsGoal: String = ""
    @State private var fatGoal: String = ""
    
    @State private var isSubmitting = false
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                            }
                            .padding()
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
                        Text("Generate Goals with AI")
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
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationTitle("Goals")
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
            // Initialize fields with current values
            calorieGoal = String(Int(vm.calorieGoal))
            proteinGoal = String(Int(vm.proteinGoal))
            carbsGoal = String(Int(vm.carbsGoal))
            fatGoal = String(Int(vm.fatGoal))
        }
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
