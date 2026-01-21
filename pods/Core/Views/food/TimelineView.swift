//
//  TimelineView.swift
//  pods
//
//  Created by Dimi Nunez on 12/14/25.
//

import SwiftUI
import AVFoundation

struct AppTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var proFeatureGate: ProFeatureGate

    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false
    @State private var showAgentChat = false
    @State private var isAtBottom = true
    @State private var pendingCoachMessageText: String?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var didTriggerInitialFetch = false

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    private let isoFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .autoupdatingCurrent
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private var dateSubtitle: String {
        let calendar = Calendar.current
        let monthDayFormatter = DateFormatter()
        monthDayFormatter.dateFormat = "MMMM d"
        let monthDay = monthDayFormatter.string(from: selectedDate)

        if calendar.isDateInToday(selectedDate) {
            return "Today, \(monthDay)"
        } else {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            let weekday = weekdayFormatter.string(from: selectedDate)
            return "\(weekday), \(monthDay)"
        }
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                if dayLogsVM.isLoading && filteredLogs.isEmpty {
                    Spacer()
                    ProgressView("Loading timeline...")
                        .padding()
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ZStack(alignment: .bottom) {
                            ScrollView {
                                VStack(spacing: 0) {
                                    // Date subtitle above the timeline section
                                    Text(dateSubtitle)
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                        .padding(.bottom, 16)

                                    ZStack(alignment: .leading) {
                                        TimelineSpineOverlay()

                                        VStack(spacing: 20) {
                                            TimelineEmptyQuickActionsRow(
                                                onAddActivity: { /* TODO: Wire up */ },
                                                onScanMeal: { /* TODO: Wire up */ }
                                            )

                                            if groupedLogs.isEmpty {
                                                Text("No entries yet")
                                                    .font(.system(size: 15))
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, 20)
                                            } else {
                                                ForEach(Array(groupedLogs.enumerated()), id: \.element.id) { groupIndex, group in
                                                    TimelineLogGroupRow(
                                                        group: group,
                                                        selectedDate: selectedDate,
                                                        coachMessage: coachMessageForGroup(group),
                                                        isThinking: isThinkingForGroup(group, at: groupIndex),
                                                        onCoachEditTap: { coachMessage in
                                                            openAgentChatWithCoachMessage(coachMessage)
                                                        },
                                                        onCopyTap: {
                                                            showToast(message: "Message copied")
                                                        },
                                                        onFeedbackSubmitted: {
                                                            showToast(message: "Thank you for your feedback!")
                                                        }
                                                    )
                                                }
                                            }

                                            // Anchor for scrolling to bottom
                                            Color.clear
                                                .frame(height: 1)
                                                .id("bottomAnchor")
                                                .onAppear { isAtBottom = true }
                                                .onDisappear { isAtBottom = false }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                }
                            }
                            .refreshable {
                                await MainActor.run {
                                    dayLogsVM.loadLogs(for: selectedDate, force: true)
                                }
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
            }
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastMessage)
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showDatePicker.toggle() }) {
                    Image(systemName: "calendar")
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                VStack(spacing: 0) {
                    // Calendar picker
                    DatePicker(
                        "Select a date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    Spacer()

                    // Bottom bar with Today button
                    VStack(spacing: 0) {
                        Divider()

                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedDate = Date()
                                }
                            } label: {
                                Text("Today")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.accentColor)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color("containerbg"))
                    }
                }
                .navigationTitle("Choose Date")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showDatePicker = false }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showDatePicker = false }
                    }
                }
            }
        }
        .onAppear {
            selectedDate = dayLogsVM.selectedDate
        }
        .onChange(of: selectedDate) { _, newValue in
            dayLogsVM.loadLogs(for: newValue, force: true)
        }
        .fullScreenCover(isPresented: $showAgentChat, onDismiss: {
            pendingCoachMessageText = nil
        }) {
            AgentChatView(initialCoachMessage: $pendingCoachMessageText)
                .environmentObject(dayLogsVM)
        }
        .onChange(of: foodManager.showLogSuccess) { _, newValue in
            if newValue, let item = foodManager.lastLoggedItem {
                showToast(message: "\(item.name) logged")
            }
        }
    }

    /// Opens AgentChatView with the coach message seeded as the first assistant message
    private func openAgentChatWithCoachMessage(_ coachMessage: CoachMessage) {
        // Seed the coach message as an assistant reply, not a user message.
        pendingCoachMessageText = coachMessage.fullText
        showAgentChat = true
    }

    private func showToast(message: String) {
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

    private var filteredLogs: [CombinedLog] {
        let calendar = Calendar.current
        return dayLogsVM.logs
            .filter { calendar.isDate(logDate(for: $0), inSameDayAs: selectedDate) }
            .sorted { logDate(for: $0) < logDate(for: $1) }  // Oldest first, newest at bottom
    }

    /// Groups logs by time (rounded to minute) - food logs at same time share one connector
    private var groupedLogs: [TimelineLogGroup] {
        let calendar = Calendar.current
        var groups: [Date: [CombinedLog]] = [:]

        for log in filteredLogs {
            let date = logDate(for: log)
            // Round to minute for grouping (ignore seconds)
            let roundedDate = calendar.date(
                from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            ) ?? date
            groups[roundedDate, default: []].append(log)
        }

        // Convert to array of groups, sorted by date
        return groups.map { TimelineLogGroup(date: $0.key, logs: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private func logDate(for log: CombinedLog) -> Date {
        if let scheduledAt = log.scheduledAt {
            return scheduledAt
        }
        if let raw = log.logDate, let parsed = isoFormatter.date(from: raw) {
            return parsed
        }
        return selectedDate
    }

    /// Returns the coach message if this group contains the last food or recipe log and it matches
    private func coachMessageForGroup(_ group: TimelineLogGroup) -> CoachMessage? {
        guard let coachMessage = foodManager.lastCoachMessage else { return nil }

        // Check if any log in the group matches the coach message
        for log in group.logs {
            // Match food logs
            if log.type == .food,
               let foodLogId = coachMessage.foodLogId,
               foodLogId == log.foodLogId {
                return coachMessage
            }
            // Match recipe logs
            if log.type == .recipe,
               let recipeLogId = coachMessage.recipeLogId,
               recipeLogId == log.recipeLogId {
                return coachMessage
            }
        }
        return nil
    }

    /// Returns true if the thinking indicator should show for this group
    private func isThinkingForGroup(_ group: TimelineLogGroup, at groupIndex: Int) -> Bool {
        let isLastGroup = groupIndex == groupedLogs.count - 1
        guard isLastGroup else { return false }

        // Check if any log in the group is a food or recipe log
        let hasFoodOrRecipeLog = group.logs.contains { $0.type == .food || $0.type == .recipe }
        guard hasFoodOrRecipeLog else { return false }

        let hasCoachMessage = coachMessageForGroup(group) != nil
        return foodManager.isAwaitingCoachMessage && !hasCoachMessage
    }
}

// MARK: - Timeline Log Group

private struct TimelineLogGroup: Identifiable {
    let date: Date
    let logs: [CombinedLog]

    var id: String {
        // Use date only for stable identification
        // This prevents view recreation when optimistic logs are replaced with server logs
        "\(date.timeIntervalSince1970)"
    }

    /// The icon to show for this group (uses first log's type)
    var iconName: String {
        guard let firstLog = logs.first else { return "circle.fill" }
        switch firstLog.type {
        case .food, .meal, .recipe:
            return "fork.knife"
        case .activity:
            return "figure.run"
        case .workout:
            return "dumbbell.fill"
        }
    }
}

// MARK: - Timeline Spine Overlay (copied from NewHomeView)

// private struct TimelineSpineOverlay: View {
//     @Environment(\.colorScheme) private var colorScheme

//     var body: some View {
//         GeometryReader { geometry in
//             let color = colorScheme == .dark ? Color(.systemGray3) : Color(.systemGray4)
//             ZStack(alignment: .center) {
//                 Rectangle()
//                     .fill(color)
//                     .frame(width: 2, height: geometry.size.height)
//                     .position(x: TimelineConnector.iconSize / 2, y: geometry.size.height / 2)

//                 Circle()
//                     .fill(color)
//                     .frame(width: 8, height: 8)
//                     .position(x: TimelineConnector.iconSize / 2, y: geometry.size.height - 4)
//             }
//         }
//         .allowsHitTesting(false)
//     }
// }

// MARK: - Timeline Connector (copied from NewHomeView)

// private struct TimelineConnector: View {
//     @Environment(\.colorScheme) private var colorScheme
//     let iconName: String
//     var overrideColor: Color? = nil

//     static let iconSize: CGFloat = 34

//     var body: some View {
//         let circleColor = overrideColor ?? (colorScheme == .dark ? Color(.systemGray2) : Color.black.opacity(0.9))

//         return ZStack {
//             Circle()
//                 .fill(circleColor)
//                 .frame(width: Self.iconSize, height: Self.iconSize)
//             Image(systemName: iconName)
//                 .font(.system(size: 12, weight: .semibold))
//                 .foregroundColor(.white)
//         }
//         .frame(width: Self.iconSize, height: Self.iconSize)
//     }
// }

// MARK: - Timeline Connector Spacer (copied from NewHomeView)

// private struct TimelineConnectorSpacer: View {
//     var body: some View {
//         Color.clear
//             .frame(width: TimelineConnector.iconSize)
//     }
// }

// MARK: - Quick Actions Row (copied from NewHomeView)

// private struct TimelineEmptyQuickActionsRow: View {
//     var onAddActivity: (() -> Void)?
//     var onScanMeal: (() -> Void)?

//     private let foregroundColor = Color("text")

//     @Environment(\.colorScheme) private var colorScheme

//     var body: some View {
//         HStack(alignment: .center, spacing: 12) {
//             TimelineConnector(
//                 iconName: "plus",
//                 overrideColor: plusColor
//             )

//             HStack(spacing: 12) {
//                 quickActionChip(
//                     title: "Add Activity",
//                     systemImage: "flame.fill",
//                     action: onAddActivity
//                 )

//                 quickActionChip(
//                     title: "Scan Meal",
//                     systemImage: "fork.knife",
//                     action: onScanMeal
//                 )
//             }
//         }
//         .frame(maxWidth: .infinity, alignment: .leading)
//     }

//     private func quickActionChip(title: String, systemImage: String, action: (() -> Void)?) -> some View {
//         Button {
//             action?()
//         } label: {
//             HStack(spacing: 8) {
//                 Image(systemName: systemImage)
//                     .font(.system(size: 13, weight: .regular))
//                 Text(title)
//                     .font(.system(size: 13, weight: .regular))
//             }
//             .foregroundColor(foregroundColor)
//             .padding(.horizontal, 16)
//             .padding(.vertical, 8)
//             .background(Color("background"))
//             .clipShape(Capsule())
//         }
//         .buttonStyle(.plain)
//         .disabled(action == nil)
//         .opacity(action == nil ? 0.5 : 1)
//     }

//     private var plusColor: Color {
//         if colorScheme == .dark {
//             return Color(.systemGray2)
//         }
//         return Color.black.opacity(0.9)
//     }
// }

// MARK: - Timeline Log Group Row (handles single or multiple logs at same time)

private struct TimelineLogGroupRow: View {
    let group: TimelineLogGroup
    let selectedDate: Date
    var coachMessage: CoachMessage? = nil
    var isThinking: Bool = false
    var onCoachEditTap: ((CoachMessage) -> Void)?
    var onCopyTap: (() -> Void)?
    var onFeedbackSubmitted: (() -> Void)?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private let labelSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: labelSpacing) {
            // Top: Single connector + time label for the group
            HStack(alignment: .center, spacing: 12) {
                TimelineConnector(iconName: group.iconName)
                    .frame(height: TimelineConnector.iconSize)

                Text(labelText)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            // Cards for all logs in the group (sharing the same connector)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(group.logs, id: \.id) { log in
                    HStack(alignment: .top, spacing: 12) {
                        TimelineConnectorSpacer()
                        // Only food, meal, and recipe logs navigate to LogDetails
                        if log.type == .food || log.type == .meal || log.type == .recipe {
                            NavigationLink(destination: LogDetails(log: log)) {
                                TimelineLogCard(log: log)
                            }
                            .buttonStyle(.plain)
                        } else {
                            TimelineLogCard(log: log)
                        }
                    }
                }

                // Show thinking indicator or coach message after all cards
                if isThinking {
                    HStack(alignment: .top, spacing: 12) {
                        TimelineConnectorSpacer()
                        CoachThinkingIndicator()
                            .padding(.bottom, 16)
                    }
                } else if let coach = coachMessage {
                    HStack(alignment: .top, spacing: 12) {
                        TimelineConnectorSpacer()
                        CoachMessageText(message: coach, onEditTap: onCoachEditTap, onCopyTap: onCopyTap, onFeedbackSubmitted: onFeedbackSubmitted)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
    }

    private var labelText: String {
        let calendar = Calendar.current
        if calendar.isDate(group.date, inSameDayAs: selectedDate) {
            return Self.timeFormatter.string(from: group.date)
        }
        return Self.dateFormatter.string(from: group.date)
    }
}

// MARK: - Timeline Log Card (matching TimelineEventCard)

private struct TimelineLogCard: View {
    let log: CombinedLog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            detailView
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("sheetcard"))
        )
    }

    private var title: String {
        switch log.type {
        case .food:
            return log.food?.displayName ?? log.message
        case .meal:
            return log.meal?.title ?? log.message
        case .recipe:
            return log.recipe?.title ?? log.message
        case .activity:
            return log.activity?.displayName ?? log.message
        case .workout:
            return log.workout?.title ?? log.message
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch log.type {
        case .food, .meal, .recipe:
            TLFoodLogDetails(log: log)
        case .workout:
            TLWorkoutLogDetails(log: log)
        case .activity:
            TLActivityLogDetails(log: log)
        }
    }
}

// MARK: - Food Log Details (matching FoodTimelineDetails)

private struct TLFoodLogDetails: View {
    let log: CombinedLog

    var body: some View {
        HStack(spacing: 12) {
            // Calories with flame icon
            label(icon: "flame.fill", text: "\(caloriesValue) cal", color: Color("brightOrange"))

            // Macros: P F C - always show all three
            macroLabel(prefix: "P", value: proteinValue)
            macroLabel(prefix: "F", value: fatValue)
            macroLabel(prefix: "C", value: carbsValue)
        }
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }

    private var caloriesValue: Int {
        Int(log.displayCalories.rounded())
    }

    private var proteinValue: Int {
        // For food logs, multiply per-serving value by numberOfServings
        if let food = log.food, let protein: Double = food.protein {
            let servings: Double = food.numberOfServings > 0 ? food.numberOfServings : 1
            return Int((protein * servings).rounded())
        }
        // For meal/recipe logs, use value directly
        if let protein: Double = log.meal?.protein ?? log.recipe?.protein {
            return Int(protein.rounded())
        }
        return 0
    }

    private var fatValue: Int {
        // For food logs, multiply per-serving value by numberOfServings
        if let food = log.food, let fat: Double = food.fat {
            let servings: Double = food.numberOfServings > 0 ? food.numberOfServings : 1
            return Int((fat * servings).rounded())
        }
        // For meal/recipe logs, use value directly
        if let fat: Double = log.meal?.fat ?? log.recipe?.fat {
            return Int(fat.rounded())
        }
        return 0
    }

    private var carbsValue: Int {
        // For food logs, multiply per-serving value by numberOfServings
        if let food = log.food, let carbs: Double = food.carbs {
            let servings: Double = food.numberOfServings > 0 ? food.numberOfServings : 1
            return Int((carbs * servings).rounded())
        }
        // For meal/recipe logs, use value directly
        if let carbs: Double = log.meal?.carbs ?? log.recipe?.carbs {
            return Int(carbs.rounded())
        }
        return 0
    }

    private func label(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
            Text(text)
        }
    }

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }
}

