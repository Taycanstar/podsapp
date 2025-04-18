//
//  DesiredWeightView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/7/25.
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
                Text("What is your desired weight?")
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
            
            // Custom ruler picker
            WeightRulerView(selectedWeight: $selectedWeight)
                .frame(height: 100)
                .padding(.horizontal)
            
            Spacer()
            
            // Continue button
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
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 24)
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

// Custom ruler-style weight picker
struct WeightRulerView: View {
    @Binding var selectedWeight: Double
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragValue: CGFloat = 0
    
    // Weight range (100-250 lbs)
    private let minWeight: Double = 100.0
    private let maxWeight: Double = 250.0
    
    // Tick constants
    private let tickSpacing: CGFloat = 20 // Points between each tick
    private let majorTickInterval = 10 // Show numbers every 10 lbs
    
    var body: some View {
        GeometryReader { geometry in
            // Main ruler container
            ZStack(alignment: .top) {
                // Vertical center indicator line
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: 50)
                    .position(x: geometry.size.width / 2, y: 25)
                    .zIndex(1)
                
                // Horizontal ruler with ticks
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            // Add padding at start to center first weight
                            Spacer().frame(width: geometry.size.width / 2)
                            
                            // Generate ticks for each weight value
                            ForEach(Int(minWeight)...Int(maxWeight), id: \.self) { weight in
                                VStack(alignment: .center, spacing: 8) {
                                    // Draw tick
                                    Rectangle()
                                        .fill(Color.primary.opacity(weight % majorTickInterval == 0 ? 1.0 : 0.3))
                                        .frame(width: 1, height: weight % majorTickInterval == 0 ? 40 : 20)
                                    
                                    // Only show labels for major ticks
                                    if weight % majorTickInterval == 0 {
                                        Text("\(weight)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(width: tickSpacing)
                                .id(weight) // Allow scrolling to specific weight
                            }
                            
                            // Add padding at end to center last weight
                            Spacer().frame(width: geometry.size.width / 2)
                        }
                    }
                    .content.offset(x: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Calculate drag delta
                                let translation = value.translation.width
                                
                                // Update drag offset
                                dragOffset += translation - lastDragValue
                                lastDragValue = translation
                                
                                // Calculate selected weight based on offset
                                let tickWidth = tickSpacing
                                let centerOffset = -dragOffset + geometry.size.width/2
                                let weightIndex = centerOffset / tickWidth
                                let newWeight = minWeight + Double(weightIndex)
                                
                                // Update selected weight with bounds checking
                                if newWeight >= minWeight && newWeight <= maxWeight {
                                    selectedWeight = Double(Int(newWeight * 10)) / 10 // Round to 1 decimal place
                                    HapticFeedback.generateLigth()
                                }
                            }
                            .onEnded { _ in
                                // Reset last drag value
                                lastDragValue = 0
                                
                                // Snap to nearest weight value
                                let nearestWeight = Int(selectedWeight.rounded())
                                let adjustedOffset = -CGFloat(nearestWeight - Int(minWeight)) * tickSpacing + geometry.size.width/2
                                
                                // Animate to snap position
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = adjustedOffset
                                    
                                    // Update weight to nearest integer for clean display
                                    selectedWeight = Double(nearestWeight)
                                }
                            }
                    )
                    .onAppear {
                        // Initialize position to selected weight
                        let initialWeight = Int(selectedWeight.rounded())
                        dragOffset = -CGFloat(initialWeight - Int(minWeight)) * tickSpacing + geometry.size.width/2
                        
                        // Scroll to initial weight
                        scrollProxy.scrollTo(initialWeight, anchor: .center)
                    }
                }
            }
        }
    }
}

#Preview {
    DesiredWeightView()
}
