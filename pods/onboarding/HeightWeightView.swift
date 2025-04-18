//
//  HeightWeightView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/7/25.
//

import SwiftUI

struct HeightWeightView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isImperial = true
    @State private var navigateToDob = false
    
    // Imperial measurements
    @State private var selectedFeet = 5
    @State private var selectedInches = 9
    @State private var selectedPounds = 160
    
    // Metric measurements
    @State private var selectedCentimeters = 175
    @State private var selectedKilograms = 73
    
    // Available ranges
    let feetRange = 2...8
    let inchesRange = 0...11
    let poundsRange = 50...500
    let centimetersRange = 100...250
    let kilogramsRange = 30...250
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation and progress bar
            VStack(spacing: 16) {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // Progress bar - 3/5 completed (60%)
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: UIScreen.main.bounds.width * 0.6, height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("Height & weight")
                    .font(.system(size: 32, weight: .bold))
                
                Text("This will be used to calibrate your custom plan.")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 40)
            
            // Imperial/Metric Toggle
            HStack(spacing: 20) {
                Text("Imperial")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isImperial ? .primary : .secondary)
                
                Toggle("", isOn: $isImperial)
                    .labelsHidden()
                    .onChange(of: isImperial) { _ in
                        HapticFeedback.generate()
                    }
                
                Text("Metric")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(!isImperial ? .primary : .secondary)
            }
            .padding(.bottom, 40)
            
            // Height and Weight section
            HStack(spacing: 30) {
                // Height section
                VStack(alignment: .leading, spacing: 20) {
                    Text("Height")
                        .font(.system(size: 20, weight: .semibold))
                    
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
                
                // Weight section
                VStack(alignment: .leading, spacing: 20) {
                    Text("Weight")
                        .font(.system(size: 20, weight: .semibold))
                    
                    if isImperial {
                        // Imperial weight picker (pounds)
                        ScrollViewPicker(
                            selection: $selectedPounds,
                            range: poundsRange,
                            suffix: "lb"
                        )
                        .frame(width: 100, height: 200)
                    } else {
                        // Metric weight picker (kilograms)
                        ScrollViewPicker(
                            selection: $selectedKilograms,
                            range: kilogramsRange,
                            suffix: "kg"
                        )
                        .frame(width: 100, height: 200)
                    }
                }
            }
            
            Spacer()
            
            // Continue button
            VStack {
                Button(action: {
                    HapticFeedback.generate()
                    saveHeightAndWeight()
                    navigateToDob = true
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .padding(.bottom, 24)
            .background(Material.ultraThin)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: DobView(),
                isActive: $navigateToDob
            ) {
                EmptyView()
            }
        )
    }
    
    private func saveHeightAndWeight() {
        UserDefaults.standard.set(isImperial, forKey: "isImperial")
        
        if isImperial {
            // Save imperial measurements
            UserDefaults.standard.set(selectedFeet, forKey: "heightFeet")
            UserDefaults.standard.set(selectedInches, forKey: "heightInches")
            UserDefaults.standard.set(selectedPounds, forKey: "weightPounds")
            
            // Also calculate and save metric for API calls
            let totalInches = (selectedFeet * 12) + selectedInches
            let centimeters = Int(Double(totalInches) * 2.54)
            let kilograms = Int(Double(selectedPounds) * 0.453592)
            
            UserDefaults.standard.set(centimeters, forKey: "heightCentimeters")
            UserDefaults.standard.set(kilograms, forKey: "weightKilograms")
        } else {
            // Save metric measurements
            UserDefaults.standard.set(selectedCentimeters, forKey: "heightCentimeters")
            UserDefaults.standard.set(selectedKilograms, forKey: "weightKilograms")
            
            // Also calculate and save imperial for UI display
            let totalInches = Int(Double(selectedCentimeters) / 2.54)
            let feet = totalInches / 12
            let inches = totalInches % 12
            let pounds = Int(Double(selectedKilograms) / 0.453592)
            
            UserDefaults.standard.set(feet, forKey: "heightFeet")
            UserDefaults.standard.set(inches, forKey: "heightInches")
            UserDefaults.standard.set(pounds, forKey: "weightPounds")
        }
    }
}

// Custom scroll wheel picker component
struct ScrollViewPicker: View {
    @Binding var selection: Int
    let range: ClosedRange<Int>
    let suffix: String
    
    var body: some View {
        VStack {
            Picker("", selection: $selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value) \(suffix)")
                        .font(.system(size: 18))
                        .tag(value)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(height: 150)
            .clipped()
            .onChange(of: selection) { _ in
                HapticFeedback.generateLigth()
            }
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    HeightWeightView()
}
