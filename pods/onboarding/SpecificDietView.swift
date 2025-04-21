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
    
    // Enum for diet options
    enum Diet: String, Identifiable, CaseIterable {
        case balanced = "Balanced"
        case pescatarian = "Pescatarian"
        case vegetarian = "Vegetarian"
        case vegan = "Vegan"
        case keto = "Keto"
        case glutenFree = "Gluten Free"
        
        var id: Self { self }
        
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
                                    .foregroundColor(selectedDiet == diet ? (colorScheme == .dark ? .black : .white) : .primary)
                                    .frame(width: 40)
                                
                                Text(diet.rawValue)
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
                            .foregroundColor(selectedDiet == diet ? (colorScheme == .dark ? .black : .white) : .primary)
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
                    saveDietPreference()
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
                destination: AccomplishView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
    }
    
    // Save selected diet to UserDefaults
    private func saveDietPreference() {
        UserDefaults.standard.set(selectedDiet?.rawValue, forKey: "dietPreference")
    }
}

#Preview {
    SpecificDietView()
}
