import SwiftUI
import UIKit
import AVFoundation
import SafariServices

struct AgentChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var onboardingViewModel: OnboardingViewModel

    // New streaming ViewModel - initialized with conversation ID if loading existing
    @StateObject private var viewModel: HealthCoachChatViewModel

    // Conversation ID to load (passed from ChatsView)
    // Using String? instead of AgentConversation? to avoid SwiftUI type complexity
    private let conversationIdToLoad: String?

    @State private var inputText: String = ""
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    @FocusState private var isUserMessageEditorFocused: Bool
    @State private var statusPhraseIndex = 0

    // Input bar state (matching AgentTabBar)
    @State private var isListening = false
    @State private var pulseScale: CGFloat = 1.0
    @StateObject private var speechRecognizer = SpeechRecognizer()

    // Scroll state for floating button
    @State private var isAtBottom = true

    // Action sheet state
    @State private var shareText: String?
    @State private var showShareSheet = false
    @State private var speechSynth = AVSpeechSynthesizer()
    @State private var showCopyToast = false
    @State private var showUserMessageSheet = false
    @State private var userMessageSheetText = ""
    @State private var userMessageDraft = ""
    @State private var isUserMessageEditing = false

    // Single food confirmation (uses FoodSummaryView)
    @State private var pendingFood: Food?
    @State private var showFoodConfirm = false

    // Meal summary for multi-food
    @State private var mealSummaryFoods: [Food] = []
    @State private var mealSummaryItems: [MealItem] = []
    @State private var showMealSummary = false

    // Plate view state
    @StateObject private var plateViewModel = PlateViewModel()
    @State private var showPlateView = false

    // Realtime voice session
    @StateObject private var realtimeSession = RealtimeVoiceSession()

    // Callbacks for actions (can be customized by parent)
    var onPlusTapped: () -> Void = {}
    var onBarcodeTapped: () -> Void = {}
    var onFoodReady: ((Food) -> Void)?
    var onMealLogged: (([Food]) -> Void)?
    var onNewConversationCreated: ((String, String) -> Void)?

    // Initial message binding to send on appear (for AgentTabBar integration)
    // Using Binding so SwiftUI reads current value when view appears, not when closure is captured
    @Binding private var initialMessage: String?

    // Initial coach message to seed as an assistant reply (for Timeline/NewHome)
    @Binding private var initialCoachMessage: String?

    // Whether to auto-start voice mode when view appears
    // Using Binding so SwiftUI reads current value when view appears, not when closure is captured
    @Binding private var startWithVoiceMode: Bool

    init(
        conversationIdToLoad: String? = nil,
        initialMessage: Binding<String?> = .constant(nil),
        initialCoachMessage: Binding<String?> = .constant(nil),
        startWithVoiceMode: Binding<Bool> = .constant(false),
        onPlusTapped: @escaping () -> Void = {},
        onBarcodeTapped: @escaping () -> Void = {},
        onNewConversationCreated: ((String, String) -> Void)? = nil
    ) {
        self.conversationIdToLoad = conversationIdToLoad
        self._initialMessage = initialMessage
        self._initialCoachMessage = initialCoachMessage
        self._startWithVoiceMode = startWithVoiceMode
        self.onPlusTapped = onPlusTapped
        self.onBarcodeTapped = onBarcodeTapped
        self.onNewConversationCreated = onNewConversationCreated
        // Initialize viewModel with conversation ID if loading existing conversation
        self._viewModel = StateObject(wrappedValue: HealthCoachChatViewModel(conversationId: conversationIdToLoad))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                chatScrollView

                inputBar

                // "Start talking" overlay when in voice mode and chat is empty
                if viewModel.messages.isEmpty && realtimeSession.messages.isEmpty {
                    if realtimeSession.state == .connecting {
                        VStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.2)
                                .padding(.bottom, 8)
                            Text("Connecting...")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else if realtimeSession.state == .connected {
                        VStack {
                            Spacer()
                            Text("Start talking")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Metryc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: startNewChat) {
                        Image(systemName: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Share", action: shareConversation)
                        Button(role: .destructive, action: startNewChat) {
                            Text("Delete Chat")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .onReceive(thinkingTimer) { _ in
            guard viewModel.isLoading else { return }
            statusPhraseIndex = (statusPhraseIndex + 1) % statusPhrases.count
        }
        .onChange(of: viewModel.isLoading) { _, loading in
            if !loading { statusPhraseIndex = 0 }
        }
        .onChange(of: viewModel.streamingMessageId) { oldValue, newValue in
            // Trigger 3 rapid haptic feedbacks when streaming starts (first delta received)
            if oldValue == nil && newValue != nil {
                HapticFeedback.generateBurstThenSingle(count: 3, interval: 0.08)
            }
        }
        .onAppear {
            isInputFocused = true
            setupCallbacks()
            realtimeSession.delegate = self

            // Load existing conversation if provided
            if let conversationId = conversationIdToLoad {
                print("🤖 AgentChatView.onAppear - Loading conversation: \(conversationId)")
                Task {
                    await loadConversation(conversationId)
                }
            }

            // Send initial message if provided (from AgentTabBar)
            print("🤖 AgentChatView.onAppear - initialMessage: \(initialMessage ?? "nil"), initialCoachMessage: \(initialCoachMessage ?? "nil"), startWithVoiceMode: \(startWithVoiceMode)")
            if conversationIdToLoad == nil, let coachMessage = initialCoachMessage, !coachMessage.isEmpty {
                print("🤖 AgentChatView: Seeding initial coach message: \(coachMessage)")
                viewModel.seedCoachMessage(coachMessage)
                initialCoachMessage = nil
            }
            if let message = initialMessage, !message.isEmpty {
                print("🤖 AgentChatView: Sending initial message: \(message)")
                viewModel.send(message: message)
                // Clear it to avoid re-sending on re-appear
                initialMessage = nil
            }

            // Auto-start voice mode if requested
            if startWithVoiceMode {
                print("🎤 AgentChatView: Auto-starting voice mode")
                // Clear it to avoid re-starting on re-appear
                startWithVoiceMode = false
                Task {
                    try? await realtimeSession.connect()
                }
            }
        }
        .onDisappear {
            if realtimeSession.state != .idle {
                realtimeSession.disconnect()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareText {
                ShareSheetView(activityItems: [shareText])
            }
        }
        .sheet(isPresented: $showUserMessageSheet, onDismiss: resetUserMessageSheet) {
            userMessageSheet
        }
        .sheet(isPresented: $showFoodConfirm) {
            if let food = pendingFood {
                FoodSummaryView(food: food)
                    .environmentObject(foodManager)
                    .environmentObject(onboardingViewModel)
                    .environmentObject(dayLogsVM)
            }
        }
        .sheet(isPresented: $showMealSummary) {
            NavigationStack {
                MealPlateSummaryView(
                    foods: mealSummaryFoods,
                    mealItems: mealSummaryItems,
                    onLogMeal: { foods, items in
                        logMealFoods(foods: foods, items: items)
                    },
                    onAddToPlate: { foods, mealItems in
                        addMealFoodsToPlate(foods, mealItems: mealItems)
                    }
                )
            }
        }
        .sheet(isPresented: $showPlateView) {
            NavigationStack {
                PlateView(
                    viewModel: plateViewModel,
                    selectedMealPeriod: suggestedMealPeriod(for: Date()),
                    mealTime: Date(),
                    onFinished: {
                        showPlateView = false
                        plateViewModel.clear()
                    },
                    onPlateLogged: { foods in
                        // Show toast with logged foods
                        let foodNames = foods.prefix(2).map { $0.description }.joined(separator: ", ")
                        let suffix = foods.count > 2 ? " +\(foods.count - 2) more" : ""
                        showToast(with: "Logged \(foodNames)\(suffix)")
                    }
                )
            }
        }
        .overlay(alignment: .top) {
            if showCopyToast {
                Text("Message copied")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .top) {
            if showToast {
                Text(toastMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func setupCallbacks() {
        // Set up food ready callback - show FoodSummaryView (ConfirmLogView) for single foods
        viewModel.onFoodReady = { food in
            pendingFood = food
            showFoodConfirm = true
        }

        // Set up meal items ready callback - show MealPlateSummaryView for multi-food
        viewModel.onMealItemsReady = { food, items in
            mealSummaryFoods = [food]
            mealSummaryItems = items
            showMealSummary = true
        }

        // Set up activity logged callback
        viewModel.onActivityLogged = { activity in
            dayLogsVM.loadLogs(for: dayLogsVM.selectedDate, force: true)
            showToast(with: "Logged \(activity.activityName)")
        }

        // Sync conversation ID from text chat to voice session
        // Also notify parent when a new conversation is created
        // Capture values directly since self is a struct (value type) and can't be weakly referenced
        let isNewConversation = conversationIdToLoad == nil
        let callback = onNewConversationCreated
        viewModel.onConversationIdUpdated = { [weak realtimeSession, weak viewModel] conversationId in
            realtimeSession?.currentConversationId = conversationId

            // Only notify parent for NEW conversations (when we started with nil conversationIdToLoad)
            // This prevents notifying when loading an existing conversation
            guard isNewConversation,
                  let firstUserMessage = viewModel?.messages.first(where: { $0.sender == .user }) else {
                return
            }

            // Generate title from first 6-8 words of user message
            let words = firstUserMessage.text.split(separator: " ").prefix(8)
            var title = words.joined(separator: " ")
            if title.count > 50 {
                title = String(title.prefix(47)) + "..."
            }
            callback?(conversationId, title)
        }

        // Sync conversation ID from voice session to text chat
        realtimeSession.onConversationIdUpdated = { [weak viewModel] conversationId in
            viewModel?.currentConversationId = conversationId
        }

        // Initialize voice session with current conversation ID if exists
        if let conversationId = viewModel.currentConversationId {
            realtimeSession.currentConversationId = conversationId
        }
    }

    // MARK: - Chat Scroll View

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        // Regular text-based messages
                        ForEach(viewModel.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }

                        // Voice session messages (from realtime mode)
                        ForEach(realtimeSession.messages) { voiceMessage in
                            voiceMessageRow(voiceMessage, isLastAssistant: isLastAssistantMessage(voiceMessage))
                                .id(voiceMessage.id)
                        }

                        // Streaming user text (what user is currently saying via voice)
                        if !realtimeSession.currentUserText.isEmpty {
                            HStack {
                                Spacer()
                                Text(realtimeSession.currentUserText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .cornerRadius(16)
                            }
                            .id("streamingUser")
                        }

                        // Streaming assistant text (voice realtime response)
                        if !realtimeSession.currentAssistantText.isEmpty {
                            Text(realtimeSession.currentAssistantText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .foregroundColor(.secondary)
                                .id("streamingAssistant")
                        }

                        // Thinking indicator (text mode)
                        if viewModel.isLoading && viewModel.streamingMessageId == nil {
                            thinkingIndicator
                        }

                        // Thinking indicator (voice mode - when realtime agent is processing)
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

                        // Extra space at bottom for floating input bar
                        Spacer()
                            .frame(height: 120)
                    }
                    .padding()
                }
                .contentShape(Rectangle())
                .onTapGesture { isInputFocused = false }
                .onAppear {
                    scrollProxy = proxy
                }

                // Floating scroll-to-bottom button (positioned above input bar)
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
                    .padding(.bottom, 140)
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

    // MARK: - Message Row

    @ViewBuilder
    private func messageRow(_ message: HealthCoachMessage) -> some View {
        let isStreaming = message.id == viewModel.streamingMessageId

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
                    .contextMenu {
                        Button {
                            copyMessageToClipboard(message.text)
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

        case .coach:
            VStack(alignment: .leading, spacing: 8) {
                // Use simple Text during streaming to avoid flicker, full markdown after
                if isStreaming {
                    Text(message.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    MarkdownMessageView(
                        text: message.text,
                        citations: message.citations?.map { citation in
                            Citation(
                                id: citation.id,
                                title: citation.title,
                                url: citation.url,
                                domain: citation.domain,
                                snippet: citation.snippet
                            )
                        },
                        onLinkTapped: { url in
                            handleLinkTap(url)
                        },
                        onCitationTapped: { citation in
                            handleCitationTap(citation)
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Show action icons only when not streaming
                if !isStreaming {
                    messageActions(for: message)
                }
            }

        case .system:
            Text(message.text)
                .font(.footnote)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity, alignment: .center)

        case .status:
            EmptyView()
        }
    }

    /// Check if this message is the last assistant message in the voice messages array
    private func isLastAssistantMessage(_ message: RealtimeMessage) -> Bool {
        guard !message.isUser else { return false }
        // Find the last assistant message
        if let lastAssistant = realtimeSession.messages.last(where: { !$0.isUser }) {
            return lastAssistant.id == message.id
        }
        return false
    }

    @ViewBuilder
    private func voiceMessageRow(_ message: RealtimeMessage, isLastAssistant: Bool) -> some View {
        if message.isUser {
            HStack {
                Spacer()
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray4))
                    .foregroundColor(.primary)
                    .cornerRadius(16)
                    .contextMenu {
                        Button {
                            copyMessageToClipboard(message.text)
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
        } else {
            VStack(alignment: .leading, spacing: 8) {
                MarkdownMessageView(
                    text: message.text,
                    citations: nil,
                    onLinkTapped: { url in
                        handleLinkTap(url)
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                // Only show action icons on the last assistant message when not processing/streaming
                let shouldShowIcons = isLastAssistant &&
                    !realtimeSession.isProcessing &&
                    realtimeSession.currentAssistantText.isEmpty
                if shouldShowIcons {
                    voiceMessageActions(for: message.text)
                }
            }
        }
    }

    @ViewBuilder
    private func voiceMessageActions(for text: String) -> some View {
        HStack(spacing: 16) {
            // Copy
            Button {
                copyMessageToClipboard(text)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.systemGray))
            }

            // Speak
            Button {
                speakMessage(text)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.systemGray))
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func clarificationOptionsView(_ options: [ClarificationOption]) -> some View {
        VStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    viewModel.selectOption(option)
                } label: {
                    HStack {
                        if let label = option.label {
                            Text(label)
                                .font(.caption.bold())
                                .foregroundColor(.accentColor)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.accentColor.opacity(0.1)))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.name ?? "Option")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)

                            if let brand = option.brand {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if let calories = option.previewCalories {
                            Text("\(Int(calories)) cal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func messageActions(for message: HealthCoachMessage) -> some View {
        HStack(spacing: 16) {
            // Copy
            Button {
                copyMessageToClipboard(message.text)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.systemGray))
            }

            // Speak
            Button {
                speakMessage(message.text)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.systemGray))
            }

            Spacer()
        }
        .padding(.top, 4)
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
        viewModel.send(message: trimmed)
    }

    private func copyMessageToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopyToast = false }
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
                            copyMessageToClipboard(userMessageSheetText)
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

    private func speakMessage(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        speechSynth.speak(utterance)
    }

    // MARK: - Link & Citation Handling

    private func handleLinkTap(_ url: URL) {
        SafeLinkHandler.shared.handleLink(url)
    }

    private func handleCitationTap(_ citation: Citation) {
        guard let urlString = citation.url, let url = URL(string: urlString) else { return }
        SafeLinkHandler.shared.handleLink(url)
    }

    // MARK: - Thinking Indicator (shimmer effect)

    private var thinkingIndicator: some View {
        ShimmerThinkingIndicator(phraseIndex: statusPhraseIndex, phrases: statusPhrases)
    }

    private var statusPhrases: [String] {
        // Simple rotating phrases for all cases
        return ["Thinking...", "Analyzing...", "Shimmering...", "Sparkling...", "Pondering...", "Tinkering..."]
    }

    private var thinkingTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    // MARK: - Input Bar

    private var inputBar: some View {
        let hasUserInput = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(spacing: 0) {
            // Top blur strip for liquid glass fade effect
            ChatTransparentBlurView(removeAllFilters: true)
                .blur(radius: 14)
                .frame(height: 10)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

            // Content card
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    // Placeholder text
                    if inputText.isEmpty {
                        Text("Log or ask anything...")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $inputText)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .tint(Color.accentColor)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(maxHeight: 120)
                        .fixedSize(horizontal: false, vertical: true)
                        .focused($isInputFocused)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = true
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    HStack(spacing: 10) {
                        ChatActionCircleButton(
                            systemName: "plus",
                            action: onPlusTapped,
                            backgroundColor: Color.accentColor,
                            foregroundColor: .white
                        )

                        ChatActionCircleButton(
                            systemName: "barcode.viewfinder",
                            action: onBarcodeTapped
                        )
                    }

                    Spacer()

                    inputBarRightButtons(hasUserInput: hasUserInput)
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
                    .stroke(inputBarBorderColor, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, -12)
            .padding(.bottom, 0)
        }
        .background(
            ChatTransparentBlurView(removeAllFilters: true)
                .blur(radius: 14)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
        )
        .padding(.bottom, 8)
        .onChange(of: speechRecognizer.transcript) { _, newTranscript in
            if !newTranscript.isEmpty {
                inputText = newTranscript
            }
        }
        .onChange(of: isListening) { _, listening in
            if listening {
                speechRecognizer.startRecording()
                pulseScale = 1.2
            } else {
                speechRecognizer.stopRecording()
                pulseScale = 1.0
            }
        }
        .onDisappear {
            if isListening {
                isListening = false
                speechRecognizer.stopRecording()
            }
        }
    }

    @ViewBuilder
    private func inputBarRightButtons(hasUserInput: Bool) -> some View {
        switch realtimeSession.state {
        case .connecting:
            Button {
                HapticFeedback.generate()
                realtimeSession.disconnect()
            } label: {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white })))
                        .scaleEffect(0.8)
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white }))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(UIColor { $0.userInterfaceStyle == .dark ? .white : .black }))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

        case .connected, .muted:
            HStack(spacing: 10) {
                // Mic toggle button
                ChatActionCircleButton(
                    systemName: realtimeSession.state == .muted ? "mic.slash.fill" : "mic.fill",
                    action: {
                        HapticFeedback.generate()
                        realtimeSession.toggleMute()
                    },
                    backgroundColor: realtimeSession.state == .muted ? .red : Color("chaticon"),
                    foregroundColor: realtimeSession.state == .muted ? .white : .primary
                )

                // End button with animated waveform
                Button(action: {
                    HapticFeedback.generate()
                    realtimeSession.disconnect()
                }) {
                    HStack(spacing: 6) {
                        AnimatedWaveform()
                            .frame(width: 20, height: 16)
                        Text("End")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

        default: // .idle, .error
            if isListening {
                Button {
                    HapticFeedback.generate()
                    toggleSpeechRecognition()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .scaleEffect(pulseScale)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    ChatActionCircleButton(
                        systemName: "mic",
                        action: {
                            HapticFeedback.generate()
                            toggleSpeechRecognition()
                        },
                        backgroundColor: Color("chaticon"),
                        foregroundColor: .primary
                    )

                    ChatActionCircleButton(
                        systemName: viewModel.isLoading ? "square.fill" : (hasUserInput ? "arrow.up" : "waveform"),
                        action: {
                            if viewModel.isLoading {
                                // Cancel the current stream
                                HapticFeedback.generate()
                                viewModel.cancelStream()
                                return
                            }
                            if hasUserInput {
                                submitAgentPrompt()
                            } else {
                                // Start realtime voice session
                                HapticFeedback.generate()
                                Task {
                                    try? await realtimeSession.connect()
                                }
                            }
                        },
                        backgroundColor: viewModel.isLoading ? Color.accentColor : (hasUserInput ? Color.accentColor : Color("chaticon")),
                        foregroundColor: viewModel.isLoading ? .white : (hasUserInput ? .white : .primary)
                    )
                }
            }
        }
    }

    private func toggleSpeechRecognition() {
        isListening.toggle()
    }

    private func submitAgentPrompt() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        HapticFeedback.generate()
        viewModel.send(message: trimmed)
        inputText = ""
        isInputFocused = false
    }

    private var inputBarBorderColor: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.20)
            : UIColor.black.withAlphaComponent(0.08)
        })
    }

    // MARK: - Actions

    private func startNewChat() {
        viewModel.clearConversation()
        inputText = ""
    }

    private func shareConversation() {
        let transcript = viewModel.messages
            .filter { $0.sender == .user || $0.sender == .coach }
            .map { msg in
                let role = msg.sender == .user ? "You" : "Coach"
                return "\(role): \(msg.text)"
            }
            .joined(separator: "\n\n")

        guard !transcript.isEmpty else { return }
        shareText = transcript
        showShareSheet = true
    }

    /// Load an existing conversation's messages from the server
    private func loadConversation(_ conversationId: String) async {
        let email = onboardingViewModel.email.isEmpty
            ? (UserDefaults.standard.string(forKey: "userEmail") ?? "")
            : onboardingViewModel.email

        guard !email.isEmpty else {
            print("❌ AgentChatView.loadConversation: No email found")
            return
        }

        do {
            let response = try await NetworkManager().getConversationMessages(
                conversationId: conversationId,
                userEmail: email
            )
            viewModel.loadConversation(id: response.conversationId, messages: response.messages)
            print("✅ AgentChatView: Loaded \(response.messages.count) messages for conversation \(conversationId)")
        } catch {
            print("❌ AgentChatView.loadConversation error: \(error)")
        }
    }

    private func showToast(with message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }

    private func logMealFoods(foods: [Food], items: [MealItem]) {
        // Dismiss sheet immediately for better UX
        showMealSummary = false

        // Determine meal type based on time of day
        let mealType = suggestedMealPeriod(for: Date()).rawValue
        let email = onboardingViewModel.email

        // IMPORTANT: Use a single timestamp for ALL foods in this batch
        // This ensures they group together in the timeline view
        let batchTimestamp = Date()

        // If we have meal items, convert them to foods and log each
        let foodsToLog: [Food]
        if !items.isEmpty {
            foodsToLog = items.map { foodFromMealItem($0) }
        } else {
            foodsToLog = foods
        }

        guard !foodsToLog.isEmpty else {
            showToast(with: "No food to log")
            return
        }

        // Log each food
        let totalFoods = foodsToLog.count
        var loggedCount = 0

        for (index, food) in foodsToLog.enumerated() {
            // Skip coach message for all but last item to avoid multiple AI responses
            let isLastItem = index == totalFoods - 1

            foodManager.logFood(
                email: email,
                food: food,
                meal: mealType,
                servings: 1,
                date: batchTimestamp,
                notes: nil,
                skipCoach: !isLastItem
            ) { [weak dayLogsVM] result in
                DispatchQueue.main.async {
                    loggedCount += 1

                    switch result {
                    case .success:
                        // Refresh logs after all foods are logged
                        if loggedCount == totalFoods {
                            dayLogsVM?.loadLogs(for: batchTimestamp, force: true)
                        }
                    case .failure(let error):
                        print("❌ Failed to log food: \(error)")
                    }
                }
            }
        }

        // Notify callback
        onMealLogged?(foodsToLog)

        // Show success toast
        let foodNames = foodsToLog.prefix(2).map { $0.description }.joined(separator: ", ")
        let suffix = totalFoods > 2 ? " +\(totalFoods - 2) more" : ""
        showToast(with: "Logged \(foodNames)\(suffix)")
    }

    private func addMealFoodsToPlate(_ foods: [Food], mealItems: [MealItem] = []) {
        // Dismiss summary sheet first
        showMealSummary = false

        let mealPeriod = suggestedMealPeriod(for: Date())

        // Use passed mealItems if available (they contain edited serving amounts)
        // Fall back to mealSummaryItems state if callback didn't provide updated items
        let itemsToUse = mealItems.isEmpty ? mealSummaryItems : mealItems

        // If we have meal items, use those (they contain the actual serving amounts/units)
        // Don't also add from foods array - that would cause duplication
        if !itemsToUse.isEmpty {
            for item in itemsToUse {
                let food = foodFromMealItem(item)
                let entry = buildPlateEntry(from: food, mealPeriod: mealPeriod)
                plateViewModel.add(entry)
            }
        } else {
            // Fallback to foods array if no meal items
            for food in foods {
                let entry = buildPlateEntry(from: food, mealPeriod: mealPeriod)
                plateViewModel.add(entry)
            }
        }

        // Delay showing PlateView to allow sheet dismiss animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showPlateView = true
        }
    }

    private func buildPlateEntry(from food: Food, mealPeriod: MealPeriod) -> PlateEntry {
        // Build base macro totals
        let baseMacros = MacroTotals(
            calories: food.calories ?? 0,
            protein: food.protein ?? 0,
            carbs: food.carbs ?? 0,
            fat: food.fat ?? 0
        )

        // Build base nutrient values
        var baseNutrients: [String: RawNutrientValue] = [:]
        for nutrient in food.foodNutrients {
            let key = nutrient.nutrientName.lowercased()
            baseNutrients[key] = RawNutrientValue(value: nutrient.value ?? 0, unit: nutrient.unitName)
        }

        // Determine baseline gram weight
        let baselineGramWeight = food.foodMeasures.first?.gramWeight ?? food.servingSize ?? 100

        return PlateEntry(
            food: food,
            servings: food.numberOfServings ?? 1,
            selectedMeasureId: food.foodMeasures.first?.id,
            availableMeasures: food.foodMeasures,
            baselineGramWeight: baselineGramWeight,
            baseNutrientValues: baseNutrients,
            baseMacroTotals: baseMacros,
            servingDescription: food.servingSizeText ?? "1 serving",
            mealItems: food.mealItems ?? [],
            mealPeriod: mealPeriod,
            mealTime: Date(),
            recipeItems: []
        )
    }

    private func foodFromMealItem(_ item: MealItem) -> Food {
        // Format serving amount - show as integer if whole number, otherwise show decimal
        let servingText: String
        if item.serving.truncatingRemainder(dividingBy: 1) == 0 {
            servingText = "\(Int(item.serving)) \(item.servingUnit ?? "serving")"
        } else {
            servingText = String(format: "%.1f", item.serving) + " \(item.servingUnit ?? "serving")"
        }

        // Create a default measure with the item's serving unit
        let unitLabel = item.servingUnit ?? "serving"
        let defaultMeasure = FoodMeasure(
            disseminationText: unitLabel,
            gramWeight: item.serving,
            id: 0,
            modifier: unitLabel,
            measureUnitName: unitLabel,
            rank: 0
        )

        return Food(
            fdcId: item.id.hashValue,
            description: item.name,
            brandOwner: nil,
            brandName: nil,
            servingSize: 1, // Base serving size is 1 unit
            numberOfServings: item.serving, // Preserve the actual serving amount
            servingSizeUnit: item.servingUnit,
            householdServingFullText: servingText,
            foodNutrients: [
                Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
            ],
            foodMeasures: [defaultMeasure],
            healthAnalysis: nil,
            aiInsight: nil,
            nutritionScore: nil,
            mealItems: item.subitems
        )
    }

    private func suggestedMealPeriod(for date: Date) -> MealPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
        }
    }
}

