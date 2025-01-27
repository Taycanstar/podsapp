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
    
    var body: some View {
        Text("Dashboard")
            .onAppear {
                podsViewModel.fetchPods(email: viewModel.email) {}
            }
    }
}

