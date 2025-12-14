//
//  FoodLogAgentView.swift
//  pods
//
//  Created by Dimi Nunez on 12/6/25.
//


import SwiftUI
import AVFoundation
import UIKit

// Chat-style food logger reused for Text -> Add More flow
struct FoodLogAgentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager

    @Binding var isPresented: Bool
    var onFoodReady: (Food) -> Void
    var onMealLogged: (([Food]) -> Void)? = nil
    var onMealAddedToPlate: (([Food]) -> Void)? = nil
    var onMealItemsReady: ((Food, [MealItem]) -> Void)? = nil

@State private var messages: [FoodLogMessage] = []
@State private var inputText: String = ""
@State private var isLoading = false
@State private var conversationHistory: [[String: String]] = []
@State private var pendingClarificationQuestion: String? = nil
@State private var pendingOptions: [ClarificationOption]? = nil
@State private var isToolCallInFlight = false
    @State private var streamingText: String = ""
    @State private var streamingMessageId: UUID?
    @State private var streamingToken: UUID?
@State private var shimmerActive = false
@FocusState private var isInputFocused: Bool
@State private var statusPhraseIndex = 0
@State private var thinkingTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
@State private var isAtBottom = true
@State private var scrollProxy: ScrollViewProxy?
@State private var likedMessageIDs: Set<UUID> = []
@State private var dislikedMessageIDs: Set<UUID> = []
@State private var shareText: String?
@State private var showShareSheet = false
@State private var speechSynth = AVSpeechSynthesizer()
@State private var showCopyToast = false
    @State private var mealSummaryFoods: [Food] = []
    @State private var mealSummaryItems: [MealItem] = []
    @State private var showMealSummary = false

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
            realtimeSession.delegate = self
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareText {
                ShareSheetView(activityItems: [shareText])
            }
        }
        .sheet(isPresented: $showMealSummary) {
            MealPlateSummaryView(
                foods: mealSummaryFoods,
                mealItems: mealSummaryItems,
                onLogMeal: { foods, _ in
                    logMealFoods(foods)
                },
                onAddToPlate: { foods, _ in
                    addMealFoodsToPlate(foods)
                }
            )
        }
        .overlay(alignment: .top) {
            if showCopyToast {
                Text("Message copied")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        // Regular text-based messages
                        ForEach(messages) { message in
                            switch message.sender {
                            case .user:
                                HStack {
                                    Spacer()
                                    Text(message.text)
                                        .padding(10)
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                }
                                .id(message.id)
                            case .system:
                                AssistantMessageWithActions(
                                    text: message.text,
                                    isLiked: likedMessageIDs.contains(message.id),
                                    isDisliked: dislikedMessageIDs.contains(message.id),
                                    onCopy: { handleCopy(text: message.text) },
                                    onLike: { toggleLike(for: message.id) },
                                    onDislike: { toggleDislike(for: message.id) },
                                    onSpeak: { speak(message.text) },
                                    onShare: { share(text: message.text) }
                                )
                                .id(message.id)
                            case .status:
                                if streamingMessageId == nil {
                                    thinkingIndicator
                                        .id(message.id)
                                }
                            }
                        }

                        // Realtime voice messages
                        ForEach(realtimeSession.messages) { message in
                            if message.isUser {
                                HStack {
                                    Spacer()
                                    Text(message.text)
                                        .padding(10)
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                }
                                .id(message.id)
                            } else {
                                AssistantMessageWithActions(
                                    text: message.text,
                                    isLiked: likedMessageIDs.contains(message.id),
                                    isDisliked: dislikedMessageIDs.contains(message.id),
                                    onCopy: { handleCopy(text: message.text) },
                                    onLike: { toggleLike(for: message.id) },
                                    onDislike: { toggleDislike(for: message.id) },
                                    onSpeak: { speak(message.text) },
                                    onShare: { share(text: message.text) }
                                )
                                .id(message.id)
                            }
                        }

                        // Streaming user text (what user is currently saying)
                        if !realtimeSession.currentUserText.isEmpty {
                            HStack {
                                Spacer()
                                Text(realtimeSession.currentUserText)
                                    .padding(10)
                                    .background(Color.accentColor.opacity(0.6))
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                            .id("streamingUser")
                        }

                        // Streaming assistant text (voice realtime)
                        if !realtimeSession.currentAssistantText.isEmpty {
                            Text(realtimeSession.currentAssistantText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .foregroundColor(.secondary)
                                .id("streamingAssistant")
                        }

                        // Thinking indicator when realtime agent is processing
                        if realtimeSession.isProcessing {
                            thinkingIndicator
                                .id("realtimeThinking")
                        }

                        // Bottom anchor for scroll detection
                        Color.clear
                            .frame(height: 1)
                            .id("bottomAnchor")
                            .onAppear { isAtBottom = true }
                            .onDisappear { isAtBottom = false }
                    }
                    .padding()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = false
                }
                .onAppear {
                    scrollProxy = proxy
                }

                // Floating scroll-to-bottom button
                if !isAtBottom {
                    Button {
                        withAnimation {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                    }
                    .padding(.bottom, 15)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("bottomAnchor", anchor: .bottom)
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
            onRealtimeStart: {
                isInputFocused = false
                startRealtimeSession()
            },
            onRealtimeEnd: { endRealtimeSession() },
            onMuteToggle: { realtimeSession.toggleMute() }
        )
        .padding(.bottom, 8)
    }

    private func sendPrompt() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        // If user asks to repeat pending options, just repeat without re-calling Nutritionix
        if let pending = pendingClarificationQuestion,
           prompt.lowercased().contains("option") {
            messages.append(FoodLogMessage(id: UUID(), sender: .system, text: pending))
            realtimeSession.speakText(simplifyQuestionForSpeech(pending))
            conversationHistory.append(["role": "assistant", "content": pending])
            inputText = ""
            return
        }

        messages.append(FoodLogMessage(id: UUID(), sender: .user, text: prompt))
        conversationHistory.append(["role": "user", "content": prompt])
        inputText = ""
        isLoading = true
        HapticFeedback.generateBurstThenSingle(count: 4)
        messages.append(FoodLogMessage(id: UUID(), sender: .status, text: statusPhrases.first ?? "Thinking..."))
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
                    handleFoodResponse(response, isVoice: false)
                case .failure(let error):
                    pendingClarificationQuestion = nil
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
        // No-op: transcripts are handled by GPT via tool calls
    }

    private func handleCopy(text: String) {
        UIPasteboard.general.string = text
        HapticFeedback.generate()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showCopyToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopyToast = false
            }
        }
    }

    private func toggleLike(for id: UUID) {
        dislikedMessageIDs.remove(id)
        if likedMessageIDs.contains(id) {
            likedMessageIDs.remove(id)
        } else {
            likedMessageIDs.insert(id)
        }
        HapticFeedback.generate()
    }

    private func toggleDislike(for id: UUID) {
        likedMessageIDs.remove(id)
        if dislikedMessageIDs.contains(id) {
            dislikedMessageIDs.remove(id)
        } else {
            dislikedMessageIDs.insert(id)
        }
        HapticFeedback.generate()
    }

    private func speak(_ text: String) {
        speechSynth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynth.speak(utterance)
        HapticFeedback.generateLigth()
    }

    private func share(text: String) {
        shareText = text
        showShareSheet = true
        HapticFeedback.generate()
    }

    private func presentMealSummary(foods: [Food], items: [MealItem]) {
        // If callback is provided, dismiss this view and let parent handle presentation
        if let onMealItemsReady, let food = foods.first {
            onMealItemsReady(food, items)
            isPresented = false
            return
        }
        // Fallback: show sheet on top of this view
        mealSummaryFoods = foods
        mealSummaryItems = items
        showMealSummary = true
    }

    private func logMealFoods(_ foods: [Food]) {
        if let handler = onMealLogged {
            handler(foods)
        } else {
            foods.forEach { onFoodReady($0) }
        }
        isPresented = false
    }

    private func addMealFoodsToPlate(_ foods: [Food]) {
        if let handler = onMealAddedToPlate {
            handler(foods)
        } else {
            foods.forEach { onFoodReady($0) }
        }
        isPresented = false
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
            "Thinking...",
            "Shimmering...",
            "Analyzing...",
            "Tinkering..."
        ]
    }

    private func formattedClarification(question: String, options: [ClarificationOption]?) -> String {
        guard let options, !options.isEmpty else { return question }
        let lines: [String] = options.enumerated().map { idx, opt in
            let label = opt.label ?? String(UnicodeScalar(65 + idx) ?? "A")
            let name = opt.name ?? "Option \(label)"
            let brand = opt.brand ?? ""
            let serving = opt.serving ?? ""
            let kcal = opt.previewCalories.map { Int($0) }
            var parts: [String] = [name]
            if !brand.isEmpty { parts.append("(\(brand))") }
            if !serving.isEmpty { parts.append(serving) }
            if let kcal { parts.append("\(kcal) kcal") }
            return "• \(label): " + parts.joined(separator: " ")
        }
        return ([question] + lines).joined(separator: "\n")
    }

    private func handleFoodResponse(_ response: GenerateFoodResponse, isVoice: Bool) {
        if response.needsClarification {
            let text = formattedClarification(
                question: response.question ?? "Can you provide more details?",
                options: response.options
            )
            pendingClarificationQuestion = text
            messages.append(FoodLogMessage(id: UUID(), sender: .system, text: text))
            conversationHistory.append(["role": "assistant", "content": text])
            if isVoice {
                realtimeSession.speakText(simplifyQuestionForSpeech(text))
            }
            return
        }

        // If multiple foods are returned, present meal summary view
        if let foods = response.foods, foods.count > 1 {
            let items = response.mealItems ?? response.food?.mealItems ?? []
            presentMealSummary(foods: foods, items: items)
            return
        }
        if let items = response.mealItems, items.count > 1 {
            let foods = response.food.map { [$0] } ?? []
            presentMealSummary(foods: foods, items: items)
            return
        }
        if let food = response.food, let items = food.mealItems, items.count > 1 {
            presentMealSummary(foods: [food], items: items)
            return
        }

        if let food = response.food {
            pendingClarificationQuestion = nil
            if isVoice {
                print("✅ [FOOD PIPELINE] Food resolved: \(food.displayName) - \(food.calories) kcal")
                let confirmationText = "Got it! I've logged that for you."
                realtimeSession.speakText(confirmationText)
                onFoodReady(food)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    realtimeSession.disconnect()
                    isPresented = false
                }
            } else {
                messages.append(FoodLogMessage(id: UUID(), sender: .system, text: "Got it!"))
                onFoodReady(food)
                isPresented = false
            }
            return
        }

        pendingClarificationQuestion = nil
        let message = response.error ?? response.question ?? "Unable to generate nutrition data."
        messages.append(FoodLogMessage(id: UUID(), sender: .system, text: message))
        if isVoice {
            realtimeSession.speakText(message)
        }
    }

}

