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
    @FocusState private var isInputFocused: Bool
    @State private var statusPhraseIndex = 0
    @State private var thinkingTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatScroll
                inputBar
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
    }

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
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
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        VStack {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Describe what you ate…", text: $inputText, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(1...4)
                    .padding(.vertical, 8)
                    .focused($isInputFocused)

                Button {
                    sendPrompt()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(isLoading || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color("chat"))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func sendPrompt() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        messages.append(FoodLogMessage(sender: .user, text: prompt))
        conversationHistory.append(["role": "user", "content": prompt])
        inputText = ""
        isLoading = true
        messages.append(FoodLogMessage(sender: .status, text: "Analyzing…"))

        foodManager.generateFoodWithAI(
            foodDescription: prompt,
            history: conversationHistory,
            skipConfirmation: true
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                messages.removeAll { $0.sender == .status }
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
