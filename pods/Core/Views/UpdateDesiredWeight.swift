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
    
    @State private var unitSelection = 0 // 0 = Imperial, 1 = Metric
    @State private var selectedWeight: Double = 160 // Default in pounds
    
    // Computed property for convenience
    private var isImperial: Bool {
        return unitSelection == 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Imperial/Metric Segmented Control
            Picker("Unit System", selection: $unitSelection) {
                Text("Imperial").tag(0)
                Text("Metric").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 40)
            .onChange(of: unitSelection) { _ in
                // Convert weight when switching between imperial and metric
                if isImperial {
                    // Convert kg to lbs
                    selectedWeight = selectedWeight * 2.20462
                } else {
                    // Convert lbs to kg
                    selectedWeight = selectedWeight / 2.20462
                }
            }
            
            // Weight display
            Text(String(format: "%.1f %@", selectedWeight, isImperial ? "lbs" : "kg"))
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 24)
            
            // Weight ruler picker
            WeightRulerView2(
                selectedWeight: $selectedWeight,
                range: isImperial ? 50.0...400.0 : 20.0...180.0,
                step: 0.1
            )
            .frame(height: 80)
            
            // Description text
            Text("Set your target weight goal. This will help track your progress and set appropriate nutrition targets.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 20)
            
            Spacer()
        }
        .padding()
        .navigationBarTitle("Weight Goal", displayMode: .inline)
        .navigationBarItems(trailing: Button("Done") {
            saveWeightGoal()
            dismiss()
        }
        .foregroundColor(.accentColor))
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
        
        NetworkManagerTwo.shared.updateNutritionGoals(
            userEmail: userEmail,
            overrides: [:],
            removeOverrides: [],
            clearAll: false,
            additionalFields: [
                "desired_weight_kg": desiredWeightKg,
                "desired_weight_lbs": desiredWeightLbs
            ]
        ) { result in
            switch result {
            case .success:
                print("Successfully updated weight goal on server")
            case .failure(let error):
                print("Error updating nutrition goals: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    NavigationView {
        UpdateDesiredWeight()
            .environmentObject(DayLogsViewModel())
    }
}
