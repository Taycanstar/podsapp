//
//  2xView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/19/25.
//

//
//  TwoXView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI

struct TwoXView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var navigateToNextStep = false
    
    // Animation states
    @State private var showBottomSections = false
    @State private var showTagline = false
    
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
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .twoX), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title text - dynamically based on goal
            Text("\(goalText.capitalized) twice as fast with Humuli")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 40)
            
            Spacer()
            
            // Comparison cards in a dark container
            ZStack {
                RoundedRectangle(cornerRadius: 25)
                    .fill(Material.ultraThinMaterial)
                    .padding(.horizontal)
                
                VStack(spacing: 50) {
                    // Cards container
                    HStack(spacing: 20) {
                        // Without Humuli card
                        ZStack(alignment: .bottom) {
                            // Top white part (fills more space)
                            VStack {
                                Text("Without\nHumuli")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 30)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .background(.primary)
                            .mask(
                                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                            )
                            
                            // Bottom section with percentage (overlaid at bottom)
                            VStack {
                                Text("20%")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 80 * (showBottomSections ? 1.0 : 0.01))
                            .background(Color.gray.opacity(0.8))
                            .mask(
                                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                            )
                            .opacity(showBottomSections ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // With Humuli card
                        ZStack(alignment: .bottom) {
                            // Top white part (fills more space)
                            VStack {
                                Text("With\nHumuli")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 30)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .background(.primary)
                            .mask(
                                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                            )
                            
                            // Bottom section with 2X (overlaid at bottom)
                            VStack {
                                Text("2X")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 160 * (showBottomSections ? 1.0 : 0.01))
                            .background(Color.accentColor)
                            .mask(
                                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                            )
                            .opacity(showBottomSections ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 50)
                    
                    // Tagline
                    Text("Humuli makes it easy and holds you accountable.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 50)
                        .opacity(showTagline ? 1 : 0)
                        .offset(y: showTagline ? 0 : 20)
                }
                .padding(.horizontal, 35)

            }
            .padding(.vertical, 20)
            .frame(height: 450)
            
            Spacer()
            
            // Continue button
            VStack {
                Button(action: {
                    HapticFeedback.generate()
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
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .background(Color(UIColor.systemBackground))
        .background(
            NavigationLink(
                destination: SpecificDietView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("TwoXView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(8, forKey: "onboardingFlowStep") // Raw value for this step
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 TwoXView appeared - saved current step")
            
            // Initial states
            showBottomSections = false
            showTagline = false
            
            // Animate bottom sections with a spring animation for the growing effect
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.5)) {
                showBottomSections = true
            }
            
            // Animate tagline with a longer delay
            withAnimation(.easeInOut(duration: 0.8).delay(1.2)) {
                showTagline = true
            }
        }
    }
}

// Custom shape for rounded corners
struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

