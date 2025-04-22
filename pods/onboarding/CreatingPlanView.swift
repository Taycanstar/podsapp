//
//  CreatingPlanView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/19/25.
//

import SwiftUI

struct CreatingPlanView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var progress: CGFloat = 0.0
    @State private var percentage: Int = 0
    @State private var currentTask: String = "Customizing health plan..."
    
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            // Percentage display
            Text("\(percentage)%")
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(.primary)
            
            // Status message
            Text("We're setting everything\nup for you")
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
            
            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    // .fill(LinearGradient(
                    //     gradient: Gradient(colors: [.red, .blue]),
                    //     startPoint: .leading,
                    //     endPoint: .trailing
                    // ))
                    .fill(Color.accentColor)
                    .frame(width: UIScreen.main.bounds.width * 0.8 * progress, height: 8)
            }
            .frame(width: UIScreen.main.bounds.width * 0.8)
            .padding(.bottom, 30)
            
            // Current task text
            Text(currentTask)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .padding(.bottom, 60)
            
            // Recommendations card
            VStack(alignment: .leading, spacing: 20) {
                Text("Daily recommendation for")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.bottom, 5)
                   .foregroundColor(Color("bg"))
                
                Group {
                    HStack {
                        Text("•")
                            .font(.system(size: 15, weight: .bold))
                        Text("Calories")
                            .font(.system(size: 15))
                    }
                .foregroundColor(Color("bg"))
                    
                    HStack {
                        Text("•")
                            .font(.system(size: 15, weight: .bold))
                        Text("Carbs")
                            .font(.system(size: 15))
                    }
               .foregroundColor(Color("bg"))
                    
                    HStack {
                        Text("•")
                            .font(.system(size: 15, weight: .bold))
                        Text("Protein")
                                    .font(.system(size: 15))
                    }
                 .foregroundColor(Color("bg"))
                    
                    HStack {
                        Text("•")
                            .font(.system(size: 15, weight: .bold))
                        Text("Fats")
                            .font(.system(size: 15))
                    }
                  .foregroundColor(Color("bg"))
                    
   
                }
            }
            .padding(30)
            .background(Color.primary)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .onAppear {
            startLoading()
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
    
    // Function to simulate loading progress
    private func startLoading() {
        // Reset progress values
        progress = 0.0
        percentage = 0
        
        // Update tasks based on progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            if progress < 1.0 {
                progress += 0.01
                percentage = Int(progress * 100)
                
                // Update task text based on progress
                if progress < 0.3 {
                    currentTask = "Customizing health plan..."
                } else if progress < 0.6 {
                    currentTask = "Calculating nutritional needs..."
                } else if progress < 0.9 {
                    currentTask = "Finalizing recommendations..."
                } else {
                    currentTask = "Almost ready..."
                }
            } else {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // CRITICAL FIX: First check if onboarding is actually complete
                    // We want to avoid corrupting the flag
                    print("🚀 About to mark onboarding as complete - validating state")
                    
                    // Double check if we should actually mark as complete
                    let currentStep = UserDefaults.standard.string(forKey: "currentOnboardingStep")
                    if currentStep != "CreatingPlanView" {
                        print("⚠️ WARNING: Trying to mark onboarding as complete when currentStep=\(currentStep ?? "nil")!")
                        print("⚠️ Setting currentStep=CreatingPlanView to fix inconsistency")
                        UserDefaults.standard.set("CreatingPlanView", forKey: "currentOnboardingStep")
                    }
                    
                    // Mark onboarding as complete
                    viewModel.onboardingCompleted = true
                    
                    // Make sure user is authenticated in UserDefaults
                    UserDefaults.standard.set(true, forKey: "isAuthenticated")
                    UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                    
                    // Clear onboarding in progress flag
                    UserDefaults.standard.set(false, forKey: "onboardingInProgress")
                    UserDefaults.standard.removeObject(forKey: "currentOnboardingStep")
                    
                    // Force synchronize to ensure changes are written immediately
                    UserDefaults.standard.synchronize()
                    
                    print("✅ Onboarding completed - all flags saved")
                    
                    // Post notification that authentication is complete
                    NotificationCenter.default.post(name: Notification.Name("AuthenticationCompleted"), object: nil)
                    
                    // Close the onboarding container
                    viewModel.isShowingOnboarding = false
                }
            }
        }
        
        // Make sure timer doesn't stop if scrolling
        RunLoop.current.add(timer, forMode: .common)
    }
}

#Preview {
    CreatingPlanView()
}
