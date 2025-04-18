//
//  DesiredWeightView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/18/25.
//

import SwiftUI

struct DesiredWeightView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedWeight: Double = 170.0
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
                        .frame(width: UIScreen.main.bounds.width * 0.9, height: 4)
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
            Text("\(String(format: "%.1f", selectedWeight)) lbs")
                .font(.system(size: 44, weight: .bold))
                .padding(.bottom, 24)
            
            // Weight ruler picker
            WeightRulerView(selectedWeight: $selectedWeight)
                .frame(height: 120)
                .padding(.horizontal)
            
            Spacer()
            
            // Continue button - match the image
            VStack {
                Button(action: {
                    HapticFeedback.generate()
                    saveDesiredWeight()
                    navigateToNextStep = true
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black) // Black background
                        .foregroundColor(.white)
                        .cornerRadius(28) // Pill shape
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
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

// Custom ruler for weight selection
struct WeightRulerView: View {
    @Binding var selectedWeight: Double
    @State private var startLocation: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    
    // Weight range and sizing
    private let minWeight: Double = 100.0
    private let maxWeight: Double = 250.0
    private let tickSpacing: CGFloat = 8.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Light gray background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemGray6))
                    .frame(height: 100)
                
                // Center indicator line
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 3, height: 60)
                    .position(x: geometry.size.width / 2, y: 50)
                    .zIndex(2)
                
                // Ruler with ticks
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack {
                        // Ticks container
                        HStack(spacing: 0) {
                            // Left buffer space
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: geometry.size.width / 2)
                            
                            // All weight ticks
                            ForEach(Int(minWeight)...Int(maxWeight), id: \.self) { weight in
                                WeightTick(
                                    weight: weight,
                                    isCurrent: abs(Double(weight) - selectedWeight) < 0.5,
                                    isMajor: weight % 10 == 0
                                )
                            }
                            
                            // Right buffer space
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: geometry.size.width / 2)
                        }
                    }
                }
                .content.offset(x: dragOffset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            // Update offset for scrolling effect
                            if abs(value.translation.width) > 0 {
                                let delta = value.translation.width - startLocation
                                dragOffset += delta
                                startLocation = value.translation.width
                                
                                // Calculate weight from position
                                let index = -dragOffset / tickSpacing
                                let weight = minWeight + index
                                
                                // Clamp to valid range
                                if weight >= minWeight && weight <= maxWeight {
                                    selectedWeight = Double(Int(weight * 10)) / 10 // Round to 0.1
                                }
                                
                                // Subtle haptic feedback
                                if Int(selectedWeight * 10) % 10 == 0 {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred(intensity: 0.3)
                                }
                            }
                        }
                        .onEnded { _ in
                            // Reset start location for next drag
                            startLocation = 0
                            
                            // Snap to nearest value
                            let targetWeight = round(selectedWeight)
                            withAnimation(.spring(response: 0.3)) {
                                selectedWeight = targetWeight
                                dragOffset = -(targetWeight - minWeight) * tickSpacing
                            }
                        }
                )
                .onAppear {
                    // Initialize at the selected weight
                    dragOffset = -(selectedWeight - minWeight) * tickSpacing
                }
            }
        }
    }
}

// Individual tick for the weight ruler
struct WeightTick: View {
    let weight: Int
    let isCurrent: Bool
    let isMajor: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // Tick mark
            Rectangle()
                .fill(isCurrent ? Color.black : Color.primary.opacity(isMajor ? 0.7 : 0.3))
                .frame(width: isCurrent ? 2 : 1, height: isMajor ? 40 : 20)
            
            // Only show text for major ticks (divisible by 10)
            if isMajor {
                Text("\(weight)")
                    .font(.caption)
                    .foregroundColor(isCurrent ? .primary : .secondary)
                    .fontWeight(isCurrent ? .bold : .regular)
            }
        }
        .frame(width: 8)
    }
}

#Preview {
    DesiredWeightView()
}