// MARK: - RealtimeVoiceSessionDelegate
extension FoodLogAgentView: RealtimeVoiceSessionDelegate {
    func realtimeSession(_ session: RealtimeVoiceSession,
                         didRequestFoodLookup query: String,
                         nixItemId: String?,
                         selectionLabel: String?,
                         completion: @escaping (ToolResult) -> Void) {
        guard !isToolCallInFlight else {
            completion(
                ToolResult(
                    status: .error,
                    food: nil,
                    mealItems: nil,
                    question: nil,
                    options: nil,
                    error: "Another request is in progress. Please wait a moment."
                )
            )
            return
        }
        isToolCallInFlight = true

        var effectiveDescription = query
        if let selectionLabel = selectionLabel,
           let option = pendingOptions?.first(where: { ($0.label ?? "").lowercased() == selectionLabel.lowercased() }),
           let name = option.name {
            // Prefer an explicit option name so backend can resolve the selection
            effectiveDescription = name
        }

        foodManager.generateFoodWithAI(
            foodDescription: effectiveDescription,
            history: conversationHistory,
            skipConfirmation: true
        ) { result in
            DispatchQueue.main.async {
                self.isToolCallInFlight = false
            switch result {
            case .success(let response):
                // Debug: Log response details immediately
                print("🔵 [VOICE RESPONSE] status=\(response.status) needsClarification=\(response.needsClarification)")
                print("🔵 [VOICE RESPONSE] food=\(response.food?.displayName ?? "nil") mealItems=\(response.mealItems?.count ?? -1)")
                if response.needsClarification {
                    self.pendingOptions = response.options
                    completion(
                        ToolResult(
                                status: .needsClarification,
                                food: nil,
                                mealItems: nil,
                                question: response.question,
                                options: response.options,
                                error: nil
                            )
                        )
                    } else if let food = response.food {
                        self.pendingOptions = nil
                        // Check for multi-food response via meal_items
                        let mealItems = response.mealItems ?? food.mealItems
                        print("🍽 [VOICE DEBUG] response.mealItems count: \(response.mealItems?.count ?? -1)")
                        print("🍽 [VOICE DEBUG] food.mealItems count: \(food.mealItems?.count ?? -1)")
                        print("🍽 [VOICE DEBUG] Final mealItems count: \(mealItems?.count ?? -1)")
                        completion(
                            ToolResult(
                                status: .success,
                                food: food,
                                mealItems: mealItems,
                                question: nil,
                                options: nil,
                                error: nil
                            )
                        )
                    } else {
                        completion(
                            ToolResult(
                                status: .error,
                                food: nil,
                                mealItems: nil,
                                question: nil,
                                options: nil,
                                error: response.error ?? "Unable to generate nutrition data."
                            )
                        )
                    }
                case .failure(let error):
                    completion(
                        ToolResult(
                            status: .error,
                            food: nil,
                            mealItems: nil,
                            question: nil,
                            options: nil,
                            error: error.localizedDescription
                        )
                    )
                }
            }
        }
    }

