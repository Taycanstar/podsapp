//
//  DemoChatView.swift
//  pods
//
//  Chat view for the onboarding demo.
//  Mimics AgentChatView styling with demo-specific data and animations.
//  Shows typing animation in the AgentTabBar-style input field.
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
            demoAgentTabBar
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
                        .frame(height: 160)
                }
                .padding()
            }
            .onChange(of: flow.demoChatMessages.count) { _, _ in
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

    // MARK: - Demo Agent Tab Bar (matches AgentTabBar styling)

    @State private var cursorVisible = true

    private var demoAgentTabBar: some View {
        VStack(spacing: 0) {
            // Top blur for fade effect
            DemoTransparentBlurView(removeAllFilters: true)
                .blur(radius: 14)
                .frame(height: 10)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

            tabBarContent
        }
        .background(
            DemoTransparentBlurView(removeAllFilters: true)
                .blur(radius: 14)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
        )
        .onAppear {
            startCursorBlink()
            startDotAnimation()
        }
    }

    private var tabBarContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Text input area with typing animation
            ZStack(alignment: .topLeading) {
                // Placeholder or typing text
                if flow.isTyping && !flow.currentTypingText.isEmpty {
                    // Typing animation for user messages
                    HStack(spacing: 0) {
                        Text(flow.currentTypingText)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        // Blinking cursor
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 2, height: 16)
                            .opacity(cursorVisible ? 1.0 : 0.0)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                } else {
                    // Placeholder
                    Text("Log or ask anything...")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            // Bottom row with action buttons
            HStack {
                HStack(spacing: 10) {
                    // Plus button
                    demoActionCircle(systemName: "plus", isPrimary: true)
                    // Barcode button
                    demoActionCircle(systemName: "barcode.viewfinder", isPrimary: false)
                }

                Spacer()

                // Mic/Send button
                if flow.isTyping {
                    // Show send button when typing
                    demoActionCircle(systemName: "arrow.up", isPrimary: true)
                } else {
                    // Show mic button when not typing
                    demoActionCircle(systemName: "mic.fill", isPrimary: false)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color("chat"))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, -12)
    }

    private func demoActionCircle(systemName: String, isPrimary: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isPrimary ? Color.accentColor : Color("chaticon"))
                .frame(width: 36, height: 36)
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isPrimary ? .white : .primary)
        }
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.06)
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

// MARK: - Demo Transparent Blur View

private struct DemoTransparentBlurView: UIViewRepresentable {
    var removeAllFilters: Bool = false

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        DispatchQueue.main.async {
            guard let backdropLayer = uiView.layer.sublayers?.first else { return }

            if removeAllFilters {
                backdropLayer.filters = []
            } else {
                backdropLayer.filters?.removeAll { filter in
                    String(describing: filter) != "gaussianBlur"
                }
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
