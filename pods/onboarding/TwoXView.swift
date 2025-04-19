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
    @State private var navigateToNextStep = false
    
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
                        .frame(width: UIScreen.main.bounds.width * 0.98, height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title text - dynamically based on goal
            Text("\(goalText.capitalized) twice as fast with Humuli vs on your own")
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 40)
            
            Spacer()
            
            // Comparison cards
            VStack(spacing: 30) {
                // Cards container
                HStack(spacing: 20) {
                    // Without Humuli card
                    VStack {
                        Spacer()
                        
                        Text("Without Humuli")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.top, 20)
                        
                        Spacer()
                        
                        Text("20%")
                            .font(.system(size: 28, weight: .bold))
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                    }
                    .frame(height: 200)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // With Humuli card
                    VStack {
                        Spacer()
                        
                        Text("With Humuli")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.top, 20)
                        
                        Spacer()
                        
                        Text("2X")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(Color.black)
                            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                    }
                    .frame(height: 200)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // Tagline
                VStack(spacing: 4) {
                    Text("Humuli makes it easier to reach your goals")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("and helps you stay accountable.")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            }
            
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
        .background(
            NavigationLink(
                destination: Text("Final Onboarding View"),  // Replace with final view
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
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

