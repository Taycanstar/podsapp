//
//  GoalTimeView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI

struct GoalTimeView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var navigateToNextStep = false
    @State private var selectedSpeed: Double = 1.5  // Default to medium speed
    
    // Get the selected goal from UserDefaults
    private var goal: String {
        return UserDefaults.standard.string(forKey: "fitnessGoal") ?? "Maintain"
    }
    
    private var goalText: String {
        if goal == "Lose weight" {
            return "lose"
        } else if goal == "Gain weight" {
            return "gain"
        } else {
            return "maintain"
        }
    }
    
    private var speedText: String {
        return "\(goal == "Maintain" ? "Weight stability" : "\(goalText.capitalized) weight speed") per week"
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
                
                // Progress bar - nearly complete
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .goalTime), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("How fast do you want to \(goalText) your goal?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            Spacer()
            
            // Speed selection section
            VStack(spacing: 40) {
                // Speed label
                Text(speedText)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                
                // Selected speed value
                Text("\(String(format: "%.1f", selectedSpeed)) lbs")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.primary)
                
                // Animal icons for speed reference
                HStack {
                    // Slow - Tortoise
                    VStack(alignment: .center) {
                        Image(systemName: "tortoise.fill")
                            .font(.system(size: 32))
                            .foregroundColor(selectedSpeed <= 0.5 ? .primary : .secondary.opacity(0.5))
                            .frame(height: 40)
                    }
                    .frame(width: 80)
                    .offset(x: -10)
                    
                    Spacer()
                    
                    // Medium - Rabbit
                    VStack(alignment: .center) {
                        Image(systemName: "hare.fill")
                            .font(.system(size: 32))
                            .foregroundColor(selectedSpeed > 0.5 && selectedSpeed < 2.5 ? .primary : .secondary.opacity(0.5))
                            .frame(height: 40)
                    }
                    .frame(width: 80)
                    
                    Spacer()
                    
                    // Fast - Bolt
                    VStack(alignment: .center) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 32))
                            .foregroundColor(selectedSpeed >= 2.5 ? .primary : .secondary.opacity(0.5))
                            .frame(height: 40)
                    }
                    .frame(width: 80)
                    .offset(x: 10)
                }
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
                
                // Slider
                ZStack(alignment: .center) {
                    // Slider track
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    // Mark key positions
                    HStack {
                        Circle()
                            .fill(selectedSpeed == 0.0 ? Color.primary : Color.clear)
                            .frame(width: 6, height: 6)
                            .offset(x: -10)
                        
                        Spacer()
                        
                        Circle()
                            .fill(selectedSpeed == 1.5 ? Color.primary : Color.clear)
                            .frame(width: 6, height: 6)
                        
                        Spacer()
                        
                        Circle()
                            .fill(selectedSpeed == 3.0 ? Color.primary : Color.clear)
                            .frame(width: 6, height: 6)
                            .offset(x: 10)
                    }
                    
                    // Slider thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(radius: 2)
                        .offset(x: getThumbOffset())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    updateSelectedSpeed(with: value.location.x)
                                }
                        )
                }
                .frame(height: 24)
                .padding(.horizontal, 20)
                
                // Speed values
                HStack {
                    Text("0.2 lbs")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 80)
                        .offset(x: -10)
                    
                    Spacer()
                    
                    Text("1.5 lbs")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 80)
                    
                    Spacer()
                    
                    Text("3.0 lbs")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 80)
                        .offset(x: 10)
                }
                .padding(.horizontal, 20)
                
                // Recommended tag for middle value
                Text("Recommended")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemGray6).opacity(abs(selectedSpeed - 1.5) < 0.3 ? 1.0 : 0.0))
                    .cornerRadius(20)
                    .padding(.top, 20)
                    .opacity(abs(selectedSpeed - 1.5) < 0.3 ? 1.0 : 0.0)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue button
            VStack {
                Button(action: {
                    HapticFeedback.generate()
                    saveWeightChangeSpeed()
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
                destination: TwoXView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("GoalTimeView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(7, forKey: "onboardingFlowStep") // Raw value for this step
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 GoalTimeView appeared - saved current step")
        }
    }
    
    // Calculate the horizontal offset for the thumb based on selected speed
    private func getThumbOffset() -> CGFloat {
        let width: CGFloat = UIScreen.main.bounds.width - 80 // Account for horizontal padding
        let totalRange: CGFloat = 3.0 // 3.0 - 0.0
        
        // Calculate the percentage of the way through the range (0.0 to 1.0)
        let percentage = selectedSpeed / totalRange
        
        // Map to screen width
        return (percentage * width) - (width / 2)
    }
    
    // Update the selected speed based on touch position
    private func updateSelectedSpeed(with xPosition: CGFloat) {
        let width = UIScreen.main.bounds.width - 80 // Account for horizontal padding
        let midpoint = width / 2
        
        // Calculate normalized position (0-1)
        let normalizedPosition = (xPosition + midpoint) / width
        let clampedPosition = min(max(normalizedPosition, 0), 1)
        
        // Map to value range
        let range: Double = 3.0 // 3.0 - 0.0
        var newValue = range * Double(clampedPosition)
        
        // Enforce minimum value of 0.2
        newValue = max(newValue, 0.2)
        
        // Round to 1 decimal place for better UX
        selectedSpeed = round(newValue * 10) / 10
    }
    
    // Save the weight change speed to UserDefaults
    private func saveWeightChangeSpeed() {
        UserDefaults.standard.set(selectedSpeed, forKey: "weightChangeSpeed")
    }
}

