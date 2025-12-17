import SwiftUI
import UIKit
import AVFoundation

struct AgentChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var onboardingViewModel: OnboardingViewModel

    // New streaming ViewModel
    @StateObject private var viewModel = HealthCoachChatViewModel()

    @State private var inputText: String = ""
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
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

    // Initial message binding to send on appear (for AgentTabBar integration)
    // Using Binding so SwiftUI reads current value when view appears, not when closure is captured
    @Binding private var initialMessage: String?

    init(
        initialMessage: Binding<String?> = .constant(nil),
        onPlusTapped: @escaping () -> Void = {},
        onBarcodeTapped: @escaping () -> Void = {}
    ) {
        self._initialMessage = initialMessage
        self.onPlusTapped = onPlusTapped
        self.onBarcodeTapped = onBarcodeTapped
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Chat scroll view fills the space
                chatScrollView
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Dismiss keyboard when tapping outside input
                        isInputFocused = false
                    }

                // Floating input bar at the bottom
                inputBar

                // "Start talking" overlay when connected and chat is empty
                if realtimeSession.state == .connected && viewModel.messages.isEmpty && realtimeSession.messages.isEmpty {
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

            // Send initial message if provided (from AgentTabBar)
            print("🤖 AgentChatView.onAppear - initialMessage: \(initialMessage ?? "nil")")
            if let message = initialMessage, !message.isEmpty {
                print("🤖 AgentChatView: Sending initial message: \(message)")
                viewModel.send(message: message)
                // Clear it to avoid re-sending on re-appear
                initialMessage = nil
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
                    onAddToPlate: { foods, _ in
                        addMealFoodsToPlate(foods)
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
                            voiceMessageRow(voiceMessage)
                                .id(voiceMessage.id)
                        }

                        // Thinking indicator
                        if viewModel.isLoading && viewModel.streamingMessageId == nil {
                            thinkingIndicator
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
                    .padding(.horizontal)
                    .padding(.top)
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.streamingText) { _, _ in
                    scrollToBottom(proxy: proxy)
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
        if let lastId = viewModel.messages.last?.id {
            withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
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
                    .padding(12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }

        case .coach:
            VStack(alignment: .leading, spacing: 8) {
                Text(message.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // REMOVED: Tappable clarification cards - agent should ask text-based questions instead
                // if let options = message.options, !options.isEmpty {
                //     clarificationOptionsView(options)
                // }

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

    @ViewBuilder
    private func voiceMessageRow(_ message: RealtimeMessage) -> some View {
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
        }
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
                UIPasteboard.general.string = message.text
                withAnimation { showCopyToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showCopyToast = false }
                }
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

    private func speakMessage(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        speechSynth.speak(utterance)
    }

    // MARK: - Thinking Indicator (shimmer effect)

    private var thinkingIndicator: some View {
        ShimmerThinkingIndicator(phraseIndex: statusPhraseIndex, phrases: statusPhrases)
    }

    private var statusPhrases: [String] {
        // Simple rotating phrases for all cases
        return ["Thinking...", "Analyzing...", "Processing..."]
    }

    private var thinkingTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    // MARK: - Input Bar

    private var inputBar: some View {
        let hasUserInput = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(alignment: .leading, spacing: 12) {
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
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                Button {
                    HapticFeedback.generate()
                    realtimeSession.disconnect()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white }))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(UIColor { $0.userInterfaceStyle == .dark ? .white : .black }))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

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
                        systemName: hasUserInput ? "arrow.up" : "waveform",
                        action: {
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
                        backgroundColor: hasUserInput ? Color.accentColor : Color("chaticon"),
                        foregroundColor: hasUserInput ? .white : .primary
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

    private func addMealFoodsToPlate(_ foods: [Food]) {
        // Dismiss summary sheet first
        showMealSummary = false

        let mealPeriod = suggestedMealPeriod(for: Date())

        // If we have meal items, use those (they contain the actual serving amounts/units)
        // Don't also add from foods array - that would cause duplication
        if !mealSummaryItems.isEmpty {
            for item in mealSummaryItems {
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
            mealTime: Date()
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
            foodMeasures: [],
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
}

// MARK: - Supporting Views

private struct ChatActionCircleButton: View {
    var systemName: String
    var action: () -> Void
    var backgroundColor: Color = Color("chaticon")
    var foregroundColor: Color = .primary

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
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
