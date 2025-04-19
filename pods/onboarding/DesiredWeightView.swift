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
    
    // Get the selected goal from UserDefaults
    private var goal: String {
        return UserDefaults.standard.string(forKey: "fitnessGoal") ?? "Maintain"
    }
    
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 40)
            
            Spacer()
            
            // Goal display
            Text(goal)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .padding(.bottom, 10)
            
            // Weight display
            Text(String(format: "%.1f lbs", selectedWeight))
                .font(.system(size: 44, weight: .bold))
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
                NavigationLink(destination: GoalInfoView(), isActive: $navigateToNextStep) {
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
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
    }
    
    private func saveDesiredWeight() {
        // Save the selected weight to UserDefaults
        UserDefaults.standard.set(selectedWeight, forKey: "desiredWeight")
    }
}

// Custom horizontal ruler with snapping and decimals
struct WeightRulerView: View {
    @Binding var selectedWeight: Double
    let range: ClosedRange<Double>
    let step: Double
    private let tickSpacing: CGFloat = 8

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
                    .fill(Color(.systemGray6))
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
