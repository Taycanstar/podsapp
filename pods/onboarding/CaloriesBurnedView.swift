//
//  CaloriesBurnedView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI

struct CaloriesBurnedView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var navigateToNextStep = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress bar
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
                
                // Progress bar
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
//                    Rectangle()
//                        .fill(Color.primary)
//                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .caloriesBurned), height: 4)
//                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and content
            VStack(spacing: 40) {
                Text("Add calories burned back to your daily goal?")
                    .padding()
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    
                Spacer()
                
                // Calorie info card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Today's Goal")
                        .font(.system(size: 15))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(colorScheme == .dark ? .black : .white)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "flame.fill")
                                .foregroundColor(.primary)
                                .font(.system(size: 18))
                        }
                        
                        Text("500 Cals")
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .font(.system(size: 15))
                    }
                    
                    Divider()
                    
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(colorScheme == .dark ? .black : .white)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "shoe")
                                .foregroundColor(.primary)
                                .font(.system(size: 18))
                        }
                        
                        Text("Running")
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .font(.system(size: 15))
                        
                        Spacer()
                        
                        Text("+100 cals")
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .font(.system(size: 15, weight: .medium))
                    }
                }
                .padding(24)
                .background(.primary)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .frame(width: 300)
                
                Spacer()
            }
            
            Spacer()
            
            // No/Yes buttons
            HStack(spacing: 16) {
                Button(action: {
                    HapticFeedback.generate()
                    UserDefaults.standard.set(false, forKey: "addCaloriesBurned")
                    navigateToNextStep = true
                }) {
                    Text("No")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(UIColor.systemBackground))
                        .foregroundColor(.accentColor)
                        .cornerRadius(28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                }
                
                Button(action: {
                    HapticFeedback.generate()
                    UserDefaults.standard.set(true, forKey: "addCaloriesBurned")
                    navigateToNextStep = true
                }) {
                    Text("Yes")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(28)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemBackground))
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: RolloverView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("CaloriesBurnedView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(13, forKey: "onboardingFlowStep") // Raw value for this step
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 CaloriesBurnedView appeared - saved current step")
        }
    }
}

struct CaloriesBurnedView_Previews: PreviewProvider {
    static var previews: some View {
        CaloriesBurnedView()
    }
}