// MARK: - Workout Log Details (matching WorkoutTimelineDetails)

private struct TLWorkoutLogDetails: View {
    let log: CombinedLog

    var body: some View {
        HStack(spacing: 12) {
            if let calories = caloriesValue {
                detail(icon: "flame.fill", text: "\(calories) cal")
            }
            if let duration = durationValue {
                detail(icon: "clock", text: "\(duration) min")
            }
            if let exercises = exercisesCount {
                detail(icon: "list.bullet", text: "\(exercises) exercises")
            }
        }
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }

    private var caloriesValue: Int? {
        guard log.calories > 0 else { return nil }
        return Int(log.calories.rounded())
    }

    private var durationValue: Int? {
        if let minutes = log.workout?.durationMinutes, minutes > 0 {
            return minutes
        }
        if let seconds = log.workout?.durationSeconds, seconds > 0 {
            return seconds / 60
        }
        return nil
    }

    private var exercisesCount: Int? {
        guard let count = log.workout?.exercisesCount, count > 0 else { return nil }
        return count
    }

    private func detail(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(text)
        }
    }
}

// MARK: - Activity Log Details (matching CardioTimelineDetails)

private struct TLActivityLogDetails: View {
    let log: CombinedLog

    var body: some View {
        HStack(spacing: 12) {
            if let calories = caloriesValue {
                detail(icon: "flame.fill", text: "\(calories) cal")
            }
            if let duration = durationText {
                detail(icon: "clock", text: duration)
            }
            if let distance = distanceText {
                detail(icon: "mappin.and.ellipse", text: distance)
            }
        }
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }

    private var caloriesValue: Int? {
        guard let cal = log.activity?.totalEnergyBurned, cal > 0 else { return nil }
        return Int(cal.rounded())
    }

    private var durationText: String? {
        log.activity?.formattedDuration
    }

    private var distanceText: String? {
        log.activity?.formattedDistance
    }

    private func detail(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(text)
        }
    }
}

// MARK: - Coach Message Text (streaming text effect for AI coaching)

private class SpeechCoordinator: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

private struct CoachMessageText: View {
    let message: CoachMessage
    var onEditTap: ((CoachMessage) -> Void)?
    var onCopyTap: (() -> Void)?
    var onFeedbackSubmitted: (() -> Void)?

    @State private var displayedText: String = ""
    @State private var isAnimating: Bool = false
    @State private var streamingComplete: Bool = false

    private var fullText: String {
        message.fullText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayedText)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Action icons - show after streaming completes
            if streamingComplete {
                HStack(spacing: 16) {
                    // Copy button
                    Button {
                        UIPasteboard.general.string = fullText
                        onCopyTap?()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(.systemGray))
                    }
                    .buttonStyle(.plain)

                    // Thumbs up/down for coach messages with intervention_id
                    if let interventionId = message.interventionId {
                        ThumbsFeedbackInlineView(
                            interventionId: interventionId,
                            initialRating: nil,
                            onFeedbackSubmitted: onFeedbackSubmitted
                        )
                        .id("thumbs-\(interventionId)")
                    }

                    // Edit/Chat button
                    Button {
                        onEditTap?(message)
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(.systemGray))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.top, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            startStreamingAnimation()
        }
        .onChange(of: message.foodLogId) { _, _ in
            // Reset and restart animation if message changes
            displayedText = ""
            streamingComplete = false
            startStreamingAnimation()
        }
    }

    private func startStreamingAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        streamingComplete = false
        displayedText = ""

        let characters = Array(fullText)
        var currentIndex = 0

        // Stream characters at ~30ms intervals for smooth typing effect
        Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { timer in
            if currentIndex < characters.count {
                displayedText.append(characters[currentIndex])
                currentIndex += 1
            } else {
                timer.invalidate()
                isAnimating = false
                withAnimation(.easeIn(duration: 0.3)) {
                    streamingComplete = true
                }
            }
        }
    }
}

// MARK: - Coach Thinking Indicator (shimmer + rotating text while generating)

private struct CoachThinkingIndicator: View {
    @State private var phraseIndex: Int = 0
    @State private var shimmerOffset: CGFloat = -100
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let phrases = ["Analyzing...", "Thinking...", "Finishing up..."]
    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            pulsingCircle
            shimmerText(phrases[phraseIndex])
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                phraseIndex = (phraseIndex + 1) % phrases.count
            }
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
