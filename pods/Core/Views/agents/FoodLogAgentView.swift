//
//  FoodLogAgentView.swift
//  pods
//
//  Created by Dimi Nunez on 12/6/25.
//


import SwiftUI
import AVFoundation

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
    @State private var streamingMessageId: UUID?
    @State private var streamingToken: UUID?
    @State private var shimmerActive = false
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
        .onAppear {
            // Auto-focus input when the view appears.
            isInputFocused = true
        }
        .onChange(of: realtimeSession.messages.count) { oldCount, newCount in
            // When a new user message is completed in the realtime session,
            // send it through the food logging pipeline
            if newCount > oldCount,
               let lastMessage = realtimeSession.messages.last,
               lastMessage.isUser {
                processRealtimeUserMessage(lastMessage.text)
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
                            if streamingMessageId == nil {
                                thinkingIndicator
                            }
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
                    // Streaming assistant text (voice realtime)
                    if !realtimeSession.currentAssistantText.isEmpty {
                        Text(realtimeSession.currentAssistantText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .foregroundColor(.secondary)
                            .id("streamingAssistant")
                    }
                }
                .padding()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = false
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
        AgentTabBarMinimal(
            text: $inputText,
            isPromptFocused: $isInputFocused,
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
        messages.append(FoodLogMessage(id: UUID(), sender: .user, text: prompt))
        conversationHistory.append(["role": "user", "content": prompt])
        inputText = ""
        isLoading = true
        messages.append(FoodLogMessage(id: UUID(), sender: .status, text: "Thinking..."))
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
                if let placeholderId = streamingMessageId {
                    messages.removeAll { $0.id == placeholderId }
                    streamingMessageId = nil
                    streamingText = ""
                }
                switch result {
                case .success(let response):
                    switch response.resolvedFoodResult {
                    case .success(let food):
                        messages.append(FoodLogMessage(id: UUID(), sender: .system, text: "Got it!"))
                        onFoodReady(food)
                        isPresented = false
                    case .failure(let genError):
                        switch genError {
                        case .needsClarification(let question):
                            messages.append(FoodLogMessage(id: UUID(), sender: .system, text: question))
                            conversationHistory.append(["role": "assistant", "content": question])
                        case .unavailable(let message):
                            messages.append(FoodLogMessage(id: UUID(), sender: .system, text: message))
                        }
                    }
                case .failure(let error):
                    messages.append(FoodLogMessage(id: UUID(), sender: .system, text: "Error: \(error.localizedDescription)"))
                }
            }
        }
    }

    // MARK: - Realtime Voice Session

    private func startRealtimeSession() {
        Task {
            do {
                // Configure audio session for voice chat + TTS
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
                try audioSession.setActive(true)

                try await realtimeSession.connect()
            } catch {
                print("❌ Realtime connection failed: \(error)")
                messages.append(FoodLogMessage(sender: .system, text: "Voice connection failed. Please try again."))
            }
        }
    }

    private func endRealtimeSession() {
        realtimeSession.disconnect()
        // Messages are already processed via onChange observer
    }

    /// Process a completed user utterance from the realtime voice session
    /// through the food logging pipeline (Nutritionix lookup, follow-ups, etc.)
    private func processRealtimeUserMessage(_ text: String) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        print("🍽️ [FOOD PIPELINE] Processing voice input: '\(prompt)'")

        // Add to conversation history for context
        conversationHistory.append(["role": "user", "content": prompt])

        isLoading = true

        foodManager.generateFoodWithAI(
            foodDescription: prompt,
            history: conversationHistory,
            skipConfirmation: true
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let response):
                    switch response.resolvedFoodResult {
                    case .success(let food):
                        // Food was successfully parsed - speak confirmation via OpenAI and complete
                        print("✅ [FOOD PIPELINE] Food resolved: \(food.displayName) - \(food.calories) kcal")
                        let confirmationText = "Got it! I've logged that for you."
                        realtimeSession.speakText(confirmationText)
                        onFoodReady(food)
                        // Delay disconnect to let OpenAI finish speaking
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            realtimeSession.disconnect()
                            isPresented = false
                        }
                    case .failure(let genError):
                        switch genError {
                        case .needsClarification(let question):
                            // Speak the clarification question via OpenAI's voice
                            print("❓ [FOOD PIPELINE] Needs clarification: \(question.prefix(100))...")
                            conversationHistory.append(["role": "assistant", "content": question])
                            realtimeSession.speakText(simplifyQuestionForSpeech(question))
                        case .unavailable(let message):
                            print("⚠️ [FOOD PIPELINE] Unavailable: \(message)")
                            realtimeSession.speakText(message)
                        }
                    }
                case .failure(let error):
                    print("❌ [FOOD PIPELINE] Error: \(error.localizedDescription)")
                    let errorMessage = "Sorry, there was an error. Please try again."
                    realtimeSession.speakText(errorMessage)
                }
            }
        }
    }

    /// Simplify option lists for speech - makes it easier to listen to
    private func simplifyQuestionForSpeech(_ question: String) -> String {
        // If it contains bullet points with options, simplify for speech
        if question.contains("• ") {
            let lines = question.components(separatedBy: "\n")
            if let firstLine = lines.first {
                let optionCount = lines.filter { $0.contains("• ") }.count
                return "\(firstLine) I found \(optionCount) options. Please say A, B, or C, or describe which one you want."
            }
        }
        return question
    }

    // MARK: - Streaming typewriter status

    private func startStreamingStatus(for prompt: String) {
        streamingText = ""
        print("[STREAM UI] start streaming status for prompt: \(prompt)")

        // Clean up any previous streaming placeholders to avoid double-rendered ghost text.
        if let existingId = streamingMessageId {
            messages.removeAll { $0.id == existingId }
            streamingMessageId = nil
        }
        if let token = streamingToken {
            foodManager.cancelStream(token: token)
            streamingToken = nil
        }

        let systemMessage = [
            "role": "system",
            "content": "You are acknowledging the user's food log while we fetch nutrition. Reply with a short neutral sentence. Do not say you have logged anything. Do not include numbers or nutrition values."
        ]
        let userMessage = ["role": "user", "content": prompt]
        let payload = [systemMessage, userMessage]

        // Remove existing status rows while we stream the live text to avoid duplicate ghost lines.
        messages.removeAll { $0.sender == .status }

        // Insert a placeholder system message that will grow as tokens arrive.
        let placeholderId = UUID()
        streamingMessageId = placeholderId
        messages.append(FoodLogMessage(id: placeholderId, sender: .system, text: ""))

        streamingToken = foodManager.streamAIResponse(
            messages: payload,
            model: "gpt-5.1",
            temperature: 0.4,
            onDelta: { delta in
                print("[STREAM UI] delta:", delta)
                streamingText.append(delta)
                if let id = streamingMessageId,
                   let idx = messages.firstIndex(where: { $0.id == id }) {
                    messages[idx].text = streamingText
                }
            },
            onComplete: {
                print("[STREAM UI] complete")
                // Keep the streamed text visible; just clear the token.
                streamingToken = nil
                streamingMessageId = nil
                streamingText = ""
            },
            onError: { error in
                print("[STREAM UI] error:", error.localizedDescription)
                streamingText = ""
                streamingToken = nil
                streamingMessageId = nil
            }
        )
        if let token = streamingToken {
            print("[STREAM UI] streaming token:", token.uuidString)
        } else {
            print("[STREAM UI] streaming token is nil (stream could not start)")
        }
    }

    private func stopStreamingStatus() {
        if let token = streamingToken {
            foodManager.cancelStream(token: token)
        }
        streamingToken = nil
        if let placeholderId = streamingMessageId {
            messages.removeAll { $0.id == placeholderId }
        }
        streamingMessageId = nil
        streamingText = ""
    }
}

private struct FoodLogMessage: Identifiable {
    enum Sender {
        case user, system, status
    }
    let id: UUID
    let sender: Sender
    var text: String

    init(id: UUID = UUID(), sender: Sender, text: String) {
        self.id = id
        self.sender = sender
        self.text = text
    }
}

// MARK: - Thinking Indicator Helpers

extension FoodLogAgentView {
    private var thinkingIndicator: some View {
        HStack(spacing: 10) {
            thinkingPulseCircle
            ZStack {
                Text(currentStatusText)
                    .font(.footnote)
                    .foregroundColor(.secondary.opacity(0.35))
                Text(currentStatusText)
                    .font(.footnote)
                    .foregroundColor(.clear)
                    .overlay(
                        GeometryReader { geo in
                            let width = geo.size.width
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, Color.secondary.opacity(0.7), .clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: width, height: geo.size.height)
                            .offset(x: shimmerActive ? width : -width)
                            .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: shimmerActive)
                        }
                        .mask(Text(currentStatusText).font(.footnote))
                    )
            }
        }
        .padding(.vertical, 4)
        .onAppear { shimmerActive = true }
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
