//
//  HeightWeightView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/7/25.
//

import SwiftUI

struct HeightWeightView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var unitSelection = 0 // 0 = Imperial, 1 = Metric
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
    
    // Computed property for convenience
    private var isImperial: Bool {
        return unitSelection == 0
    }
    
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
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .heightWeight), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("Height & weight")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("This will be used to calibrate your custom plan.")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 40)

            Spacer()
            
            // Imperial/Metric Segmented Control
            Picker("Unit System", selection: $unitSelection) {
                Text("Imperial").tag(0)
                Text("Metric").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.bottom, 40)
            .onChange(of: unitSelection) { _ in
                HapticFeedback.generate()
            }
            
            // Height and Weight section
            HStack(spacing: 30) {
                // Height section
                VStack(alignment: .leading, spacing: 20) {
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
                
                // Weight section
                VStack(alignment: .leading, spacing: 20) {
                    Text("Weight")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
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
        .background(Color(UIColor.systemBackground))
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
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("HeightWeightView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(2, forKey: "onboardingFlowStep") // Raw value for this step
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 HeightWeightView appeared - saved current step")
        }
    }
    
    private func saveHeightAndWeight() {
        // Convert measurements to metric for storage
        var heightInCm: Double
        var weightInKg: Double
        
        if isImperial {
            // Convert imperial to metric
            let totalInches = (selectedFeet * 12) + selectedInches
            heightInCm = Double(totalInches) * 2.54
            weightInKg = Double(selectedPounds) / 2.20462
        } else {
            // Already in metric
            heightInCm = Double(selectedCentimeters)
            weightInKg = Double(selectedKilograms)
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(isImperial, forKey: "isImperial")
        UserDefaults.standard.set(heightInCm, forKey: "heightCentimeters")
        UserDefaults.standard.set(weightInKg, forKey: "weightKilograms")
        
        if isImperial {
            UserDefaults.standard.set(selectedFeet, forKey: "heightFeet")
            UserDefaults.standard.set(selectedInches, forKey: "heightInches")
            UserDefaults.standard.set(selectedPounds, forKey: "weightPounds")
        } else {
            UserDefaults.standard.set(selectedCentimeters, forKey: "heightCentimeters")
            UserDefaults.standard.set(selectedKilograms, forKey: "weightKilograms")
        }
        
        print("Saved height: \(heightInCm) cm, weight: \(weightInKg) kg")
    }
}

// Custom scroll wheel picker component
struct ScrollViewPicker: View {
    @Binding var selection: Int
    let range: ClosedRange<Int>
    let suffix: String
    @Environment(\.colorScheme) var colorScheme
    
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
        .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    HeightWeightView()
}