// MARK: - RealtimeVoiceSessionDelegate

extension AgentChatView: RealtimeVoiceSessionDelegate {
    // MARK: - Food Logging (existing)

    func realtimeSession(_ session: RealtimeVoiceSession, didRequestFoodLookup query: String, isBranded: Bool, brandName: String?, nixItemId: String?, selectionLabel: String?, completion: @escaping (ToolResult) -> Void) {
        // Use FoodManager to look up food
        foodManager.generateFoodWithAI(
            foodDescription: query,
            isBrandedHint: isBranded,
            brandNameHint: brandName
        ) { result in
            switch result {
            case .success(let response):
                switch response.resolvedFoodResult {
                case .success(let food):
                    completion(ToolResult(status: .success, food: food, mealItems: response.mealItems, question: nil, options: nil, error: nil))
                case .failure:
                    if let options = response.options, !options.isEmpty {
                        completion(ToolResult(status: .needsClarification, food: nil, mealItems: nil, question: response.question, options: options, error: nil))
                    } else {
                        completion(ToolResult(status: .error, food: nil, mealItems: nil, question: nil, options: nil, error: "Could not find food"))
                    }
                }
            case .failure(let error):
                completion(ToolResult(status: .error, food: nil, mealItems: nil, question: nil, options: nil, error: error.localizedDescription))
            }
        }
    }

