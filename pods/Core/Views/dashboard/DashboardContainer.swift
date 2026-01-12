//
//  DashboardContainer.swift
//  pods
//
//  Container view that manages inverted navigation hierarchy:
//  ChatsView (root) → NewHomeView (auto-pushed)
//

import SwiftUI

/// Wrapper to make conversation ID identifiable for sheet(item:) presentation
private struct ConversationSheetItem: Identifiable {
    let id: String  // The conversation ID, or a UUID for new conversations
    let conversationId: String?  // nil means new conversation

    init(conversationId: String?) {
        self.conversationId = conversationId
        self.id = conversationId ?? UUID().uuidString
    }
}

struct DashboardContainer: View {
    // Agent bar bindings
    @Binding var agentText: String
    @Binding var agentAttachments: [ChatAttachment]
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

    // Conversation selection state - using item-based sheet for reliable ID passing
    @State private var conversationSheetItem: ConversationSheetItem?

    // New conversation info for immediate UI update (id, title)
    @State private var newConversationId: String?
    @State private var newConversationTitle: String?

    // Trigger refresh of ChatsView when returning from AgentChatView
    @State private var shouldRefreshChats = false

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
                    // Use item-based sheet presentation to guarantee ID is available
                    conversationSheetItem = ConversationSheetItem(conversationId: conversationId)
                },
                newConversationId: $newConversationId,
                newConversationTitle: $newConversationTitle,
                shouldRefresh: $shouldRefreshChats
            )
            .background(
                NavigationLink(
                    destination: NewHomeView(
                        agentText: $agentText,
                        agentAttachments: $agentAttachments,
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
        .sheet(item: $conversationSheetItem, onDismiss: {
            shouldRefreshChats = true
        }) { item in
            AgentChatView(
                conversationIdToLoad: item.conversationId,
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
