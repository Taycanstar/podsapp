//
//  ConnectToAppleHealth.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI
import HealthKit

struct ConnectToAppleHealth: View {
    @Environment(\.dismiss) var dismiss
    @State private var navigateToNextStep = false
    @State private var isRequestingPermission = false
    
    // Health store for requesting permissions
    private let healthStore = HKHealthStore()
    
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
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .connectHealth), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            Spacer()
            
            // Apple Health icon and visual elements
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray6))
                    .frame(width: 300, height: 300)
                
                VStack {
                    HStack(spacing: 45) {
                        Text("Walking")
                            .font(.system(size: 18, weight: .medium))
                        
                        ZStack {
                   
                            
                            Image(systemName: "apple.logo")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    
                    HStack(spacing: 45) {
                        Text("Running")
                            .font(.system(size: 18, weight: .medium))
                        
            
                    }
                    
                    HStack(spacing: 120) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.red)
                        
                        Text("Yoga")
                            .font(.system(size: 18, weight: .medium))
                    }
                    
                    HStack(spacing: 45) {
                        Text("Sleep")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
            .padding(.bottom, 40)
            
            // Title and description
            VStack(spacing: 16) {
                Text("Connect to\nApple Health")
                    .font(.system(size: 36, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("Sync your daily activity between Cal AI and the Health app to have the most thorough data.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Continue and Not now buttons
            VStack(spacing: 16) {
                Button(action: {
                    HapticFeedback.generate()
                    requestHealthPermissions()
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    HapticFeedback.generate()
                    UserDefaults.standard.set(false, forKey: "healthKitEnabled")
                    navigateToNextStep = true
                }) {
                    Text("Not now")
                        .font(.system(size: 18, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
            .background(Material.ultraThin)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: CaloriesBurnedView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
    }
    
    // Request health permissions
    private func requestHealthPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            // Health data not available on this device
            navigateToNextStep = true
            return
        }
        
        // Set up the health data types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType()
        ]
        
        // Request authorization
        isRequestingPermission = true
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            DispatchQueue.main.async {
                isRequestingPermission = false
                
                // Save the user preference
                UserDefaults.standard.set(success, forKey: "healthKitEnabled")
                
                // Navigate to next screen regardless of user choice
                navigateToNextStep = true
            }
        }
    }
}

struct ConnectToAppleHealth_Previews: PreviewProvider {
    static var previews: some View {
        ConnectToAppleHealth()
    }
}