    func realtimeSession(_ session: RealtimeVoiceSession, didResolveFood food: Food, mealItems: [MealItem]?) {
        // Food was logged via voice - update UI
        DispatchQueue.main.async {
            if let items = mealItems, !items.isEmpty {
                self.mealSummaryFoods = [food]
                self.mealSummaryItems = items
                self.showMealSummary = true
            } else {
                self.onFoodReady?(food)
                self.dayLogsVM.loadLogs(for: self.dayLogsVM.selectedDate, force: true)
                self.showToast(with: "Logged \(food.description)")
            }
        }
    }

    // MARK: - Activity Logging (new)

    func realtimeSession(_ session: RealtimeVoiceSession, didRequestActivityLog activityName: String, activityType: String?, durationMinutes: Int, caloriesBurned: Int?, notes: String?, completion: @escaping (VoiceToolResult) -> Void) {
        Task {
            do {
                let result = try await VoiceToolService.shared.logActivity(
                    activityName: activityName,
                    activityType: activityType,
                    durationMinutes: durationMinutes,
                    caloriesBurned: caloriesBurned,
                    notes: notes
                )
                completion(result)

                // If activity was logged successfully, refresh logs
                if result.success {
                    await MainActor.run {
                        self.dayLogsVM.loadLogs(for: self.dayLogsVM.selectedDate, force: true)
                        let calories = caloriesBurned ?? 0
                        self.showToast(with: "Logged \(activityName) - \(calories) cal burned")
                    }
                }
            } catch {
                completion(VoiceToolResult.failure(error: error.localizedDescription))
            }
        }
    }

