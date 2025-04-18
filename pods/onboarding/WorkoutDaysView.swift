//
//  WorkoutDaysView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/7/25.
//

import SwiftUI

struct WorkoutDaysView: View {
    enum WorkoutFrequency: String, Identifiable, CaseIterable {
        case low
        case medium
        case high
        
        var id: Self { self }
        
        var title: String {
            switch self {
            case .low: return "0-2"
            case .medium: return "3-5"
            case .high: return "6+"
            }
        }
        
        var description: String {
            switch self {
            case .low: return "Now and then"
            case .medium: return "Most weeks"
            case .high: return "All in"
            }
        }
        
        var icon: String {
            switch self {
            case .low: return "aqi.low"
            case .medium: return "aqi.medium"
            case .high: return "aqi.high"
            }
        }
    }
    
    @State private var selectedFrequency: WorkoutFrequency = .medium
    @Environment(\.dismiss) var dismiss
    @State private var navigateToNextStep = false
    
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
                
                // Progress bar - 2/5 completed (40%)
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: UIScreen.main.bounds.width * 0.4, height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("How often do you workout weekly?")
                    .font(.system(size: 32, weight: .bold))
                
                Text("We'll use this to shape your plan.")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 40)
            
            Spacer()
            
            // Workout frequency selection buttons
            VStack(spacing: 16) {
                ForEach(WorkoutFrequency.allCases) { frequency in
                    Button(action: {
                        HapticFeedback.generate()
                        selectedFrequency = frequency
                    }) {
                        HStack {
                            Image(systemName: frequency.icon)
                                .font(.system(size: 22))
                                .foregroundColor(selectedFrequency == frequency ? .white : .primary)
                                .frame(width: 30)
                                .padding(.leading, 6)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(frequency.title)
                                    .font(.system(size: 18, weight: .medium))
                                
                                Text(frequency.description)
                                    .font(.system(size: 14))
                                    .opacity(0.8)
                            }
                            .padding(.leading, 8)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(selectedFrequency == frequency ? Color.accentColor : Color("iosbg"))
                        .foregroundColor(selectedFrequency == frequency ? .white : .primary)
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
                    UserDefaults.standard.set(selectedFrequency.rawValue, forKey: "workoutFrequency")
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
    }
}


