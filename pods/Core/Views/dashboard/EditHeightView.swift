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
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    @State private var selectedDate = Date()
    
    // Imperial units
    @State private var selectedFeet = 5
    @State private var selectedInches = 9
    
    // Metric units
    @State private var heightCmText = ""
    @FocusState private var isHeightFieldFocused: Bool
    
    @State private var showingHeightPicker = false
    
    // Available ranges for imperial
    let feetRange = 2...8
    let inchesRange = 0...11
    
    // Computed properties for unit display
    private var heightUnit: String {
        switch viewModel.unitsSystem {
        case .imperial:
            return "ft"
        case .metric:
            return "cm"
        }
    }
    
    private var heightPlaceholder: String {
        switch viewModel.unitsSystem {
        case .imperial:
            return "Select height"
        case .metric:
            return "Enter height in cm"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Combined Date and Height Card
                VStack(spacing: 0) {
                    // Date Row
                    HStack {
                        Text("Date")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Height Input Row - Different based on units system
                    if viewModel.unitsSystem == .imperial {
                        // Imperial: Height Button Row with Picker
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingHeightPicker.toggle()
                            }
                        }) {
                            HStack {
                                Text(heightUnit)
                                    .font(.system(size: 17))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(selectedFeet)' \(selectedInches)\"")
                                    .font(.system(size: 17))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Inline Height Picker (expands/collapses)
                        if showingHeightPicker {
                            Divider()
                                .padding(.horizontal, 16)
                            
                            HStack(spacing: 0) {
                                // Feet Picker
                                Picker("Feet", selection: $selectedFeet) {
                                    ForEach(feetRange, id: \.self) { feet in
                                        Text("\(feet) ft").tag(feet)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(maxWidth: .infinity)
                                
                                // Inches Picker
                                Picker("Inches", selection: $selectedInches) {
                                    ForEach(inchesRange, id: \.self) { inches in
                                        Text("\(inches) in").tag(inches)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(maxWidth: .infinity)
                            }
                            .frame(height: 150)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                    } else {
                        // Metric: Height Text Field
                        HStack {
                            Text(heightUnit)
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            TextField("", text: $heightCmText)
                                .keyboardType(.decimalPad)
                                .focused($isHeightFieldFocused)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .background(Color("iosnp"))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
            }
            .background(Color("iosbg"))
            .navigationBarTitle("Height", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.accentColor),
                trailing: Button("Add") {
                    saveHeight()
                    dismiss()
                }
                .foregroundColor(.accentColor)
                .disabled(viewModel.unitsSystem == .metric && heightCmText.isEmpty)
            )
        }
        .onAppear {
            // Initialize with current height if available
            if vm.height > 0 {
                switch viewModel.unitsSystem {
                case .imperial:
                    // Calculate imperial values
                    let totalInches = vm.height / 2.54
                    selectedFeet = Int(totalInches / 12)
                    selectedInches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
                case .metric:
                    // Display in cm
                    heightCmText = String(format: "%.1f", vm.height)
                }
            }
            
            // Auto-focus for metric text field
            if viewModel.unitsSystem == .metric {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isHeightFieldFocused = true
                }
            }
        }
    }
    
    private func saveHeight() {
        let heightInCm: Double
        
        switch viewModel.unitsSystem {
        case .imperial:
            // Convert imperial to metric
            let totalInches = (selectedFeet * 12) + selectedInches
            heightInCm = Double(totalInches) * 2.54
            
            // Save imperial values to UserDefaults
            UserDefaults.standard.set(selectedFeet, forKey: "heightFeet")
            UserDefaults.standard.set(selectedInches, forKey: "heightInches")
            
        case .metric:
            // Input is already in cm
            guard let inputHeight = Double(heightCmText) else {
                print("Error: Invalid height value")
                return
            }
            
            heightInCm = inputHeight
            
            // Calculate and save imperial equivalents
            let totalInches = heightInCm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
            
            UserDefaults.standard.set(feet, forKey: "heightFeet")
            UserDefaults.standard.set(inches, forKey: "heightInches")
        }
        
        // Save cm value to UserDefaults
        UserDefaults.standard.set(heightInCm, forKey: "heightCentimeters")
        
        // Update the viewModel (always stored in cm)
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
