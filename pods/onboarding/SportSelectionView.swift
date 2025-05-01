//
//  SportSelectionView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/30/25.
//

import SwiftUI

struct SportSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var sportName: String = ""
    @State private var navigateToNextStep = false
    @State private var showAlert = false
    
    // Common sports for autocomplete suggestions
    let commonSports = [
        "Soccer", "Basketball", "Baseball", "Football", "Tennis", 
        "Golf", "Hockey", "Volleyball", "Swimming", "Running",
        "Cycling", "Boxing", "Wrestling", "MMA", "CrossFit",
        "Triathlon", "Skiing", "Snowboarding", "Surfing", "Rock Climbing",
        "Rugby", "Cricket", "Gymnastics", "Track and Field", "Weightlifting"
    ]
    
    // Filtered suggestions based on current input
    var filteredSuggestions: [String] {
        if sportName.isEmpty {
            return []
        }
        return commonSports.filter { $0.lowercased().contains(sportName.lowercased()) }
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
                
                // Progress bar
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .sportSelection), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("What sport do you play?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("We'll tailor your plan for optimal performance.")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 16)
            
            // Sport name input
            VStack(alignment: .leading, spacing: 0) {
             
                
                TextField("Enter sport name", text: $sportName)
                    .padding()
                    .frame(height: 56)
                    .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemGray6))
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Show suggestions if any match the input
            if !filteredSuggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            Button(action: {
                                sportName = suggestion
                            }) {
                                HStack {
                                    Text(suggestion)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                            }
                            .background(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray5))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 200)
            }
            
            Spacer()
            
            // Continue button
            VStack {
                Button(action: {
                    HapticFeedback.generate()
                    
                    if !sportName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        UserDefaults.standard.set(sportName, forKey: "sportType")
                        
                        // Make sure we're using the server-compatible format
                        convertDietGoalFormat()
                        
                        navigateToNextStep = true
                    } else {
                        showAlert = true
                    }
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
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Sport Required"),
                message: Text("Please enter the sport you play to continue."),
                dismissButton: .default(Text("OK"))
            )
        }
        .background(
            NavigationLink(
                destination: CreatingPlanView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("SportSelectionView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(14, forKey: "onboardingFlowStep") // Adjust based on flow position
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            
            // Convert the diet goal format for server compatibility
            convertDietGoalFormat()
            
            UserDefaults.standard.synchronize()
            print("📱 SportSelectionView appeared - saved current step")
        }
    }
    
    // Helper method to convert diet goal format from iOS to server format
    private func convertDietGoalFormat() {
        if let currentDietGoal = UserDefaults.standard.string(forKey: "dietGoal") {
            let serverDietGoal: String
            switch currentDietGoal {
            case "gainWeight":
                serverDietGoal = "gain"
            case "loseWeight":
                serverDietGoal = "lose"
            case "maintain":
                serverDietGoal = "maintain"
            default:
                serverDietGoal = "maintain" // Default fallback
            }
            
            // Save the converted format that the server expects
            UserDefaults.standard.set(serverDietGoal, forKey: "serverDietGoal")
            print("📝 Converted diet goal from \(currentDietGoal) to \(serverDietGoal) for server compatibility")
        }
    }
}

#Preview {
    SportSelectionView()
}
