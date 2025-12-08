//
//  FoodLogAgentView.swift
//  pods
//
//  Created by Dimi Nunez on 12/6/25.
//


import SwiftUI

// Chat-style food logger reused for Text -> Add More flow
struct FoodLogAgentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager

    @Binding var isPresented: Bool
    var onFoodReady: (Food) -> Void

    @State private var messages: [FoodLogMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading = false
    @State private var conversationHistory: [[String: String]] = []
    @State private var streamingText: String = ""
    @State private var streamingToken: UUID?
    @FocusState private var isInputFocused: Bool
    @State private var statusPhraseIndex = 0
    @State private var thinkingTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    // Realtime voice session
    @StateObject private var realtimeSession = RealtimeVoiceSession()

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    chatScroll
                    inputBar
                }

                // "Start talking" overlay when connected and chat is empty
                if realtimeSession.state == .connected && messages.isEmpty && realtimeSession.messages.isEmpty {
                    VStack {
                        Spacer()
                        Text("Start talking")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Metryc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .onReceive(thinkingTimer) { _ in
            guard isLoading else { return }
            statusPhraseIndex = (statusPhraseIndex + 1) % statusPhrases.count
        }
        .onChange(of: isLoading) { _, loading in
            if !loading { statusPhraseIndex = 0 }
        }
        .onDisappear {
            // Clean up realtime session when view disappears
            if realtimeSession.state != .idle {
                realtimeSession.disconnect()
            }
        }
    }

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Regular text-based messages
                    ForEach(messages) { message in
                        switch message.sender {
                        case .user:
                            HStack {
                                Spacer()
                                Text(message.text)
                                    .padding(12)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                        case .system:
                            Text(message.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .foregroundColor(.primary)
                        case .status:
                            thinkingIndicator
                        }
                    }

                    // Realtime voice messages
                    ForEach(realtimeSession.messages) { message in
                        if message.isUser {
                            HStack {
                                Spacer()
                                Text(message.text)
                                    .padding(12)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                        } else {
                            Text(message.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .foregroundColor(.primary)
                        }
                    }

                    // Streaming user text (what user is currently saying)
                    if !realtimeSession.currentUserText.isEmpty {
                        HStack {
                            Spacer()
                            Text(realtimeSession.currentUserText)
                                .padding(12)
                                .background(Color.accentColor.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .id("streamingUser")
                    }

                    // Streaming assistant text (what AI is currently saying)
                    if !realtimeSession.currentAssistantText.isEmpty {
                        Text(realtimeSession.currentAssistantText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .foregroundColor(.secondary)
                            .id("streamingAssistant")
                    }

                    // Text streaming from backend typewriter
                    if !streamingText.isEmpty {
                        Text(streamingText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .foregroundColor(.secondary)
                            .id("streamingAssistantText")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: realtimeSession.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: realtimeSession.currentUserText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: realtimeSession.currentAssistantText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if !realtimeSession.currentAssistantText.isEmpty {
                proxy.scrollTo("streamingAssistant", anchor: .bottom)
            } else if !realtimeSession.currentUserText.isEmpty {
                proxy.scrollTo("streamingUser", anchor: .bottom)
            } else if let last = realtimeSession.messages.last?.id {
                proxy.scrollTo(last, anchor: .bottom)
            } else if let last = messages.last?.id {
                proxy.scrollTo(last, anchor: .bottom)
            }
        }
    }

    private var inputBar: some View {
        AgentTabBar(
            text: $inputText,
            isPromptFocused: $isInputFocused,
            onPlusTapped: { HapticFeedback.generateLigth() },
            onBarcodeTapped: { HapticFeedback.generateLigth() },
            onMicrophoneTapped: { HapticFeedback.generateLigth() },
            onWaveformTapped: {
                guard !isLoading else { return }
                sendPrompt()
            },
            onSubmit: {
                guard !isLoading else { return }
                sendPrompt()
            },
            realtimeState: realtimeSession.state,
            onRealtimeStart: { startRealtimeSession() },
            onRealtimeEnd: { endRealtimeSession() },
            onMuteToggle: { realtimeSession.toggleMute() }
        )
        .padding(.bottom, 8)
    }

    private func sendPrompt() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        messages.append(FoodLogMessage(sender: .user, text: prompt))
        conversationHistory.append(["role": "user", "content": prompt])
        inputText = ""
        isLoading = true
        messages.append(FoodLogMessage(sender: .status, text: "Analyzing…"))
        startStreamingStatus(for: prompt)

        foodManager.generateFoodWithAI(
            foodDescription: prompt,
            history: conversationHistory,
            skipConfirmation: true
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                messages.removeAll { $0.sender == .status }
                stopStreamingStatus()
                switch result {
                case .success(let response):
                    switch response.resolvedFoodResult {
                    case .success(let food):
                        messages.append(FoodLogMessage(sender: .system, text: "Got it!"))
                        onFoodReady(food)
                        isPresented = false
                    case .failure(let genError):
                        switch genError {
                        case .needsClarification(let question):
                            messages.append(FoodLogMessage(sender: .system, text: question))
                            conversationHistory.append(["role": "assistant", "content": question])
                        case .unavailable(let message):
                            messages.append(FoodLogMessage(sender: .system, text: message))
                        }
                    }
                case .failure(let error):
                    messages.append(FoodLogMessage(sender: .system, text: "Error: \(error.localizedDescription)"))
                }
            }
        }
    }

    // MARK: - Realtime Voice Session

    private func startRealtimeSession() {
        Task {
            do {
                try await realtimeSession.connect()
            } catch {
                print("❌ Realtime connection failed: \(error)")
                messages.append(FoodLogMessage(sender: .system, text: "Voice connection failed. Please try again."))
            }
        }
    }

    private func endRealtimeSession() {
        let transcript = realtimeSession.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        realtimeSession.disconnect()

        // If we have transcribed text, send it through the existing food logging flow
        if !transcript.isEmpty {
            inputText = transcript
            sendPrompt()
        }
    }

    // MARK: - Streaming typewriter status

    private func startStreamingStatus(for prompt: String) {
        streamingText = ""
        let systemMessage = [
            "role": "system",
            "content": "You are acknowledging the user's food log while we fetch nutrition. Reply with a short reassuring sentence. Do not include numbers or nutrition values."
        ]
        let userMessage = ["role": "user", "content": prompt]
        let payload = [systemMessage, userMessage]

        streamingToken = foodManager.streamAIResponse(
            messages: payload,
            model: "gpt-5.1",
            temperature: 0.4,
            onDelta: { delta in
                streamingText.append(delta)
            },
            onComplete: {},
            onError: { error in
                print("Streaming error: \(error.localizedDescription)")
            }
        )
    }

    private func stopStreamingStatus() {
        if let token = streamingToken {
            foodManager.cancelStream(token: token)
        }
        streamingToken = nil
        streamingText = ""
    }
}

private struct FoodLogMessage: Identifiable {
    enum Sender {
        case user, system, status
    }
    let id = UUID()
    let sender: Sender
    let text: String
}

// MARK: - Thinking Indicator Helpers

extension FoodLogAgentView {
    private var thinkingIndicator: some View {
        HStack(spacing: 10) {
            thinkingPulseCircle
            Text(currentStatusText)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var currentStatusText: String {
        statusPhrases[min(statusPhraseIndex, statusPhrases.count - 1)]
    }

    private var thinkingPulseCircle: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let normalized = (sin(t * 2 * .pi / 1.5) + 1) / 2
            Circle()
                .fill(Color.primary)
                .frame(width: 10, height: 10)
                .scaleEffect(0.85 + 0.25 * normalized)
                .opacity(0.6 + 0.4 * normalized)
        }
    }

    private var statusPhrases: [String] {
        [
            "Analyzing your meal…",
            "Looking up nutrition…",
            "Balancing macros…",
            "Checking ingredients…"
        ]
    }

}
