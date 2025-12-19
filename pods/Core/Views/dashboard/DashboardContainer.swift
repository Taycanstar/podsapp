//
//  DashboardContainer.swift
//  pods
//
//  Container view that manages inverted navigation hierarchy:
//  ChatsView (root) → NewHomeView (auto-pushed)
//

import SwiftUI

struct DashboardContainer: View {
    // Agent bar bindings
    @Binding var agentText: String
    var onPlusTapped: () -> Void
    var onBarcodeTapped: () -> Void
    var onMicrophoneTapped: () -> Void
    var onWaveformTapped: () -> Void
    var onSubmit: () -> Void
    var onRealtimeStart: () -> Void = {}

    // Navigation State - starts TRUE to auto-push DashboardView
    @State private var showDashboard = true

    // User Info for ChatsView
    @State private var userInitial: String = ""
    @State private var userDisplayName: String = ""
    @State private var shouldShowProfileBorder: Bool = false

    // Environment objects
    @EnvironmentObject var onboarding: OnboardingViewModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    var body: some View {
        NavigationView {
            ChatsView(
                initial: userInitial,
                name: userDisplayName,
                showsBorder: shouldShowProfileBorder,
                onNavigateToDashboard: {
                    showDashboard = true
                }
            )
            .navigationBarHidden(true)
            .background(
                NavigationLink(
                    destination: NewHomeView(
                        agentText: $agentText,
                        onPlusTapped: onPlusTapped,
                        onBarcodeTapped: onBarcodeTapped,
                        onMicrophoneTapped: onMicrophoneTapped,
                        onWaveformTapped: onWaveformTapped,
                        onSubmit: onSubmit,
                        onShowChats: {
                            // Dismiss back to ChatsView
                            showDashboard = false
                        },
                        onRealtimeStart: onRealtimeStart
                    )
                    .navigationBarBackButtonHidden(true),
                    isActive: $showDashboard
                ) {
                    EmptyView()
                }
                .hidden()
            )
        }
        .navigationViewStyle(.stack)
        .onAppear {
            setupUserInfo()
            // Ensure DashboardView is pushed on appear
            if !showDashboard {
                showDashboard = true
            }
        }
        .onChange(of: onboarding.name) { _, _ in
            setupUserInfo()
        }
        .onChange(of: subscriptionManager.subscriptionInfo?.status) { _, _ in
            setupUserInfo()
        }
    }

    private func setupUserInfo() {
        // Get user display name from OnboardingViewModel or fallback to UserDefaults
        if !onboarding.name.isEmpty {
            userDisplayName = onboarding.name
        } else {
            userDisplayName = UserDefaults.standard.string(forKey: "userName") ?? "User"
        }

        // Get user initial from UserDefaults or derive from name
        if let storedInitial = UserDefaults.standard.string(forKey: "profileInitial"), !storedInitial.isEmpty {
            userInitial = String(storedInitial.prefix(1)).uppercased()
        } else {
            userInitial = String(userDisplayName.prefix(1)).uppercased()
        }

        // Check if user has active subscription from SubscriptionManager
        shouldShowProfileBorder = subscriptionManager.subscriptionInfo?.status == "active"
    }
}
