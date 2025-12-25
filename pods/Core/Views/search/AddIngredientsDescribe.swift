//
//  AddIngredientsDescribe.swift
//  pods
//
//  Created by Dimi Nunez on 12/20/25.
//

import SwiftUI
import AVFoundation

// MARK: - Message Model for Describe Chat

enum IngredientMessageSender {
    case user
    case system
    case status
}

struct IngredientMessage: Identifiable {
    let id: UUID
    let sender: IngredientMessageSender
    var text: String

    init(id: UUID = UUID(), sender: IngredientMessageSender, text: String) {
        self.id = id
        self.sender = sender
        self.text = text
    }
}

// MARK: - AddIngredientsDescribe View

struct AddIngredientsDescribe: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager

    var onIngredientAdded: (Food) -> Void

    @State private var messages: [IngredientMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading = false
    @State private var conversationHistory: [[String: String]] = []
    @State private var streamingText: String = ""
    @State private var streamingMessageId: UUID?
    @State private var currentStreamTask: URLSessionDataTask?
    @FocusState private var isInputFocused: Bool
    @State private var statusPhraseIndex = 0
    @State private var thinkingTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    @State private var isAtBottom = true
    @State private var showCopyToast = false
    @State private var shimmerActive = false
    @State private var isToolCallInFlight = false
    @State private var pendingOptions: [ClarificationOption]? = nil
    @State private var pendingClarificationQuestion: String? = nil
    @State private var activeStatusMessageId: UUID?

    // Ingredient summary sheet (single food)
    @State private var scannedFood: Food?
    @State private var showIngredientSummary = false
    @State private var ingredientAddedViaVoice = false

    // Multi-ingredient summary sheet
    @State private var scannedFoods: [Food] = []
    @State private var scannedMealItems: [MealItem] = []
    @State private var showIngredientPlateSummary = false
    @State private var ingredientsAddedViaPlate = false

    // Toast state
    @State private var showAddedToast = false
    @State private var toastMessage = ""

    // Realtime voice session
    @StateObject private var realtimeSession = RealtimeVoiceSession()

    private let statusPhrases = ["Thinking...", "Analyzing...", "Processing..."]

    var body: some View {
        VStack(spacing: 0) {
            chatScroll
            inputBar
        }
        .onReceive(thinkingTimer) { _ in
            guard isLoading else { return }
            statusPhraseIndex = (statusPhraseIndex + 1) % statusPhrases.count
        }
        .onChange(of: isLoading) { _, loading in
            if !loading { statusPhraseIndex = 0 }
        }
        .onAppear {
            isInputFocused = true
            realtimeSession.delegate = self
        }
        .onDisappear {
            // Clean up realtime session when view disappears
            if realtimeSession.state != .idle {
                realtimeSession.disconnect()
            }
        }
        .sheet(isPresented: $showIngredientSummary, onDismiss: {
            // When sheet dismisses, check if ingredient was added and show toast
            if ingredientAddedViaVoice, let food = scannedFood {
                showToast("Added \(food.description) to recipe")
                ingredientAddedViaVoice = false
            }
        }) {
            if let food = scannedFood {
                IngredientSummaryView(food: food, onAddToRecipe: { updatedFood in
                    ingredientAddedViaVoice = true
                    onIngredientAdded(updatedFood)
                    // IngredientSummaryView will dismiss itself
                    // Don't dismiss AddIngredientsDescribe - user may want to describe more ingredients
                })
            }
        }
        .sheet(isPresented: $showIngredientPlateSummary, onDismiss: {
            // When sheet dismisses, check if ingredients were added and show toast
            if ingredientsAddedViaPlate {
                let count = scannedMealItems.isEmpty ? scannedFoods.count : scannedMealItems.count
                showToast("Added \(count) ingredient\(count == 1 ? "" : "s") to recipe")
                ingredientsAddedViaPlate = false
            }
        }) {
            IngredientPlateSummaryView(
                foods: scannedFoods,
                mealItems: scannedMealItems,
                onAddToRecipe: { foods, mealItems in
                    ingredientsAddedViaPlate = true
                    // Add all foods as ingredients
                    for food in foods {
                        onIngredientAdded(food)
                    }
                    // If we have meal items but no corresponding foods, convert meal items to foods
                    if foods.isEmpty && !mealItems.isEmpty {
                        for item in mealItems {
                            let food = convertMealItemToFood(item)
                            onIngredientAdded(food)
                        }
                    }
                }
            )
        }
        .overlay(alignment: .top) {
            if showAddedToast {
                ingredientToastView
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
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

    // MARK: - Chat Scroll

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
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.primary)
                                        .cornerRadius(16)
                                        .contextMenu {
                                            Button {
                                                handleCopy(text: message.text)
                                            } label: {
                                                Label("Copy", systemImage: "doc.on.doc")
                                            }
                                        }
                                }
                                .id(message.id)

                            case .system:
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(message.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if message.id != streamingMessageId {
                                        HStack(spacing: 16) {
                                            Button {
                                                handleCopy(text: message.text)
                                            } label: {
                                                Image(systemName: "doc.on.doc")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                            }

                                            Button {
                                                speak(message.text)
                                            } label: {
                                                Image(systemName: "speaker.wave.2")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
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
                                        .background(Color(.systemGray4))
                                        .foregroundColor(.primary)
                                        .cornerRadius(16)
                                        .contextMenu {
                                            Button {
                                                handleCopy(text: message.text)
                                            } label: {
                                                Label("Copy", systemImage: "doc.on.doc")
                                            }
                                        }
                                }
                                .id(message.id)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(message.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    HStack(spacing: 16) {
                                        Button {
                                            handleCopy(text: message.text)
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }

                                        Button {
                                            speak(message.text)
                                        } label: {
                                            Image(systemName: "speaker.wave.2")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .id(message.id)
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

                        // Bottom anchor
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

    // MARK: - Input Bar

    private var inputBar: some View {
        AgentTabBarMinimal(
            text: $inputText,
            isPromptFocused: $isInputFocused,
            placeholder: "Describe ingredient...",
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
            onStopTapped: { stopStreaming() },
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

    // MARK: - Thinking Indicator

    private var thinkingIndicator: some View {
        HStack(spacing: 10) {
            thinkingPulseCircle
            ZStack {
                Text(statusPhrases[statusPhraseIndex])
                    .font(.footnote)
                    .foregroundColor(.secondary.opacity(0.35))
                Text(statusPhrases[statusPhraseIndex])
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
                        .mask(Text(statusPhrases[statusPhraseIndex]).font(.footnote))
                    )
            }
        }
        .padding(.vertical, 4)
        .onAppear { shimmerActive = true }
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
                messages.append(IngredientMessage(sender: .system, text: "Voice connection failed. Please try again."))
            }
        }
    }

    private func endRealtimeSession() {
        realtimeSession.disconnect()
    }

    // MARK: - Functions

    private func sendPrompt() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        messages.append(IngredientMessage(sender: .user, text: prompt))
        conversationHistory.append(["role": "user", "content": prompt])
        inputText = ""
        isLoading = true
        HapticFeedback.generateLigth()

        // Add status message
        let statusMessageId = UUID()
        messages.append(IngredientMessage(id: statusMessageId, sender: .status, text: ""))
        activeStatusMessageId = statusMessageId

        streamingMessageId = nil
        streamingText = ""

        // Use the food chat orchestrator endpoint with "ingredient" context
        // This tells the backend to use "Found" instead of "Logged" in responses
        currentStreamTask = foodManager.foodChatWithOrchestratorStream(
            message: prompt,
            history: conversationHistory,
            context: "ingredient",
            onDelta: { delta in
                if streamingMessageId == nil {
                    let newId = UUID()
                    streamingMessageId = newId
                    messages.removeAll { $0.id == statusMessageId }
                    if activeStatusMessageId == statusMessageId {
                        activeStatusMessageId = nil
                    }
                    messages.append(IngredientMessage(id: newId, sender: .system, text: delta))
                } else if let currentId = streamingMessageId,
                          let index = messages.firstIndex(where: { $0.id == currentId }) {
                    messages[index].text += delta
                }
                streamingText += delta
            },
            onComplete: { result in
                isLoading = false
                currentStreamTask = nil
                messages.removeAll { $0.id == statusMessageId }
                if activeStatusMessageId == statusMessageId {
                    activeStatusMessageId = nil
                }

                let completedMessageId = streamingMessageId
                streamingMessageId = nil
                streamingText = ""

                switch result {
                case .success(let response):
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

                    if let msgId = completedMessageId {
                        messages.removeAll { $0.id == msgId }
                    }
                    messages.append(IngredientMessage(sender: .system, text: "Error: \(error.localizedDescription)"))
                }
            }
        )
    }

    private func stopStreaming() {
        // Cancel the network task first
        currentStreamTask?.cancel()
        currentStreamTask = nil

        isLoading = false
        if let statusId = activeStatusMessageId {
            messages.removeAll { $0.id == statusId }
            activeStatusMessageId = nil
        }
        if let streamingId = streamingMessageId {
            messages.removeAll { $0.id == streamingId }
        }
        streamingMessageId = nil
        streamingText = ""
    }

    private func handleOrchestratorResponse(_ response: FoodChatResponse, existingMessageId: UUID? = nil) {
        if existingMessageId == nil {
            messages.append(IngredientMessage(sender: .system, text: response.message))
        }
        conversationHistory.append(["role": "assistant", "content": response.message])

        switch response.type {
        case .text:
            // Just a chat message
            break

        case .foodLogged:
            // Food identified - check if we have multiple meal items
            if let chatMealItems = response.mealItems, !chatMealItems.isEmpty {
                // Multiple foods - convert and show plate summary
                let convertedMealItems = chatMealItems.map { convertChatMealItemToMealItem($0) }
                scannedMealItems = convertedMealItems
                // Create foods from meal items for the view
                scannedFoods = convertedMealItems.map { convertMealItemToFood($0) }
                showIngredientPlateSummary = true
            } else if let food = response.food {
                // Single food - show ingredient summary
                let convertedFood = convertChatFoodToFood(food)
                scannedFood = convertedFood
                showIngredientSummary = true
            }

        case .needsClarification:
            // Awaiting user clarification
            break

        case .error:
            // Error already displayed
            break
        }
    }

    private func convertChatMealItemToMealItem(_ chatItem: FoodChatMealItem) -> MealItem {
        // Debug: Log incoming values from FoodChatMealItem
        print("[CONVERT] FoodChatMealItem: name=\(chatItem.name ?? "nil"), serving=\(chatItem.serving ?? -1), servingUnit=\(chatItem.servingUnit ?? "nil")")

        // Create a measure from the serving unit so IngredientEditableFoodItem can display it
        let unitLabel = chatItem.servingUnit ?? "serving"
        let servingAmount = chatItem.serving ?? 1.0
        let measure = MealItemMeasure(
            unit: unitLabel,
            description: unitLabel,
            gramWeight: servingAmount
        )

        let result = MealItem(
            name: chatItem.name ?? "Unknown",
            serving: servingAmount,
            servingUnit: unitLabel,
            calories: chatItem.calories ?? 0,
            protein: chatItem.protein ?? 0,
            carbs: chatItem.carbs ?? 0,
            fat: chatItem.fat ?? 0,
            subitems: nil,
            baselineServing: nil,
            measures: [measure],
            originalServing: nil,
            foodNutrients: chatItem.foodNutrients
        )
        print("[CONVERT] MealItem result: name=\(result.name), serving=\(result.serving), servingUnit=\(result.servingUnit ?? "nil"), measures=\(result.measures.count)")
        return result
    }

    private func convertChatFoodToFood(_ chatFood: FoodChatFood) -> Food {
        // Prefer full nutrient payload when provided by the orchestrator; fall back to macros
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

    private func convertMealItemToFood(_ item: MealItem) -> Food {
        let unitLabel = item.servingUnit ?? "serving"
        let defaultMeasure = FoodMeasure(
            disseminationText: unitLabel,
            gramWeight: item.serving,
            id: 0,
            modifier: unitLabel,
            measureUnitName: unitLabel,
            rank: 0
        )

        // Use full nutrients if available, fallback to basic macros
        let nutrients: [Nutrient]
        if let fullNutrients = item.foodNutrients, !fullNutrients.isEmpty {
            nutrients = fullNutrients
        } else {
            nutrients = [
                Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
            ]
        }

        return Food(
            fdcId: item.id.hashValue,
            description: item.name,
            brandOwner: nil,
            brandName: nil,
            servingSize: item.serving,
            numberOfServings: 1,
            servingSizeUnit: item.servingUnit,
            householdServingFullText: item.originalServing?.resolvedText ?? "\(Int(item.serving)) \(item.servingUnit ?? "serving")",
            foodNutrients: nutrients,
            foodMeasures: [defaultMeasure],
            healthAnalysis: nil,
            aiInsight: nil,
            nutritionScore: nil,
            mealItems: item.subitems
        )
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

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showAddedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showAddedToast = false
            }
        }
    }

    @ViewBuilder
    private var ingredientToastView: some View {
        if #available(iOS 26.0, *) {
            Text(toastMessage)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .glassEffect(.regular.interactive())
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Text(toastMessage)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - RealtimeVoiceSessionDelegate

extension AddIngredientsDescribe: RealtimeVoiceSessionDelegate {
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
                        let mealItems = response.mealItems ?? food.mealItems
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
        // Check if we have multiple meal items - if so, show the plate summary view
        if let items = mealItems, !items.isEmpty {
            scannedFoods = [food]
            scannedMealItems = items
            showIngredientPlateSummary = true
        } else {
            // Single food - show ingredient summary
            scannedFood = food
            showIngredientSummary = true
        }
    }

    // MARK: - Activity Logging (not supported)

    func realtimeSession(_ session: RealtimeVoiceSession, didRequestActivityLog activityName: String, activityType: String?, durationMinutes: Int, caloriesBurned: Int?, notes: String?, completion: @escaping (VoiceToolResult) -> Void) {
        completion(VoiceToolResult.failure(error: "Activity logging is not supported when adding ingredients."))
    }

    // MARK: - Data Queries (not supported)

    func realtimeSession(_ session: RealtimeVoiceSession, didRequestQuery queryType: VoiceQueryType, args: [String: Any], completion: @escaping (VoiceToolResult) -> Void) {
        completion(VoiceToolResult.failure(error: "Data queries are not supported when adding ingredients."))
    }

    // MARK: - Goal Updates (not supported)

    func realtimeSession(_ session: RealtimeVoiceSession, didRequestGoalUpdate goals: [String: Int], completion: @escaping (VoiceToolResult) -> Void) {
        completion(VoiceToolResult.failure(error: "Goal updates are not supported when adding ingredients."))
    }
}

#Preview {
    AddIngredientsDescribe(onIngredientAdded: { _ in })
        .environmentObject(FoodManager())
}