    func realtimeSession(_ session: RealtimeVoiceSession, didResolveFood food: Food, mealItems: [MealItem]?) {
        // Debug log
        print("🟢 [didResolveFood] Called with food=\(food.displayName) mealItems=\(mealItems?.count ?? -1)")
        if let items = mealItems {
            for (i, item) in items.enumerated() {
                print("🟢 [didResolveFood] Item \(i): \(item.name)")
            }
        }

        // Check if this is a multi-food response
        if let items = mealItems, items.count > 1 {
            // Multi-food: Use callback if provided, otherwise fallback to sheet
            print("✅ [FOOD PIPELINE] Multi-food resolved: \(items.count) items")
            session.disconnect()
            if let onMealItemsReady {
                // Parent will handle presentation - dismiss this view
                onMealItemsReady(food, items)
                isPresented = false
            } else {
                // Fallback: show sheet on top of this view
                presentMealSummary(foods: [food], items: items)
            }
        } else {
            // Single food: Use existing flow
            print("✅ [FOOD PIPELINE] Single food resolved: \(food.displayName)")
            onFoodReady(food)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                session.disconnect()
                isPresented = false
            }
        }
    }
}

// MARK: - Formatted Assistant Message

private struct AssistantMessageWithActions: View {
    let text: String
    let isLiked: Bool
    let isDisliked: Bool
    let onCopy: () -> Void
    let onLike: () -> Void
    let onDislike: () -> Void
    let onSpeak: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FormattedAssistantMessage(text: text)
            actionRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            actionButton(systemName: "doc.on.doc", action: onCopy)
            actionButton(systemName: "speaker.wave.2", action: onSpeak)
        }
        .padding(.top, 0)
    }

    private func actionButton(systemName: String, action: @escaping () -> Void, isActive: Bool = false) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(isActive ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct FormattedAssistantMessage: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(formattedLines.enumerated()), id: \.offset) { _, line in
                if line.isBullet {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(line.text)
                            .foregroundColor(.primary)
                    }
                } else {
                    Text(line.text)
                        .foregroundColor(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var formattedLines: [FormattedLine] {
        // Parse the text to detect list items
        // Look for patterns like "1.", "2.", numbered items, or "Or" followed by items
        let lines = text.components(separatedBy: ". ")

        // If text contains "options:" or multiple items separated by ". Or", format as bullets
        if text.lowercased().contains("option") || text.contains(". Or ") || text.contains(", or ") {
            return parseOptionsText(text)
        }

        // Default: just show as single text
        return [FormattedLine(text: text, isBullet: false)]
    }

    private func parseOptionsText(_ text: String) -> [FormattedLine] {
        var result: [FormattedLine] = []

        // Try to split by common option separators
        // Pattern: "I found a few options: ITEM1. Or ITEM2. Or ITEM3. Which one?"
        let parts = text.components(separatedBy: ". Or ")

        if parts.count > 1 {
            // First part might have intro text before the first option
            let firstPart = parts[0]
            if let colonIndex = firstPart.lastIndex(of: ":") {
                let intro = String(firstPart[...colonIndex])
                let firstOption = String(firstPart[firstPart.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                result.append(FormattedLine(text: intro, isBullet: false))
                if !firstOption.isEmpty {
                    result.append(FormattedLine(text: firstOption, isBullet: true))
                }
            } else {
                result.append(FormattedLine(text: firstPart, isBullet: true))
            }

            // Middle parts are options
            for i in 1..<parts.count - 1 {
                result.append(FormattedLine(text: parts[i].trimmingCharacters(in: .whitespaces), isBullet: true))
            }

            // Last part might have trailing question
            let lastPart = parts[parts.count - 1]
            if let questionIndex = lastPart.lastIndex(of: "?") {
                let optionText = String(lastPart[..<questionIndex]).trimmingCharacters(in: .whitespaces)
                let questionText = String(lastPart[questionIndex...])
                if !optionText.isEmpty && !optionText.starts(with: "Which") {
                    result.append(FormattedLine(text: optionText, isBullet: true))
                }
                result.append(FormattedLine(text: questionText, isBullet: false))
            } else {
                result.append(FormattedLine(text: lastPart.trimmingCharacters(in: .whitespaces), isBullet: true))
            }

            return result
        }

        // Fallback: just show as plain text
        return [FormattedLine(text: text, isBullet: false)]
    }
}

private struct FormattedLine {
    let text: String
    let isBullet: Bool
}

struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
