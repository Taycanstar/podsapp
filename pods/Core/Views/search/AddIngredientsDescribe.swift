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
    @FocusState private var isInputFocused: Bool
    @State private var statusPhraseIndex = 0
    @State private var thinkingTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    @State private var isAtBottom = true
    @State private var showCopyToast = false

    // Ingredient summary sheet
    @State private var scannedFood: Food?
    @State private var showIngredientSummary = false

    private let statusPhrases = ["Thinking...", "Analyzing...", "Processing..."]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                chatScroll
                inputBar
            }

            // Empty state
            if messages.isEmpty {
                VStack {
                    Spacer()
                    Text("Describe your ingredients")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("e.g. \"2 eggs and a slice of toast\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.top, 4)
                    Spacer()
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
        .onAppear {
            isInputFocused = true
        }
        .sheet(isPresented: $showIngredientSummary) {
            if let food = scannedFood {
                IngredientSummaryView(food: food, onAddToRecipe: { updatedFood in
                    onIngredientAdded(updatedFood)
                    // IngredientSummaryView will dismiss itself
                    // Don't dismiss AddIngredientsDescribe - user may want to describe more ingredients
                })
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
                        ForEach(messages) { message in
                            switch message.sender {
                            case .user:
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
        HStack(spacing: 12) {
            TextField("Describe ingredients...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemGray6))
                )
                .focused($isInputFocused)
                .onSubmit {
                    guard !isLoading else { return }
                    sendPrompt()
                }
                .submitLabel(.send)

            Button {
                guard !isLoading else { return }
                sendPrompt()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Thinking Indicator

    private var thinkingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.secondary)
                .frame(width: 8, height: 8)
                .opacity(0.6)

            Text(statusPhrases[statusPhraseIndex])
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
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

        streamingMessageId = nil
        streamingText = ""

        // Use the food chat orchestrator endpoint
        foodManager.foodChatWithOrchestratorStream(
            message: prompt,
            history: conversationHistory,
            onDelta: { delta in
                if streamingMessageId == nil {
                    let newId = UUID()
                    streamingMessageId = newId
                    messages.removeAll { $0.id == statusMessageId }
                    messages.append(IngredientMessage(id: newId, sender: .system, text: delta))
                } else if let currentId = streamingMessageId,
                          let index = messages.firstIndex(where: { $0.id == currentId }) {
                    messages[index].text += delta
                }
                streamingText += delta
            },
            onComplete: { result in
                isLoading = false
                messages.removeAll { $0.id == statusMessageId }

                let completedMessageId = streamingMessageId
                streamingMessageId = nil
                streamingText = ""

                switch result {
                case .success(let response):
                    handleOrchestratorResponse(response, existingMessageId: completedMessageId)
                case .failure(let error):
                    if let msgId = completedMessageId {
                        messages.removeAll { $0.id == msgId }
                    }
                    messages.append(IngredientMessage(sender: .system, text: "Error: \(error.localizedDescription)"))
                }
            }
        )
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
            // Food identified - show ingredient summary
            if let food = response.food {
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

    private func convertChatFoodToFood(_ chatFood: FoodChatFood) -> Food {
        var nutrients: [Nutrient] = []
        if let calories = chatFood.calories {
            nutrients.append(Nutrient(nutrientName: "Energy", value: calories, unitName: "kcal"))
        }
        if let protein = chatFood.protein {
            nutrients.append(Nutrient(nutrientName: "Protein", value: protein, unitName: "g"))
        }
        if let carbs = chatFood.carbs {
            nutrients.append(Nutrient(nutrientName: "Carbohydrate, by difference", value: carbs, unitName: "g"))
        }
        if let fat = chatFood.fat {
            nutrients.append(Nutrient(nutrientName: "Total lipid (fat)", value: fat, unitName: "g"))
        }

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
}

#Preview {
    AddIngredientsDescribe(onIngredientAdded: { _ in })
        .environmentObject(FoodManager())
}
