//
//  DemoChatView.swift
//  pods
//
//  Created by Dimi Nunez on 12/27/25.
//


//
//  DemoChatView.swift
//  pods
//
//  Chat view for the onboarding demo.
//  Mimics AgentChatView styling with demo-specific data and animations.
//

import SwiftUI

struct DemoChatView: View {
    @ObservedObject var flow: DemoFlowController
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            // Chat scroll view
            chatScrollView

            // Input bar (non-interactive, shows typing animation)
            demoInputBar
        }
        .navigationTitle("Metryc")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Chat Scroll View

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Completed messages
                    ForEach(flow.demoChatMessages) { message in
                        messageRow(message)
                            .id(message.id)
                    }

                    // Currently typing user message
                    if flow.isTyping && !flow.currentTypingText.isEmpty {
                        typingUserMessageRow
                            .id("typingUser")
                    }

                    // Typing indicator for coach
                    if flow.showTypingIndicator {
                        coachTypingIndicator
                            .id("typingIndicator")
                    }

                    // Bottom anchor
                    Color.clear
                        .frame(height: 1)
                        .id("bottomAnchor")

                    // Extra space for input bar
                    Spacer()
                        .frame(height: 120)
                }
                .padding()
            }
            .onChange(of: flow.demoChatMessages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
            .onChange(of: flow.currentTypingText) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
            .onChange(of: flow.showTypingIndicator) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Message Rows

    @ViewBuilder
    private func messageRow(_ message: HealthCoachMessage) -> some View {
        switch message.sender {
        case .user:
            HStack {
                Spacer()
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(16)
            }

        case .coach:
            VStack(alignment: .leading, spacing: 8) {
                Text(message.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .system, .status:
            EmptyView()
        }
    }

    private var typingUserMessageRow: some View {
        HStack {
            Spacer()
            HStack(spacing: 0) {
                Text(flow.currentTypingText)
                // Blinking cursor
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2, height: 16)
                    .opacity(cursorOpacity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(16)
        }
    }

    @State private var cursorVisible = true
    private var cursorOpacity: Double {
        cursorVisible ? 1.0 : 0.0
    }

    private var coachTypingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .opacity(dotOpacity(for: index))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @State private var dotAnimationPhase: Int = 0
    private func dotOpacity(for index: Int) -> Double {
        let phase = (dotAnimationPhase + index) % 3
        switch phase {
        case 0: return 1.0
        case 1: return 0.6
        default: return 0.3
        }
    }

    // MARK: - Demo Input Bar

    private var demoInputBar: some View {
        VStack(spacing: 0) {
            // Top blur for fade effect
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground).opacity(0),
                    Color(UIColor.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)
            .allowsHitTesting(false)

            // Input field area
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Search/input field
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        if flow.step == .foodTyping && !flow.demoSearchQuery.isEmpty {
                            HStack(spacing: 0) {
                                Text(flow.demoSearchQuery)
                                    .foregroundColor(.primary)
                                // Blinking cursor
                                Rectangle()
                                    .fill(Color.primary)
                                    .frame(width: 2, height: 16)
                                    .opacity(cursorOpacity)
                            }
                        } else {
                            Text("Log or ask anything...")
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.systemGray6))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
        }
        .onAppear {
            startCursorBlink()
            startDotAnimation()
        }
    }

    // MARK: - Animations

    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                cursorVisible.toggle()
            }
        }
    }

    private func startDotAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation {
                dotAnimationPhase = (dotAnimationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DemoChatView(flow: DemoFlowController())
    }
}
