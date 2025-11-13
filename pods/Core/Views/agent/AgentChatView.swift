import SwiftUI
import UIKit

struct AgentChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel
    @ObservedObject var viewModel: AgentChatViewModel
    @State private var inputText: String = ""
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    @State private var mealSelections: [UUID: String] = [:]
    @State private var expandedDetails: Set<UUID> = []
    @State private var statusPhraseIndex = 0
    @State private var shimmerPhase: CGFloat = 0
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
            guard viewModel.isLoading else { return }
            let phrases = thinkingPhrases(for: viewModel.currentStatusHint)
            statusPhraseIndex = (statusPhraseIndex + 1) % phrases.count
        }
        .onAppear {
            viewModel.bootstrapIfNeeded()
            syncMealSelections(with: viewModel.messages)
        }
        .onChange(of: viewModel.messages) { _, newMessages in
            syncMealSelections(with: newMessages)
        }
        .onChange(of: viewModel.currentStatusHint) { _, _ in
            statusPhraseIndex = 0
        }
        .onChange(of: viewModel.isLoading) { _, loading in
            if !loading { statusPhraseIndex = 0 }
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
            Text(thinkingStatusText)
                .font(.footnote)
                .foregroundColor(.secondary)
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

            HStack(spacing: 12) {
                CapsuleButton(title: "Not now") {
                    dismissPendingPreview(messageID: messageID)
                }

                let isExpanded = expandedDetails.contains(messageID)
                CapsuleButton(title: isExpanded ? "Hide Details" : "Show Details") {
                    toggleDetails(for: messageID)
                }
            }
            .padding(.top, 4)

            if expandedDetails.contains(messageID) {
                pendingLogDetails(preview: preview)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color("iosfit"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
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

    private func CapsuleButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }

    private func toggleDetails(for id: UUID) {
        if expandedDetails.contains(id) {
            expandedDetails.remove(id)
        } else {
            expandedDetails.insert(id)
        }
    }

    private func pendingLogDetails(preview: AgentPendingLog) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if preview.logType == .food {
                micronutrientGrid(nutrition: preview.nutritionDetails)
                healthSection(health: preview.healthAnalysis)
            } else {
                activityDetailSection(preview: preview)
            }
        }
        .padding(.top, 12)
    }

    private func micronutrientGrid(nutrition: AgentPendingNutrition?) -> some View {
        Group {
            if let nutrition {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nutrients")
                        .font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        microTile(label: "Sugar", value: nutrition.sugars, unit: "g")
                        microTile(label: "Fiber", value: nutrition.fiber, unit: "g")
                        microTile(label: "Sodium", value: nutrition.sodium, unit: "mg")
                        microTile(label: "Sat Fat", value: nutrition.saturatedFat, unit: "g")
                        microTile(label: "Potassium", value: nutrition.potassium, unit: "mg")
                        microTile(label: "Cholesterol", value: nutrition.cholesterol, unit: "mg")
                    }
                    if !nutrition.additionalNutrients.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(nutrition.additionalNutrients, id: \.label) { item in
                                HStack {
                                    Text(item.label)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formattedValue(item.value, suffix: item.unit ?? ""))
                                        .font(.caption.weight(.semibold))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func healthSection(health: HealthAnalysis?) -> some View {
        Group {
            if let health {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Health Score")
                        .font(.headline)
                    HStack(spacing: 12) {
                        Text("\(health.score)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(14)
                            .background(
                                Circle()
                                    .fill(Color(hex: health.color ?? "#CCCCCC").opacity(0.2))
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            let positiveTitles = health.positives.map { $0.title }
                            if !positiveTitles.isEmpty {
                                Text("Positives: \(positiveTitles.joined(separator: ", "))")
                                    .font(.caption)
                            }
                            let negativeTitles = health.negatives.map { $0.title }
                            if !negativeTitles.isEmpty {
                                Text("Watch out: \(negativeTitles.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func activityDetailSection(preview: AgentPendingLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Details")
                .font(.headline)
            detailRow(label: "Type", value: preview.activityType ?? "Other")
            if let duration = preview.durationMinutes {
                detailRow(label: "Duration", value: "\(duration) min")
            }
            detailRow(label: "Scheduled", value: formatDateForLog(dayLogsVM.selectedDate))
            if let note = preview.description, !note.isEmpty {
                detailRow(label: "Notes", value: note)
            }
        }
    }

    @ViewBuilder
    private func microTile(label: String, value: Double?, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(formattedValue(value, suffix: unit))
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private func formattedValue(_ value: Double?, suffix: String) -> String {
        guard let value else { return "--" }
        let rounded = value.rounded(.toNearestOrEven)
        let base: String
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            base = "\(Int(rounded))"
        } else {
            base = String(format: "%.1f", value)
        }
        return suffix.isEmpty ? base : "\(base) \(suffix)"
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var thinkingStatusText: String {
        let phrases = thinkingPhrases(for: viewModel.currentStatusHint)
        let index = min(statusPhraseIndex, phrases.count - 1)
        return phrases[index]
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

    private func thinkingPhrases(for hint: AgentResponseHint) -> [String] {
        switch hint {
        case .logFood:
            return [
                "Analyzing your log…",
                "Balancing macros…",
                "Reviewing recent meals…",
                "Estimating nutrition…"
            ]
        case .logActivity:
            return [
                "Reviewing your activity…",
                "Estimating calories burned…",
                "Checking intensity…",
                "Logging your session…"
            ]
        case .chat:
            fallthrough
        default:
            return [
                "Preparing your answer…",
                "Reviewing your trends…",
                "Thinking through your plan…",
                "Summarizing insights…"
            ]
        }
    }

    private var thinkingTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
}