    // MARK: - Data Queries (new)

    func realtimeSession(_ session: RealtimeVoiceSession, didRequestQuery queryType: VoiceQueryType, args: [String: Any], completion: @escaping (VoiceToolResult) -> Void) {
        Task {
            do {
                let result = try await VoiceToolService.shared.executeQuery(queryType: queryType, args: args)
                completion(result)
            } catch {
                completion(VoiceToolResult.failure(error: error.localizedDescription))
            }
        }
    }

    // MARK: - Goal Updates (new)

    func realtimeSession(_ session: RealtimeVoiceSession, didRequestGoalUpdate goals: [String: Int], completion: @escaping (VoiceToolResult) -> Void) {
        Task {
            do {
                let result = try await VoiceToolService.shared.updateGoals(goals: goals)
                completion(result)

                // If goals were updated successfully, post notification to refresh UI
                if result.success {
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: Notification.Name("NutritionGoalsUpdatedNotification"),
                            object: nil
                        )
                        let goalsList = goals.keys.joined(separator: ", ")
                        self.showToast(with: "Updated \(goalsList) goals")
                    }
                }
            } catch {
                completion(VoiceToolResult.failure(error: error.localizedDescription))
            }
        }
    }
}

// MARK: - Supporting Views

private struct ChatActionCircleButton: View {
    var systemName: String
    var action: () -> Void
    var backgroundColor: Color = Color("chaticon")
    var foregroundColor: Color = .primary

