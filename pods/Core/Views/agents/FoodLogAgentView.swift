//
//  FoodLogAgentView.swift
//  pods
//
//  Created by Dimi Nunez on 12/6/25.
//


import SwiftUI
import AVFoundation
import UIKit
import SafariServices

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
    @State private var currentStreamTask: URLSessionDataTask?
@State private var shimmerActive = false
@FocusState private var isInputFocused: Bool
@FocusState private var isUserMessageEditorFocused: Bool
@State private var statusPhraseIndex = 0
@State private var activeStatusMessageId: UUID?
@State private var thinkingTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
@State private var isAtBottom = true
@State private var scrollProxy: ScrollViewProxy?
@State private var likedMessageIDs: Set<UUID> = []
@State private var dislikedMessageIDs: Set<UUID> = []
@State private var shareText: String?
@State private var showShareSheet = false
@State private var showCopyToast = false
@State private var showUserMessageSheet = false
@State private var userMessageSheetText = ""
@State private var userMessageDraft = ""
@State private var isUserMessageEditing = false
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
        .sheet(isPresented: $showUserMessageSheet, onDismiss: resetUserMessageSheet) {
            userMessageSheet
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

    private enum CombinedChatMessage: Identifiable {
        case text(FoodLogMessage)
        case voice(RealtimeMessage)

        var id: String {
            switch self {
            case .text(let message):
                return "text-\(message.id.uuidString)"
            case .voice(let message):
                return "voice-\(message.id.uuidString)"
            }
        }

        var timestamp: Date {
            switch self {
            case .text(let message):
                return message.timestamp
            case .voice(let message):
                return message.timestamp
            }
        }
    }

    private var combinedMessages: [CombinedChatMessage] {
        let textMessages = messages.map { CombinedChatMessage.text($0) }
        let voiceMessages = realtimeSession.messages.map { CombinedChatMessage.voice($0) }
        return (textMessages + voiceMessages).sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.id < rhs.id
            }
            return lhs.timestamp < rhs.timestamp
        }
    }

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        // Messages (text + voice)
                        ForEach(combinedMessages) { combinedMessage in
                            switch combinedMessage {
                            case .text(let message):
                                switch message.sender {
                                case .user:
                                    HStack {
                                        Spacer()
                                        Text(message.text)
                                            .padding(10)
                                            .background(Color(.systemGray5))
                                            .foregroundColor(.primary)
                                            .cornerRadius(16)
                                            .contextMenu {
                                                Button {
                                                    handleCopy(text: message.text)
                                                } label: {
                                                    Label("Copy", systemImage: "doc.on.doc")
                                                }
                                                Button {
                                                    presentUserMessageSheet(text: message.text, startEditing: true)
                                                } label: {
                                                    Label("Edit", systemImage: "pencil")
                                                }
                                            }
                                            .onTapGesture {
                                                presentUserMessageSheet(text: message.text, startEditing: false)
                                            }
                                    }
                                    .id(combinedMessage.id)
                                case .system:
                                    // Hide action icons for streaming message
                                    if message.id == streamingMessageId {
                                        // Streaming message - show text without action icons
                                        FormattedAssistantMessage(text: message.text)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id(combinedMessage.id)
                                    } else {
                                        AssistantMessageWithActions(
                                            text: message.text,
                                            isLiked: likedMessageIDs.contains(message.id),
                                            isDisliked: dislikedMessageIDs.contains(message.id),
                                            onCopy: { handleCopy(text: message.text) },
                                            onLike: { toggleLike(for: message.id) },
                                            onDislike: { toggleDislike(for: message.id) },
                                            onSpeak: { speak(message.text) },
                                            onShare: { share(text: message.text) },
                                            onLinkTapped: handleLinkTap
                                        )
                                        .id(combinedMessage.id)
                                    }
                                case .status:
                                    if streamingMessageId == nil {
                                        thinkingIndicator
                                            .id(combinedMessage.id)
                                    }
                                }
                            case .voice(let message):
                                if message.isUser {
                                    HStack {
                                        Spacer()
                                        Text(message.text)
                                            .padding(10)
                                            .background(Color(.systemGray5))
                                            .foregroundColor(.primary)
                                            .cornerRadius(16)
                                            .contextMenu {
                                                Button {
                                                    handleCopy(text: message.text)
                                                } label: {
                                                    Label("Copy", systemImage: "doc.on.doc")
                                                }
                                                Button {
                                                    presentUserMessageSheet(text: message.text, startEditing: true)
                                                } label: {
                                                    Label("Edit", systemImage: "pencil")
                                                }
                                            }
                                            .onTapGesture {
                                                presentUserMessageSheet(text: message.text, startEditing: false)
                                            }
                                    }
                                    .id(combinedMessage.id)
                                } else {
                                    AssistantMessageWithActions(
                                        text: message.text,
                                        isLiked: likedMessageIDs.contains(message.id),
                                        isDisliked: dislikedMessageIDs.contains(message.id),
                                        onCopy: { handleCopy(text: message.text) },
                                        onLike: { toggleLike(for: message.id) },
                                        onDislike: { toggleDislike(for: message.id) },
                                        onSpeak: { speak(message.text) },
                                        onShare: { share(text: message.text) },
                                        onLinkTapped: handleLinkTap
                                    )
                                    .id(combinedMessage.id)
                                }
                            }
                        }

                        // Streaming user text (what user is currently saying)
                        if !realtimeSession.currentUserText.isEmpty {
                            HStack {
                                Spacer()
                                Text(realtimeSession.currentUserText)
                                    .padding(10)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
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
            isStreaming: isLoading || streamingMessageId != nil,
            onStopTapped: { stopStreamingResponse() },
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

    private func sendPrompt(text: String? = nil, clearInput: Bool = true) {
        let prompt = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        // If user asks to repeat pending options, just repeat without re-calling API
        if let pending = pendingClarificationQuestion,
           prompt.lowercased().contains("option") {
            messages.append(FoodLogMessage(id: UUID(), sender: .system, text: pending))
            realtimeSession.speakText(simplifyQuestionForSpeech(pending))
            conversationHistory.append(["role": "assistant", "content": pending])
            if clearInput {
                inputText = ""
            }
            return
        }

        messages.append(FoodLogMessage(id: UUID(), sender: .user, text: prompt))
        conversationHistory.append(["role": "user", "content": prompt])
        if clearInput {
            inputText = ""
        }
        isLoading = true
        HapticFeedback.generateBurstThenSingle(count: 4)

        // Add a status message for the thinking indicator
        let statusMessageId = UUID()
        messages.append(FoodLogMessage(id: statusMessageId, sender: .status, text: ""))
        activeStatusMessageId = statusMessageId
        activeStatusMessageId = statusMessageId

        // Track streaming message separately (nil until first delta arrives)
        streamingMessageId = nil
        streamingText = ""

        // Use the streaming orchestrator endpoint - AI decides when to call log_food tool
        // Text streams in token by token like voice mode
        currentStreamTask = foodManager.foodChatWithOrchestratorStream(
            message: prompt,
            history: conversationHistory,
            onDelta: { delta in
                // On first delta, create the streaming message and hide status
                if streamingMessageId == nil {
                    let newId = UUID()
                    streamingMessageId = newId
                    messages.removeAll { $0.id == statusMessageId }
                    if activeStatusMessageId == statusMessageId {
                        activeStatusMessageId = nil
                    }
                    messages.append(FoodLogMessage(id: newId, sender: .system, text: delta))
                } else if let currentId = streamingMessageId,
                          let index = messages.firstIndex(where: { $0.id == currentId }) {
                    messages[index].text += delta
                }
                streamingText += delta
            },
            onComplete: { result in
                isLoading = false
                currentStreamTask = nil
                // Remove status message if still present
                messages.removeAll { $0.id == statusMessageId }
                if activeStatusMessageId == statusMessageId {
                    activeStatusMessageId = nil
                }

                // Keep the streaming message ID for reference, then clear tracking
                let completedMessageId = streamingMessageId
                streamingMessageId = nil
                streamingText = ""

                switch result {
                case .success(let response):
                    // Don't remove/re-add the message - just update tracking and handle response
                    // The streaming message already has the text, just needs action icons (handled by clearing streamingMessageId)
                    handleOrchestratorResponse(response, existingMessageId: completedMessageId)
                case .failure(let error):
                    // Check if this was a cancellation - if so, silently ignore
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                        // User cancelled - no error message needed
                        if let msgId = completedMessageId {
                            messages.removeAll { $0.id == msgId }
                        }
                        return
                    }

                    pendingClarificationQuestion = nil
                    // Remove streaming message on error and show error
                    if let msgId = completedMessageId {
                        messages.removeAll { $0.id == msgId }
                    }
                    messages.append(FoodLogMessage(id: UUID(), sender: .system, text: "Error: \(error.localizedDescription)"))
                }
            }
        )
    }

    /// Handle response from the food chat orchestrator endpoint
    /// The AI decides whether to call the log_food tool or just chat
    /// - Parameter existingMessageId: If provided, the message was already streamed and we shouldn't add it again
    private func handleOrchestratorResponse(_ response: FoodChatResponse, existingMessageId: UUID? = nil) {
        // Only add message if it wasn't already streamed
        if existingMessageId == nil {
            messages.append(FoodLogMessage(id: UUID(), sender: .system, text: response.message))
        }
        // Always add to conversation history
        conversationHistory.append(["role": "assistant", "content": response.message])

        switch response.type {
        case .text:
            // AI decided this was just a chat message, not food logging
            pendingClarificationQuestion = nil

        case .foodLogged:
            pendingClarificationQuestion = nil
            // Check for multi-food meal
            if let mealItems = response.mealItems, mealItems.count > 1, let food = response.food {
                // Convert FoodChatFood to Food and present meal summary
                let convertedFood = convertChatFoodToFood(food)
                let convertedItems = mealItems.map { convertChatMealItemToMealItem($0) }
                presentMealSummary(foods: [convertedFood], items: convertedItems)
            } else if let food = response.food {
                // Single food logged
                let convertedFood = convertChatFoodToFood(food)
                onFoodReady(convertedFood)
                isPresented = false
            }

        case .needsClarification:
            // Store options for user selection
            if let options = response.options {
                pendingOptions = options
                pendingClarificationQuestion = response.message
            }

        case .error:
            pendingClarificationQuestion = nil
            // Error message is already displayed via response.message
        }
    }

    /// Convert simplified FoodChatFood to full Food model
    private func convertChatFoodToFood(_ chatFood: FoodChatFood) -> Food {
        // Use full nutrient payload when available; otherwise derive from macros
        let nutrients: [Nutrient] = {
            if let full = chatFood.foodNutrients, !full.isEmpty {
                return full
            }

            var compact: [Nutrient] = []
            if let calories = chatFood.calories {
                compact.append(Nutrient(nutrientName: "Energy", value: calories, unitName: "kcal"))
            }
            if let protein = chatFood.protein {
                compact.append(Nutrient(nutrientName: "Protein", value: protein, unitName: "g"))
            }
            if let carbs = chatFood.carbs {
                compact.append(Nutrient(nutrientName: "Carbohydrate, by difference", value: carbs, unitName: "g"))
            }
            if let fat = chatFood.fat {
                compact.append(Nutrient(nutrientName: "Total lipid (fat)", value: fat, unitName: "g"))
            }
            return compact
        }()

        // Create a default food measure
        let measure = FoodMeasure(
            disseminationText: chatFood.servingSizeText ?? "1 serving",
            gramWeight: 100.0,
            id: 1,
            modifier: chatFood.servingSizeText ?? "serving",
            measureUnitName: "serving",
            rank: 1
        )

        return Food(
            fdcId: chatFood.id ?? Int.random(in: 1000000..<9999999),
            description: chatFood.name ?? "Unknown",
            brandOwner: nil,
            brandName: nil,
            servingSize: 1.0,
            numberOfServings: 1.0,
            servingSizeUnit: "serving",
            householdServingFullText: chatFood.servingSizeText,
            foodNutrients: nutrients,
            foodMeasures: [measure]
        )
    }

    /// Convert simplified FoodChatMealItem to MealItem
    private func convertChatMealItemToMealItem(_ chatItem: FoodChatMealItem) -> MealItem {
        return MealItem(
            name: chatItem.name ?? "Unknown",
            serving: 1.0,
            servingUnit: "serving",
            calories: chatItem.calories ?? 0,
            protein: chatItem.protein ?? 0,
            carbs: chatItem.carbs ?? 0,
            fat: chatItem.fat ?? 0
        )
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

    private func focusUserMessageEditor() {
        DispatchQueue.main.async {
            isUserMessageEditorFocused = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isUserMessageEditorFocused = true
        }
    }

    private func presentUserMessageSheet(text: String, startEditing: Bool) {
        userMessageSheetText = text
        userMessageDraft = text
        isUserMessageEditing = startEditing
        showUserMessageSheet = true
        isInputFocused = false
        if startEditing {
            focusUserMessageEditor()
        }
    }

    private func resetUserMessageSheet() {
        isUserMessageEditing = false
        userMessageSheetText = ""
        userMessageDraft = ""
        isUserMessageEditorFocused = false
    }

    private func handleUserMessageEditAction() {
        if !isUserMessageEditing {
            userMessageDraft = userMessageSheetText
            isUserMessageEditing = true
            focusUserMessageEditor()
            return
        }

        let trimmed = userMessageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        showUserMessageSheet = false
        isUserMessageEditing = false
        sendPrompt(text: trimmed, clearInput: true)
    }

    private var userMessageSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if isUserMessageEditing {
                    TextEditor(text: $userMessageDraft)
                        .font(.system(size: 18, weight: .semibold))
                        .focused($isUserMessageEditorFocused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 220)
                } else {
                    ScrollView {
                        Text(userMessageSheetText)
                            .font(.system(size: 18, weight: .semibold))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showUserMessageSheet = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isUserMessageEditing {
                        checkmarkToolbarButton {
                            handleUserMessageEditAction()
                        }
                    } else {
                        Button {
                            handleCopy(text: userMessageSheetText)
                            showUserMessageSheet = false
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        Button {
                            handleUserMessageEditAction()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
        }
        .onAppear {
            if isUserMessageEditing {
                focusUserMessageEditor()
            }
        }
        .onChange(of: isUserMessageEditing) { _, editing in
            if editing {
                focusUserMessageEditor()
            } else {
                isUserMessageEditorFocused = false
            }
        }
    }

    @ViewBuilder
    private func checkmarkToolbarButton(action: @escaping () -> Void) -> some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.glassProminent)
        } else {
            Button(action: action) {
                Image(systemName: "checkmark")
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
        HapticFeedback.generateLigth()
        TTSService.shared.speak(text)
    }

    private func share(text: String) {
        shareText = text
        showShareSheet = true
        HapticFeedback.generate()
    }

    private func handleLinkTap(_ url: URL) {
        SafeLinkHandler.shared.handleLink(url)
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

    private func stopStreamingResponse() {
        // Cancel the network task first
        currentStreamTask?.cancel()
        currentStreamTask = nil

        if let token = streamingToken {
            foodManager.cancelStream(token: token)
        }
        streamingToken = nil
        streamingText = ""
        if let statusId = activeStatusMessageId {
            messages.removeAll { $0.id == statusId }
        }
        if let placeholderId = streamingMessageId {
            messages.removeAll { $0.id == placeholderId }
        }
        streamingMessageId = nil
        activeStatusMessageId = nil
        isLoading = false
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
    let timestamp: Date

    init(id: UUID = UUID(), sender: Sender, text: String, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
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
            "Tinkering...",
            "Pondering...",
            "Sparkling..."
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
                         isBranded: Bool,
                         brandName: String?,
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
            skipConfirmation: true,
            isBrandedHint: isBranded,
            brandNameHint: brandName
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

    // MARK: - Activity Logging (not supported in FoodLogAgentView)

    func realtimeSession(_ session: RealtimeVoiceSession, didRequestActivityLog activityName: String, activityType: String?, durationMinutes: Int, caloriesBurned: Int?, notes: String?, completion: @escaping (VoiceToolResult) -> Void) {
        // FoodLogAgentView is food-only; return error for activity logging
        completion(VoiceToolResult.failure(error: "Activity logging is not supported in this view. Please use the main agent."))
    }

    // MARK: - Data Queries (not supported in FoodLogAgentView)

    func realtimeSession(_ session: RealtimeVoiceSession, didRequestQuery queryType: VoiceQueryType, args: [String: Any], completion: @escaping (VoiceToolResult) -> Void) {
        // FoodLogAgentView is food-only; return error for queries
        completion(VoiceToolResult.failure(error: "Data queries are not supported in this view. Please use the main agent."))
    }

    // MARK: - Goal Updates (not supported in FoodLogAgentView)

    func realtimeSession(_ session: RealtimeVoiceSession, didRequestGoalUpdate goals: [String: Int], completion: @escaping (VoiceToolResult) -> Void) {
        // FoodLogAgentView is food-only; return error for goal updates
        completion(VoiceToolResult.failure(error: "Goal updates are not supported in this view. Please use the main agent."))
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
    var onLinkTapped: ((URL) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MarkdownMessageView(
                text: text,
                citations: nil,
                onLinkTapped: onLinkTapped
            )
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

/// Simple wrapper for streaming messages (plain text during streaming)
private struct FormattedAssistantMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}

struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
