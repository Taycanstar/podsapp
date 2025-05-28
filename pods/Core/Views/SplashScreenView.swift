//
//  SplashScreenView.swift
//  pods
//
//  Created by Dimi Nunez on 5/30/24.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    @State private var hasTriedDataLoading = false
    
    // Environment objects needed for data loading
    @EnvironmentObject var onboarding: OnboardingViewModel
    @EnvironmentObject var foodMgr: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                // Full screen black background
                Color.black
                    .ignoresSafeArea(.all)
                
                // Logo with scaling animation
                Image("logo-bk")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    // .scaleEffect(size)
            }
            .onAppear {
                // Animate logo
                // withAnimation(.easeInOut(duration: 1.0)) {
                //     self.size = 1.0
                //     self.opacity = 1.0
                // }
                
                // Transition after 2 seconds regardless of loading status
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.isActive = true
                }
            }
            .onChange(of: onboarding.email) { newEmail in
                // When authentication is restored and email becomes available, load data
                if !newEmail.isEmpty && !hasTriedDataLoading {
                    hasTriedDataLoading = true
                    preloadAppData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AuthenticationCompleted"))) { _ in
                // Also try when authentication completes
                if !hasTriedDataLoading {
                    hasTriedDataLoading = true
                    preloadAppData()
                }
            }
        }
    }
    
    /// Preload critical app data during splash screen
    private func preloadAppData() {
        print("🚀 SplashScreenView - Starting data preload...")
        
        // Load user email from UserDefaults first (fallback to onboarding.email)
        let userEmail: String
        if let storedEmail = UserDefaults.standard.string(forKey: "userEmail"), !storedEmail.isEmpty {
            userEmail = storedEmail
        } else if !onboarding.email.isEmpty {
            userEmail = onboarding.email
        } else {
            print("❌ No user email available - cannot load data")
            return
        }
        
        print("📧 Using email for data loading: \(userEmail)")
        
        // Configure basic app state
        if dayLogsVM.email.isEmpty {
            dayLogsVM.setEmail(userEmail)
        }
        
        // Save the email so other views can pick it up
        UserDefaults.standard.set(userEmail, forKey: "userEmail")
        
        // Initialize food manager with user email
        foodMgr.initialize(userEmail: userEmail)
        
        // Set up the connection between FoodManager and DayLogsViewModel for voice logging
        foodMgr.dayLogsViewModel = dayLogsVM
        
        // Load logs for selected date (this will happen in background)
        dayLogsVM.loadLogs(for: dayLogsVM.selectedDate)
        
        // Preload health data logs for detail views (background task)
        preloadHealthDataLogs(userEmail: userEmail)
        
        print("🚀 SplashScreenView - Data preload initiated")
    }
    
    /// Preload health data logs so they're available when navigating to detail views
    private func preloadHealthDataLogs(userEmail: String) {
        // Preload weight logs (background)
        NetworkManagerTwo.shared.fetchWeightLogs(userEmail: userEmail, limit: 1000, offset: 0) { result in
            switch result {
            case .success(let response):
                if let encodedData = try? JSONEncoder().encode(response) {
                    UserDefaults.standard.set(encodedData, forKey: "preloadedWeightLogs")
                }
                print("✅ Weight logs preloaded successfully")
            case .failure(let error):
                print("❌ Error preloading weight logs: \(error)")
            }
        }
        
        // Preload height logs (background)
        NetworkManagerTwo.shared.fetchHeightLogs(userEmail: userEmail, limit: 1000, offset: 0) { result in
            switch result {
            case .success(let response):
                if let encodedData = try? JSONEncoder().encode(response) {
                    UserDefaults.standard.set(encodedData, forKey: "preloadedHeightLogs")
                }
                print("✅ Height logs preloaded successfully")
            case .failure(let error):
                print("❌ Error preloading height logs: \(error)")
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