    var body: some View {
        let iconSize: CGFloat = systemName == "square.fill" ? 13 : 16
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(foregroundColor)
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shimmer Thinking Indicator

private struct ShimmerThinkingIndicator: View {
    var phraseIndex: Int
    var phrases: [String]

    @State private var shimmerOffset: CGFloat = -100
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            pulsingCircle
            shimmerText(phrases[min(phraseIndex, phrases.count - 1)])
        }
        .onAppear {
            startShimmerAnimation()
        }
    }

    private var pulsingCircle: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let normalized = (sin(t * 2 * .pi / 1.5) + 1) / 2
            Circle()
                .fill(Color.primary)
                .frame(width: 6, height: 6)
                .scaleEffect(0.85 + 0.25 * normalized)
                .opacity(0.6 + 0.4 * normalized)
        }
    }

    private func shimmerText(_ text: String) -> some View {
        let shimmerColor = colorScheme == .dark ? Color.white.opacity(0.3) : Color.white.opacity(0.6)

        return Text(text)
            .font(.system(size: 15))
            .foregroundColor(.primary)
            .overlay(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: shimmerColor, location: 0.5),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: .init(x: -0.3 + shimmerOffset / 100, y: 0),
                    endPoint: .init(x: 0.3 + shimmerOffset / 100, y: 0)
                )
                .blendMode(.overlay)
            )
            .mask(
                Text(text)
                    .font(.system(size: 15))
            )
    }

    private func startShimmerAnimation() {
        guard !reduceMotion else { return }
        shimmerOffset = -100
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 100
        }
    }
}

// MARK: - Transparent Blur View for Liquid Glass Effect

private struct ChatTransparentBlurView: UIViewRepresentable {
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
