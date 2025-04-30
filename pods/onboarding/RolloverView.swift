//
//  RolloverView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI

struct RolloverView: View {
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
//                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .rollover), height: 4)
//                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and content
            VStack(spacing: 30) {
                Text("Rollover extra calories to the next day?")
                    .padding(.horizontal)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                ZStack {
                    Text("Rollover up to 200 cals")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemGray6))
                        .cornerRadius(16)
                }
                .padding(.bottom, 10)
                
                // Yesterday's card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Yesterday")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                    
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(colorScheme == .dark ? .black.opacity(0.3) : .white.opacity(0.3), lineWidth: 6)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .trim(from: 0, to: 0.7) // 350/500 = 0.7
                                .stroke(colorScheme == .dark ? .black : .white, lineWidth: 6)
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 2) {
                                Text("350/500")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                                
                                Text("Cals left")
                                    .font(.system(size: 16))
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                            }
                            
                            Text("150")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .frame(width: 270)
                }
                .padding(24)
                .background(.primary)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .frame(width: 320)
                .padding(.bottom, 20)
                
                // Today's card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                    
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(colorScheme == .dark ? .black.opacity(0.3) : .white.opacity(0.3), lineWidth: 6)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .trim(from: 0, to: 0.54) // 350/650 = ~0.54
                                .stroke(colorScheme == .dark ? .black : .white, lineWidth: 6)
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 2) {
                                Text("350/650")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                                
                                Text("Cals left")
                                    .font(.system(size: 16))
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                                
                                Text("+150")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                            }
                            
                            Text("150+150")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .frame(width: 270)
                }
                .padding(24)
                .background(.primary)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .frame(width: 320)
                
                Spacer()
            }
            
            Spacer()
            
            // No/Yes buttons
            HStack(spacing: 16) {
                Button(action: {
                    HapticFeedback.generate()
                    UserDefaults.standard.set(false, forKey: "allowCalorieRollover")
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
                    UserDefaults.standard.set(true, forKey: "allowCalorieRollover")
                    navigateToNextStep = true
                }) {
                    Text("Yes")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.accentColor)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
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
                destination: CreatingPlanView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
    }
}


