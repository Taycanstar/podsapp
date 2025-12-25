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
    @State private var userDisplayName: String = ""

    // Conversation selection state
    // Note: Using String? instead of AgentConversation? to avoid SwiftUI type complexity
    // that causes stack overflow during type metadata resolution
    @State private var selectedConversationId: String?
    @State private var showAgentChat = false

    // New conversation info for immediate UI update (id, title)
    @State private var newConversationId: String?
    @State private var newConversationTitle: String?

    // Environment objects
    @EnvironmentObject var onboarding: OnboardingViewModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @EnvironmentObject var foodManager: FoodManager

    var body: some View {
        NavigationView {
            ChatsView(
                name: userDisplayName,
                onNavigateToDashboard: {
                    showDashboard = true
                },
                onSelectConversationId: { conversationId in
                    selectedConversationId = conversationId
                    showAgentChat = true
                },
                newConversationId: $newConversationId,
                newConversationTitle: $newConversationTitle
            )
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
        .sheet(isPresented: $showAgentChat) {
            AgentChatView(
                conversationIdToLoad: selectedConversationId,
                onNewConversationCreated: { id, title in
                    newConversationId = id
                    newConversationTitle = title
                }
            )
            .environmentObject(dayLogsVM)
            .environmentObject(foodManager)
            .environmentObject(onboarding)
        }
    }

    private func setupUserInfo() {
        // Get user display name from OnboardingViewModel or fallback to UserDefaults
        if !onboarding.name.isEmpty {
            userDisplayName = onboarding.name
        } else {
            userDisplayName = UserDefaults.standard.string(forKey: "userName") ?? "User"
        }
    }
}
