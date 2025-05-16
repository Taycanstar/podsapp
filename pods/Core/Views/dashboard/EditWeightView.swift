//
//  EditWeightView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/16/25.
//

import SwiftUI

struct EditWeightView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var vm: DayLogsViewModel
    
    @State private var isImperial = true
    @State private var selectedWeight: Double = 160 // Default in pounds
    
    var body: some View {
        NavigationView {
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
                
                // Weight ruler picker
                WeightRulerView(
                    selectedWeight: $selectedWeight,
                    range: isImperial ? 50.0...500.0 : 20.0...220.0,
                    step: 0.1
                )
                .frame(height: 80)
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("Update Weight", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                saveWeight()
                dismiss()
            }
            .foregroundColor(.accentColor))
        }
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
        
        // TODO: Add API call to save weight to server
        print("Saving weight: \(weightInKg) kg")
    }
}

