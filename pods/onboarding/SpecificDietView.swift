//
//  SpecificDietView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI

struct SpecificDietView: View {
    @Environment(\.dismiss) var dismiss
    @State private var navigateToNextStep = false
    @State private var selectedDiet: DietType = .balanced
    
    // Enum for diet options
    enum DietType: String, Identifiable, CaseIterable {
        case balanced = "Balanced"
        case pescatarian = "Pescatarian"
        case vegetarian = "Vegetarian"
        case vegan = "Vegan"
        case keto = "Keto"  // Additional diet option
        
        var id: Self { self }
        
        var icon: String {
            switch self {
            case .balanced: return "fork.knife"
            case .pescatarian: return "fish"
            case .vegetarian: return "leaf"
            case .vegan: return "leaf.fill"
            case .keto: return "chart.pie"
            }
        }
        
        var description: String {
            switch self {
            case .balanced: return "Includes all food groups with an emphasis on moderation"
            case .pescatarian: return "Vegetarian diet that includes seafood"
            case .vegetarian: return "Excludes meat and seafood"
            case .vegan: return "Excludes all animal products"
            case .keto: return "High fat, low carb, moderate protein"
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
                
                // Progress bar - complete
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: UIScreen.main.bounds.width, height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("Which diet do you follow?")
                    .font(.system(size: 32, weight: .bold))
                

            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 30)
            Spacer()
            
            // Diet selection options
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(DietType.allCases) { diet in
                        Button(action: {
                            HapticFeedback.generate()
                            selectedDiet = diet
                        }) {
                            HStack {
                                Image(systemName: diet.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(selectedDiet == diet ? .white : .primary)
                                    .frame(width: 40)
                                
                                Text(diet.rawValue)
                                    .font(.system(size: 15, weight: .medium))
                                
                                Spacer()
                                
                              
                            }
                            .padding(.leading, 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(selectedDiet == diet ? Color.accentColor : Color("iosbg"))
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
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: Text("Final Onboarding View"),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
    }
    
    // Save selected diet to UserDefaults
    private func saveDietPreference() {
        UserDefaults.standard.set(selectedDiet.rawValue, forKey: "dietPreference")
    }
}

#Preview {
    SpecificDietView()
}
