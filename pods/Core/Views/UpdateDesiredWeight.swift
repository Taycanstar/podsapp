//
//  UpdateDesiredWeight.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/25.
//

import SwiftUI

struct UpdateDesiredWeight: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var vm: DayLogsViewModel
    
    @State private var isImperial = true
    @State private var selectedWeight: Double = 160 // Default in pounds
    
    var body: some View {
        VStack(spacing: 0) {
            // Imperial/Metric Toggle
            HStack(spacing: 20) {
                Text("Imperial")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isImperial ? .primary : .secondary)
                
                Toggle("", isOn: $isImperial)
                    .labelsHidden()
                    .onChange(of: isImperial) { _ in
                        // Convert weight when switching between imperial and metric
                        if isImperial {
                            // Convert kg to lbs
                            selectedWeight = selectedWeight * 2.20462
                        } else {
                            // Convert lbs to kg
                            selectedWeight = selectedWeight / 2.20462
                        }
                    }
                
                Text("Metric")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(!isImperial ? .primary : .secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
            
            // Weight display
            Text(String(format: "%.1f %@", selectedWeight, isImperial ? "lbs" : "kg"))
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 24)
            
            // Weight picker
            Picker("Weight", selection: $selectedWeight) {
                ForEach(Array(stride(from: isImperial ? 50.0 : 20.0, 
                                    through: isImperial ? 400.0 : 180.0, 
                                    by: 0.5)), id: \.self) { weight in
                    Text("\(weight, specifier: "%.1f") \(isImperial ? "lbs" : "kg")")
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(height: 150)
            
            // Description text
            Text("Set your target weight goal. This will help track your progress and set appropriate nutrition targets.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 20)
            
            Spacer()
            
            // Save button
            Button(action: {
                saveWeightGoal()
                dismiss()
            }) {
                Text("Save Goal")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .padding()
        }
        .padding()
        .navigationBarTitle("Weight Goal", displayMode: .inline)
        .onAppear {
            // First try to get from view model
            if vm.desiredWeightLbs > 0 {
                if isImperial {
                    selectedWeight = vm.desiredWeightLbs
                } else {
                    selectedWeight = vm.desiredWeightKg
                }
            }
            // Then try UserDefaults if not available in ViewModel
            else if let goalWeight = UserDefaults.standard.value(forKey: "weightGoalPounds") as? Double {
                if isImperial {
                    selectedWeight = goalWeight
                } else {
                    selectedWeight = goalWeight / 2.20462 // Convert lbs to kg
                }
            } else if let goalWeight = UserDefaults.standard.value(forKey: "weightGoalKilograms") as? Double {
                if isImperial {
                    selectedWeight = goalWeight * 2.20462 // Convert kg to lbs
                } else {
                    selectedWeight = goalWeight
                }
            } else if vm.weight > 0 {
                // If no goal is set, initialize with current weight
                if isImperial {
                    selectedWeight = vm.weight * 2.20462 // Convert kg to lbs
                } else {
                    selectedWeight = vm.weight
                }
            }
        }
    }
    
    private func saveWeightGoal() {
        // Convert to kg for storage if in imperial
        let weightInKg = isImperial ? selectedWeight / 2.20462 : selectedWeight
        let weightInLbs = isImperial ? selectedWeight : selectedWeight * 2.20462
        
        // Save to UserDefaults
        UserDefaults.standard.set(weightInLbs, forKey: "weightGoalPounds")
        UserDefaults.standard.set(weightInKg, forKey: "weightGoalKilograms")
        
        // Update the ViewModel
        vm.desiredWeightKg = weightInKg
        vm.desiredWeightLbs = weightInLbs
        
        // Update nutrition goals on the server
        updateNutritionGoalsOnServer(desiredWeightKg: weightInKg, desiredWeightLbs: weightInLbs)
        
        // Post notification to refresh related views
        NotificationCenter.default.post(name: Notification.Name("WeightGoalUpdatedNotification"), object: nil)
    }
    
    private func updateNutritionGoalsOnServer(desiredWeightKg: Double, desiredWeightLbs: Double) {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            print("Error: No user email found")
            return
        }
        
        // Prepare the request parameters
        let parameters: [String: Any] = [
            "user_email": userEmail,
            "desired_weight_kg": desiredWeightKg,
            "desired_weight_lbs": desiredWeightLbs
        ]
        
        // Convert parameters to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
            print("Error converting parameters to JSON")
            return
        }
        
        // Create the request
        guard let url = URL(string: "https://fitness-cal.stumpwm.org/update_nutrition_goals/") else {
            print("Error creating URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Perform the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error updating nutrition goals: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                return
            }
            
            if httpResponse.statusCode == 200 {
                print("Successfully updated weight goal on server")
            } else {
                print("Server error: \(httpResponse.statusCode)")
                if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                    print("Server error message: \(errorMessage)")
                }
            }
        }.resume()
    }
}

#Preview {
    NavigationView {
        UpdateDesiredWeight()
            .environmentObject(DayLogsViewModel())
    }
}
