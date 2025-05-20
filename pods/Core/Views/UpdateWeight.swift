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
            
            // Weight ruler picker
            WeightRulerView2(
                selectedWeight: $selectedWeight,
                range: isImperial ? 50.0...400.0 : 20.0...180.0,
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

// Custom horizontal ruler with snapping and decimals
struct WeightRulerView2: View {
    @Binding var selectedWeight: Double
    let range: ClosedRange<Double>
    let step: Double
    private let tickSpacing: CGFloat = 8
    @Environment(\.colorScheme) var colorScheme

    @State private var baseOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var lastHapticIndex: Int = -1

    var body: some View {
        GeometryReader { geometry in
            let totalSteps = Int((range.upperBound - range.lowerBound) / step)
            let majorStepCount = Int((1.0 / step).rounded())
            let halfStepCount = Int((0.5 / step).rounded())
            let centerX = geometry.size.width / 2
            let epsilon = step / 2
            ZStack {
                // Ruler ticks
                HStack(spacing: tickSpacing) {
                    ForEach(0...totalSteps, id: \.self) { i in
                        let weight = range.lowerBound + Double(i) * step
                        let weightTenth = Int(round(weight * 10))        // Represent weight to 0.1 precision as an Int
                        let mod = weightTenth % 10                       // 0...9
                        let isMajor = mod == 0                           // .0 positions
                        let isHalf  = mod == 5                           // .5 positions
                        // Heights: major = 40, half = 30, minor = 20
                        let lineHeight: CGFloat = isMajor ? 40 : (isHalf ? 30 : 20)
                        // Colors: major primary, others secondary
                        let lineColor: Color = isMajor ? .primary : .secondary
                        // Width: always 1 for minor/half, 2 for major
                        let lineWidth: CGFloat = isMajor ? 2 : 1

                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(lineColor)
                                .frame(width: lineWidth, height: lineHeight)
                            if isMajor {
                                Text(String(format: "%.0f", weight))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .offset(x: baseOffset + dragOffset)
                .animation(.interactiveSpring(response: 0.30, dampingFraction: 0.80), value: baseOffset)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 4, height: geometry.size.height - 10)
                    .zIndex(1),
                alignment: .center
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { g in
                        dragOffset = g.translation.width
                        let rawIndex = -(baseOffset + dragOffset - centerX) / tickSpacing
                        let clamped = min(max(rawIndex, 0), CGFloat(totalSteps))
                        let roundedIndex = round(clamped)
                        selectedWeight = range.lowerBound + Double(roundedIndex) * step

                        let currentIndex = Int(roundedIndex)
                        if currentIndex != lastHapticIndex {
                            // Subtle feedback on every tick
                            UISelectionFeedbackGenerator().selectionChanged()
                            // Stronger feedback on major ticks (integer weights)
                            let currentWeightTenth = Int(round(selectedWeight * 10))
                            if currentWeightTenth % 10 == 0 {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                            lastHapticIndex = currentIndex
                        }
                    }
                    .onEnded { _ in
                        let idx = CGFloat((selectedWeight - range.lowerBound) / step)
                        let newBase = -idx * tickSpacing + centerX
                        baseOffset = newBase
                        dragOffset = 0
                        lastHapticIndex = -1
                    }
            )
            .onAppear {
                let idx = CGFloat((selectedWeight - range.lowerBound) / step)
                baseOffset = -idx * tickSpacing + centerX
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
