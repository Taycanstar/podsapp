//
//  UpdateWeight.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/25.
//

import SwiftUI

struct UpdateWeight: View {
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
            
            Spacer()
            
            // Save button
            Button(action: {
                saveWeight()
                dismiss()
            }) {
                Text("Save")
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
        .navigationBarTitle("Update Weight", displayMode: .inline)
        .onAppear {
            // Initialize with current weight if available
            if vm.weight > 0 {
                if isImperial {
                    selectedWeight = vm.weight * 2.20462 // Convert kg to lbs
                } else {
                    selectedWeight = vm.weight
                }
            }
        }
    }
    
    private func saveWeight() {
        // Convert to kg for storage if in imperial
        let weightInKg = isImperial ? selectedWeight / 2.20462 : selectedWeight
        
        // Save to UserDefaults
        if isImperial {
            UserDefaults.standard.set(selectedWeight, forKey: "weightPounds")
            UserDefaults.standard.set(weightInKg, forKey: "weightKilograms")
        } else {
            UserDefaults.standard.set(selectedWeight, forKey: "weightKilograms")
            UserDefaults.standard.set(selectedWeight * 2.20462, forKey: "weightPounds")
        }
        
        // Update the viewModel
        vm.weight = weightInKg
        
        // Call API to log weight
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("Error: No user email found")
            return
        }
        
        NetworkManagerTwo.shared.logWeight(
            userEmail: email,
            weightKg: weightInKg,
            notes: "Logged from dashboard"
        ) { result in
            switch result {
            case .success(let response):
                print("Weight successfully logged: \(response.weightKg) kg")
                
                // Post notification to refresh health data
                NotificationCenter.default.post(
                    name: Notification.Name("WeightLoggedNotification"), 
                    object: nil
                )
                
            case .failure(let error):
                print("Error logging weight: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    NavigationView {
        UpdateWeight()
            .environmentObject(DayLogsViewModel())
    }
}
