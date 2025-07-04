//
//  EditHeightView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/16/25.
//

import SwiftUI

struct EditHeightView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var vm: DayLogsViewModel
    
    @State private var unitSelection = 0 // 0 = Imperial, 1 = Metric
    
    // Imperial measurements
    @State private var selectedFeet = 5
    @State private var selectedInches = 9
    
    // Metric measurements
    @State private var selectedCentimeters = 175
    
    // Available ranges
    let feetRange = 2...8
    let inchesRange = 0...11
    let centimetersRange = 100...250
    
    // Computed property for convenience
    private var isImperial: Bool {
        return unitSelection == 0
    }
    
    var body: some View {
        NavigationView {
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
                    if isImperial {
                        // Convert from metric to imperial
                        let totalInches = Double(selectedCentimeters) / 2.54
                        selectedFeet = Int(totalInches / 12)
                        selectedInches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
                    } else {
                        // Convert from imperial to metric
                        let totalInches = (selectedFeet * 12) + selectedInches
                        selectedCentimeters = Int(Double(totalInches) * 2.54)
                    }
                }
                
                // Height section
                VStack(alignment: .center, spacing: 20) {
                    Text("Height")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isImperial {
                        // Imperial height pickers (feet and inches)
                        HStack(spacing: 10) {
                            // Feet picker
                            ScrollViewPicker(
                                selection: $selectedFeet,
                                range: feetRange,
                                suffix: "ft"
                            )
                            .frame(width: 100, height: 200)
                            
                            // Inches picker
                            ScrollViewPicker(
                                selection: $selectedInches,
                                range: inchesRange,
                                suffix: "in"
                            )
                            .frame(width: 100, height: 200)
                        }
                    } else {
                        // Metric height picker (centimeters)
                        ScrollViewPicker(
                            selection: $selectedCentimeters,
                            range: centimetersRange,
                            suffix: "cm"
                        )
                        .frame(width: 100, height: 200)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("Update Height", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                saveHeight()
                dismiss()
            }
            .foregroundColor(.accentColor))
        }
        .onAppear {
            // Initialize with current height if available
            if vm.height > 0 {
                // Set metric value
                selectedCentimeters = Int(vm.height)
                
                // Calculate imperial values
                let totalInches = vm.height / 2.54
                selectedFeet = Int(totalInches / 12)
                selectedInches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
            }
        }
    }
    
    private func saveHeight() {
        var heightInCm: Double
        
        if isImperial {
            // Convert imperial to metric
            let totalInches = (selectedFeet * 12) + selectedInches
            heightInCm = Double(totalInches) * 2.54
        } else {
            // Already in metric
            heightInCm = Double(selectedCentimeters)
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(isImperial, forKey: "isImperial")
        
        if isImperial {
            UserDefaults.standard.set(selectedFeet, forKey: "heightFeet")
            UserDefaults.standard.set(selectedInches, forKey: "heightInches")
            UserDefaults.standard.set(heightInCm, forKey: "heightCentimeters")
        } else {
            UserDefaults.standard.set(selectedCentimeters, forKey: "heightCentimeters")
            UserDefaults.standard.set(selectedFeet, forKey: "heightFeet")
            UserDefaults.standard.set(selectedInches, forKey: "heightInches")
        }
        
        // Update the viewModel
        vm.height = heightInCm
        
        // Call API to log height using NetworkManagerTwo
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("Error: No user email found")
            return
        }
        
        NetworkManagerTwo.shared.logHeight(
            userEmail: email,
            heightCm: heightInCm,
            notes: "Logged from dashboard"
        ) { result in
            switch result {
            case .success(let response):
                print("Height successfully logged: \(response.heightCm) cm")
                
                // Post notification to refresh health data
                NotificationCenter.default.post(name: Notification.Name("HeightLoggedNotification"), object: nil)
                
            case .failure(let error):
                print("Error logging height: \(error.localizedDescription)")
            }
        }
    }
}
