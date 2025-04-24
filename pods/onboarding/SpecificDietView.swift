//
//  SpecificDietView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI

struct SpecificDietView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedDiet: Diet?
    @State private var navigateToNextStep = false
    @State private var showAlert = false
    
    // Enum for diet options
    enum Diet: String, Identifiable, CaseIterable {
        case balanced = "balanced"
        case pescatarian = "pescatarian"
        case vegetarian = "vegetarian"
        case vegan = "vegan"
        case keto = "keto"
        case glutenFree = "glutenFree"
        
        var id: Self { self }
        
        var displayText: String {
            switch self {
            case .balanced: return "Balanced"
            case .pescatarian: return "Pescatarian"
            case .vegetarian: return "Vegetarian"
            case .vegan: return "Vegan"
            case .keto: return "Keto"
            case .glutenFree: return "Gluten Free"
            }
        }
        
        var icon: String {
            switch self {
            case .balanced: return "fork.knife"
            case .pescatarian: return "fish"
            case .vegetarian: return "leaf"
            case .vegan: return "leaf.fill"
            case .keto: return "chart.pie"
            case .glutenFree: return "allergens"
            }
        }
    }
    
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
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .specificDiet), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("Which diet do you follow?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 30)
            
            Spacer()
            
            // Diet selection options
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Diet.allCases) { diet in
                        Button(action: {
                            HapticFeedback.generate()
                            selectedDiet = diet
                        }) {
                            HStack {
                                Image(systemName: diet.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(selectedDiet == diet ? .white : .primary)
                                    .frame(width: 40)
                                
                                Text(diet.displayText)
                                    .font(.system(size: 15, weight: .medium))
                                
                                Spacer()
                                
                              
                            }
                            .padding(.leading, 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                selectedDiet == diet ? 
                                    Color.accentColor : 
                                    (colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemGray6))
                            )
                            .foregroundColor(selectedDiet == diet ? .white : .primary)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Continue button
            VStack {
                Button(action: {
                    HapticFeedback.generate()
                    
                    // Validate selection
                    if selectedDiet != nil {
                        saveDietPreference()
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
                title: Text("Selection Required"),
                message: Text("Please select a diet preference to continue."),
                dismissButton: .default(Text("OK"))
            )
        }
        .background(
            NavigationLink(
                destination: AccomplishView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("SpecificDietView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(10, forKey: "onboardingFlowStep") // Raw value for this step
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 SpecificDietView appeared - saved current step")
        }
    }
    
    // Save selected diet to UserDefaults
    private func saveDietPreference() {
        if let diet = selectedDiet {
            print("📝 Saving diet preference: \(diet.rawValue)")
            UserDefaults.standard.set(diet.rawValue, forKey: "dietPreference")
        }
    }
}

#Preview {
    SpecificDietView()
}
