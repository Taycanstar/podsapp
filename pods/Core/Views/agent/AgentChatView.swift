import SwiftUI
import UIKit

struct AgentChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel
    @ObservedObject var viewModel: AgentChatViewModel
    @State private var inputText: String = ""
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var thinkingMessageIndex = 0
    @State private var shimmerPhase: CGFloat = 0
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    @State private var mealSelections: [UUID: String] = [:]
    private let mealTypeOptions = ["Breakfast", "Lunch", "Dinner", "Snack"]

    init(viewModel: AgentChatViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pendingActionsSection
                Divider()
                ZStack(alignment: .bottomTrailing) {
                    chatScrollView
                    scrollToBottomButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
                inputBar
            }
            .navigationTitle("Humuli")
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
            if viewModel.isLoading {
                thinkingMessageIndex = (thinkingMessageIndex + 1) % thinkingPhrases.count
            } else {
                thinkingMessageIndex = 0
            }
        }
        .onAppear {
            viewModel.bootstrapIfNeeded()
            syncMealSelections(with: viewModel.messages)
        }
        .onChange(of: viewModel.messages) { _, newMessages in
            syncMealSelections(with: newMessages)
        }
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastMessage)
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 40)
            }
        }
    }

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        if let preview = message.pendingLog, message.sender == .pendingLog {
                            pendingLogBubble(messageID: message.id, preview: preview)
                                .id(message.id)
                        } else {
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    if viewModel.isLoading {
                        thinkingIndicator
                    }
                }
                .padding()
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 10) {
            thinkingPulseCircle
            shimmeringThinkingText
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func messageRow(_ message: AgentChatMessage) -> some View {
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
        case .agent:
            Text(message.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        case .system:
            Text(message.text)
                .font(.footnote)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity, alignment: .center)
        case .pendingLog:
            EmptyView()
        }
    }

    @ViewBuilder
    private func pendingLogBubble(messageID: UUID, preview: AgentPendingLog) -> some View {
        let fallbackMeal = mealTypeOptions.first ?? "Lunch"
        let mealBinding = Binding<String>(
            get: {
                mealSelections[messageID] ?? preview.mealType ?? fallbackMeal
            },
            set: { mealSelections[messageID] = $0 }
        )

        return VStack(alignment: .leading, spacing: 20) {
            headerSection(messageID: messageID, preview: preview)

            if preview.logType == .food {
                macroRow(preview: preview)

                Picker("Meal", selection: mealBinding) {
                    ForEach(mealTypeOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                activitySummary(preview: preview)
            }

            Button {
                dismissPendingPreview(messageID: messageID)
            } label: {
                Text("Not now")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color("iosfit"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func headerSection(messageID: UUID, preview: AgentPendingLog) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(preview.title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                if let line = brandServingLine(for: preview) {
                    Text(line)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            logCTA(messageID: messageID, preview: preview)
        }
    }

    @ViewBuilder
    private func logCTA(messageID: UUID, preview: AgentPendingLog) -> some View {
        Button {
            confirmPendingLogAction(messageID: messageID, preview: preview)
        } label: {
            HStack(spacing: 6) {
                if viewModel.confirmingMessageID == messageID {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(.systemBackground))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Log")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundColor(Color(.systemBackground))
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(viewModel.confirmingMessageID == messageID ? 0.4 : 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.confirmingMessageID == messageID)
    }

    private func brandServingLine(for preview: AgentPendingLog) -> String? {
        let serving = preview.servingText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return serving.isEmpty ? nil : serving
    }

    @ViewBuilder
    private func macroRow(preview: AgentPendingLog) -> some View {
        HStack(alignment: .center, spacing: 24) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color("brightOrange"))
                HStack(alignment: .bottom, spacing: 2) {
                    Text(formattedMacro(preview.calories, suffix: ""))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("cal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 24) {
                macroStat(label: "Protein", value: preview.protein, suffix: "g", tint: .blue)
                macroStat(label: "Carbs", value: preview.carbs, suffix: "g", tint: Color("darkYellow"))
                macroStat(label: "Fat", value: preview.fat, suffix: "g", tint: .pink)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func activitySummary(preview: AgentPendingLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(preview.durationMinutes ?? 0) min", systemImage: "clock")
                Spacer()
                Label("\(Int(preview.calories ?? 0)) kcal", systemImage: "flame")
            }
            .font(.subheadline.weight(.semibold))

            if let type = preview.activityType, !type.isEmpty {
                Label(type, systemImage: "figure.run")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.primary)
    }

    private func macroStat(label: String, value: Double?, suffix: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundColor(tint)
            Text(formattedMacro(value, suffix: suffix))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pendingActionsSection: some View {
        Group {
            if viewModel.pendingActions.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pending Agent Actions")
                        .font(.headline)
                    ForEach(viewModel.pendingActions) { action in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(action.actionType.capitalized)
                                .font(.subheadline)
                                .bold()
                            if let rationale = action.rationale {
                                Text(rationale)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Button("Decline") {
                                    viewModel.decide(action: action, approved: false)
                                }
                                .buttonStyle(.bordered)
                                Button("Approve") {
                                    viewModel.decide(action: action, approved: true)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
    }

    private func formattedMacro(_ value: Double?, suffix: String) -> String {
        guard let value else { return "--" }
        let formatted = value.rounded(.toNearestOrEven)
        let base: String
        if formatted.truncatingRemainder(dividingBy: 1) == 0 {
            base = "\(Int(formatted))"
        } else {
            base = String(format: "%.1f", value)
        }
        return suffix.isEmpty ? base : "\(base) \(suffix)"
    }

    private func dismissPendingPreview(messageID: UUID) {
        viewModel.dismissPendingLog(messageId: messageID)
        mealSelections[messageID] = nil
    }

    private func confirmPendingLogAction(messageID: UUID, preview: AgentPendingLog) {
        let fallbackMeal = mealTypeOptions.first ?? "Lunch"
        let mealType = mealSelections[messageID] ?? preview.mealType ?? fallbackMeal
        viewModel.confirmPendingLog(messageId: messageID, mealType: mealType) { result in
            switch result {
            case .success(let commitResult):
                mealSelections[messageID] = nil
                if let combined = buildCombinedLog(from: commitResult, fallbackMealType: mealType) {
                    var optimisticLog = combined
                    optimisticLog.isOptimistic = true
                    if optimisticLog.scheduledAt == nil {
                        optimisticLog.scheduledAt = dayLogsVM.selectedDate
                    }
                    dayLogsVM.addPending(optimisticLog)
                    dayLogsVM.loadLogs(for: dayLogsVM.selectedDate, force: true)
                } else {
                    dayLogsVM.loadLogs(for: dayLogsVM.selectedDate, force: true)
                }
                let acknowledgement = commitResult.message ?? "Logged \(commitResult.entryType.capitalized)"
                viewModel.appendSystemMessage(acknowledgement)
                showToast(with: acknowledgement)
            case .failure(let error):
                showToast(with: "Failed to log: \(error.localizedDescription)")
            }
        }
    }

    private func syncMealSelections(with messages: [AgentChatMessage]) {
        let pendingMessages = messages.filter { $0.isPendingLog }
        let pendingIDs = Set(pendingMessages.map(\.id))

        // Remove entries for dismissed previews
        mealSelections.keys
            .filter { !pendingIDs.contains($0) }
            .forEach { mealSelections.removeValue(forKey: $0) }

        // Ensure every pending preview has a selection
        for message in pendingMessages {
            if mealSelections[message.id] == nil {
                let fallback = mealTypeOptions.first ?? "Lunch"
                mealSelections[message.id] = message.pendingLog?.mealType ?? fallback
            }
        }
    }

    private func buildCombinedLog(from result: AgentLogCommitResult, fallbackMealType: String) -> CombinedLog? {
        guard let entryType = result.payload["entry_type"] as? String else { return nil }
        switch entryType {
        case "food":
            return buildFoodCombinedLog(result.payload, mealType: fallbackMealType)
        case "activity":
            return buildActivityCombinedLog(result.payload)
        default:
            return nil
        }
    }

    private func buildFoodCombinedLog(_ payload: [String: Any], mealType: String) -> CombinedLog? {
        guard
            let foodLogId = payload["food_log_id"] as? Int,
            let foodData = payload["food"] as? [String: Any]
        else { return nil }

        let displayName = foodData["displayName"] as? String ?? "Food Log"
        let caloriesValue = payload["calories"] as? Int ?? Int(foodData["calories"] as? Double ?? 0)
        let message = payload["message"] as? String ?? "Logged \(displayName)"
        let resolvedMealType = payload["meal_type"] as? String ?? mealType

        var healthAnalysisData: HealthAnalysis? = nil
        if let healthDict = foodData["health_analysis"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: healthDict),
           let decoded = try? JSONDecoder().decode(HealthAnalysis.self, from: data) {
            healthAnalysisData = decoded
        }

        var foodNutrients: [Nutrient]? = nil
        if let nutrientsArray = foodData["foodNutrients"] as? [[String: Any]] {
            foodNutrients = nutrientsArray.compactMap { dict in
                guard
                    let name = dict["nutrientName"] as? String,
                    let value = dict["value"] as? Double,
                    let unit = dict["unitName"] as? String
                else { return nil }
                return Nutrient(nutrientName: name, value: value, unitName: unit)
            }
        }

        let loggedFoodItem = LoggedFoodItem(
            foodLogId: foodLogId,
            fdcId: foodData["fdcId"] as? Int ?? foodLogId,
            displayName: displayName,
            calories: foodData["calories"] as? Double ?? Double(caloriesValue),
            servingSizeText: foodData["servingSizeText"] as? String ?? "1 serving",
            numberOfServings: foodData["numberOfServings"] as? Double ?? 1.0,
            brandText: foodData["brandText"] as? String,
            protein: foodData["protein"] as? Double,
            carbs: foodData["carbs"] as? Double,
            fat: foodData["fat"] as? Double,
            healthAnalysis: healthAnalysisData,
            foodNutrients: foodNutrients
        )

        return CombinedLog(
            type: .food,
            status: payload["status"] as? String ?? "success",
            calories: Double(caloriesValue),
            message: message,
            foodLogId: foodLogId,
            food: loggedFoodItem,
            mealType: resolvedMealType,
            mealLogId: nil,
            meal: nil,
            mealTime: nil,
            scheduledAt: dayLogsVM.selectedDate,
            recipeLogId: nil,
            recipe: nil,
            servingsConsumed: nil,
            activityId: nil,
            activity: nil,
            workoutLogId: nil,
            workout: nil,
            logDate: formatDateForLog(dayLogsVM.selectedDate),
            dayOfWeek: formatDayOfWeek(dayLogsVM.selectedDate),
            isOptimistic: true
        )
    }

    private func buildActivityCombinedLog(_ payload: [String: Any]) -> CombinedLog? {
        guard
            let activityLogId = payload["activity_log_id"] as? Int,
            let activityName = payload["activity_name"] as? String,
            let caloriesBurned = payload["calories_burned"] as? Int,
            let durationMinutes = payload["duration_minutes"] as? Int,
            let message = payload["message"] as? String
        else { return nil }

        let activitySummary = ActivitySummary(
            id: String(activityLogId),
            workoutActivityType: formatActivityType(payload["activity_type"] as? String ?? "Other"),
            displayName: formatActivityName(activityName),
            duration: Double(durationMinutes * 60),
            totalEnergyBurned: Double(caloriesBurned),
            totalDistance: nil,
            startDate: Date(),
            endDate: Date()
        )

        let scheduledDate = dayLogsVM.selectedDate

        return CombinedLog(
            type: .activity,
            status: payload["status"] as? String ?? "success",
            calories: Double(caloriesBurned),
            message: message,
            foodLogId: nil,
            food: nil,
            mealType: nil,
            mealLogId: nil,
            meal: nil,
            mealTime: nil,
            scheduledAt: scheduledDate,
            recipeLogId: nil,
            recipe: nil,
            servingsConsumed: nil,
            activityId: String(activityLogId),
            activity: activitySummary,
            workoutLogId: nil,
            workout: nil,
            logDate: formatDateForLog(scheduledDate),
            dayOfWeek: formatDayOfWeek(scheduledDate),
            isOptimistic: true
        )
    }

    private func formatDateForLog(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func formatActivityName(_ name: String) -> String {
        switch name.lowercased() {
        case "running":
            return "Running"
        case "walking":
            return "Walking"
        case "cycling", "biking":
            return "Cycling"
        case "swimming":
            return "Swimming"
        case "hiking":
            return "Hiking"
        case "yoga":
            return "Yoga"
        case "weightlifting", "weight lifting", "strength training":
            return "Strength Training"
        case "cardio":
            return "Cardio Workout"
        case "tennis":
            return "Tennis"
        case "basketball":
            return "Basketball"
        case "soccer", "football":
            return "Soccer"
        case "rowing":
            return "Rowing"
        case "elliptical":
            return "Elliptical"
        case "stairs", "stair climbing":
            return "Stair Climbing"
        default:
            return name.prefix(1).uppercased() + name.dropFirst().lowercased()
        }
    }

    private func formatActivityType(_ type: String) -> String {
        switch type.lowercased() {
        case "cardio":
            return "Running"
        case "strength":
            return "StrengthTraining"
        case "sports":
            return "Other"
        default:
            return formatActivityName(type)
        }
    }

    private var inputBar: some View {
        VStack {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Ask or log anything…", text: $inputText, axis: .vertical)
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
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.send(message: trimmed)
        inputText = ""
        isInputFocused = false
    }

    private func startNewChat() {
        viewModel.resetConversation()
        viewModel.refreshContext()
        inputText = ""
    }

    private func shareConversation() {
        let transcript = viewModel.transcriptText()
        guard !transcript.isEmpty else { return }
        UIPasteboard.general.string = transcript
        showToast(with: "Conversation copied")
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

    private var scrollToBottomButton: some View {
        Group {
            if !viewModel.messages.isEmpty {
                Button {
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            scrollProxy?.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                        .background(
                            Circle()
                                .fill(.thinMaterial)
                                .frame(width: 44, height: 44)
                        )
                }
            }
        }
    }

    private var thinkingPhrases: [String] {
        [
            "Humuli is thinking…",
            "Checking your recent trends…",
            "Balancing recovery and strain…",
            "Reviewing your sleep + HRV…"
        ]
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

    private var shimmeringThinkingText: some View {
        let text = thinkingPhrases[thinkingMessageIndex]
        return Text(text)
            .font(.footnote)
            .foregroundColor(.secondary)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, Color.white.opacity(0.6), .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: shimmerPhase)
                .mask(
                    Text(text)
                        .font(.footnote)
                )
            )
            .onAppear {
                shimmerPhase = -60
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    shimmerPhase = 60
                }
            }
    }

    private var thinkingTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
}
