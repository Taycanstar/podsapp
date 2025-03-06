//
//  DashboardView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/26/25.
//

import SwiftUI



struct DashboardView: View {
    @EnvironmentObject var podsViewModel: PodsViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var foodManager: FoodManager
    @Environment(\.isTabBarVisible) var isTabBarVisible
    
    var body: some View {
        Text("Dashboard")

            .onAppear {
                isTabBarVisible.wrappedValue = true
                podsViewModel.initialize(email: viewModel.email)
                print("🏠 DashboardView onAppear - initializing FoodManager")
                foodManager.initialize(userEmail: viewModel.email)
                
                // Add a slight delay to ensure initialization completes first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("🔄 DashboardView explicitly refreshing logs")
                    foodManager.refresh()
                }
            }
    }
}
