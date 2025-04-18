//
//  GenderView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/17/25.
//

//
//  GenderView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/7/25.
//

import SwiftUI

struct GenderView: View {
    @State private var selectedGender: Gender = .male
    @Environment(\.dismiss) var dismiss
    @State private var navigateToWorkoutDays = false
    
    // Enum for gender options
    enum Gender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
        case other = "Other"
        
    }
    
    var body: some View {
        NavigationView {
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
                    
                    // Progress bar - 1/5 completed (20%)
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: UIScreen.main.bounds.width * 0.2, height: 4)
                            .cornerRadius(2)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Title and instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose your Gender")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("We'll use this to tailor your personalized plan")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 40)
                
                Spacer()
                
                // Gender selection buttons
                VStack(spacing: 16) {
                    ForEach(Gender.allCases, id: \.self) { gender in
                        Button(action: {
                            HapticFeedback.generate()
                            selectedGender = gender
                        }) {
                            Text(gender.rawValue)
                                .font(.system(size: 18, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(selectedGender == gender ? Color.accentColor : Color("iosbg"))
                                .foregroundColor(selectedGender == gender ? .white : .primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Continue button
                VStack {
                    Button(action: {
                        HapticFeedback.generate()
                        UserDefaults.standard.set(selectedGender.rawValue, forKey: "selectedGender")
                        navigateToWorkoutDays = true
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
                    destination: WorkoutDaysView(),
                    isActive: $navigateToWorkoutDays
                ) {
                    EmptyView()
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    GenderView()
} 