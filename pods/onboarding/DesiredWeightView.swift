//
//  DesiredWeightView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/18/25.
//

import SwiftUI
import UIKit

struct DesiredWeightView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedWeight: Double = {
        // Check if user selected imperial or metric
        let isImperial = UserDefaults.standard.bool(forKey: "isImperial")
        
        if isImperial {
            // Get pounds for imperial
            return Double(UserDefaults.standard.integer(forKey: "weightPounds"))
        } else {
            // Get kilograms for metric
            return Double(UserDefaults.standard.integer(forKey: "weightKilograms"))
        }
    }()
    @State private var navigateToNextStep = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
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
                
                // Progress indicator
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .desiredWeight), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title
            VStack(alignment: .leading, spacing: 12) {
                Text("What's your desired weight?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 40)
            
            Spacer()
            
            // Weight display
            Text(String(format: "%.1f lbs", selectedWeight))
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 24)
            
            // Weight ruler picker (range: 50.0...500.0)
            WeightRulerView(
                selectedWeight: $selectedWeight,
                range: 50.0...500.0,
                step: 0.1
            )
            .frame(height: 80)
            
            Spacer()
            
            // Continue button
            VStack {
                NavigationLink(destination: GoalTimeView(), isActive: $navigateToNextStep) {
                    Button(action: {
                        HapticFeedback.generate()
                        saveDesiredWeight()
                        navigateToNextStep = true
                    }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .padding(.bottom, 24)
            .background(Material.ultraThin)
        }
        .background(Color(UIColor.systemBackground))
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("DesiredWeightView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(4, forKey: "onboardingFlowStep") // Raw value for this step
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 DesiredWeightView appeared - saved current step")
        }
    }
    
    private func saveDesiredWeight() {
        let isImperial = UserDefaults.standard.bool(forKey: "isImperial")
        
        if isImperial {
            // Save imperial weight
            UserDefaults.standard.set(selectedWeight, forKey: "desiredWeightPounds")
            
            // Convert and save metric weight for API
            let kilograms = selectedWeight * 0.45359237 // Using precise conversion factor
            UserDefaults.standard.set(kilograms, forKey: "desiredWeightKilograms")
        } else {
            // Save metric weight
            UserDefaults.standard.set(selectedWeight, forKey: "desiredWeightKilograms")
            
            // Convert and save imperial weight for UI
            let pounds = selectedWeight / 0.45359237 // Using precise conversion factor
            UserDefaults.standard.set(pounds, forKey: "desiredWeightPounds")
        }
        
        // Automatically determine fitness goal based on weight difference
        let currentWeight = isImperial ? 
            UserDefaults.standard.double(forKey: "weightPounds") : 
            UserDefaults.standard.double(forKey: "weightKilograms")
        
        let weightDifference = selectedWeight - currentWeight
        
        // Set the appropriate fitness goal
        let fitnessGoal: String
        if abs(weightDifference) < 1.0 {
            // If the difference is less than 1 lb/kg, consider it "maintain"
            fitnessGoal = "maintain"
        } else if weightDifference < 0 {
            // Desired weight is less than current weight: lose weight
            fitnessGoal = "loseWeight"
        } else {
            // Desired weight is more than current weight: gain weight
            fitnessGoal = "gainWeight"
        }
        
        // Save the determined fitness goal
        UserDefaults.standard.set(fitnessGoal, forKey: "fitnessGoal")
        print("📊 Automatically determined fitness goal: \(fitnessGoal)")
        
        // Also save the current step before navigating
        UserDefaults.standard.set("DesiredWeightView", forKey: "currentOnboardingStep")
        UserDefaults.standard.set(4, forKey: "onboardingFlowStep") // Updated raw value
        UserDefaults.standard.synchronize()
    }
}

// Custom horizontal ruler with snapping and decimals
struct WeightRulerView: View {
    @Binding var selectedWeight: Double
    let range: ClosedRange<Double>
    let step: Double
    private let tickSpacing: CGFloat = 8
    @Environment(\.colorScheme) var colorScheme

    @State private var baseOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let totalSteps = Int((range.upperBound - range.lowerBound) / step)
            let centerX = geometry.size.width / 2
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemBackground))
                    .frame(height: 60)
                
                Rectangle()
                    .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6))
                    .frame(height: 60)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: centerX)
                            Spacer()
                        }
                    )
                
                // Center indicator
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2, height: 60)
                
                // Ruler ticks
                HStack(spacing: tickSpacing) {
                    ForEach(0...totalSteps, id: \.self) { i in
                        let weight = range.lowerBound + Double(i) * step
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(i % Int(1/step) == 0 ? Color.primary : Color.secondary)
                                .frame(width: i % Int(1/step) == 0 ? 2 : 1,
                                       height: i % Int(1/step) == 0 ? 40 : 20)
                            if i % Int(1/step) == 0 {
                                Text(String(format: "%.0f", weight))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .offset(x: baseOffset + dragOffset)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { g in
                        dragOffset = g.translation.width
                        let rawIndex = -(baseOffset + dragOffset - centerX) / tickSpacing
                        let clamped = min(max(rawIndex, 0), CGFloat(totalSteps))
                        let roundedIndex = round(clamped)
                        selectedWeight = range.lowerBound + Double(roundedIndex) * step

                        // Haptic on major tick (every 1.0 lb)
                        if Int(roundedIndex) % Int(1.0/step) == 0 {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.prepare()
                            generator.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        let idx = CGFloat((selectedWeight - range.lowerBound) / step)
                        let newBase = -idx * tickSpacing + centerX
                        withAnimation(.spring()) {
                            baseOffset = newBase
                            dragOffset = 0
                        }
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
    DesiredWeightView()
}
