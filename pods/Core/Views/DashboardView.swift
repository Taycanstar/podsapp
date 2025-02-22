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
                foodManager.initialize(userEmail: viewModel.email)
                
            }
    }
}
