//
//  TimelineView.swift
//  pods
//
//  Created by Dimi Nunez on 12/14/25.
//

import SwiftUI

struct AppTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @EnvironmentObject var foodManager: FoodManager

    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false
    @State private var scrollToBottom = false

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
                        ScrollView {
                            ZStack(alignment: .leading) {
                                TimelineSpineOverlay()

                                VStack(spacing: 20) {
                                    TimelineEmptyQuickActionsRow(
                                        onAddActivity: { /* TODO: Wire up */ },
                                        onScanMeal: { /* TODO: Wire up */ }
                                    )

                                    if filteredLogs.isEmpty {
                                        Text("No entries yet")
                                            .font(.system(size: 15))
                                            .foregroundColor(.secondary)
                                            .padding(.top, 20)
                                    } else {
                                        ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { index, log in
                                            TimelineLogRow(
                                                log: log,
                                                selectedDate: selectedDate,
                                                coachMessage: coachMessageForLog(log, at: index),
                                                isThinking: isThinkingForLog(log, at: index)
                                            )
                                        }
                                    }

                                    // Anchor for scrolling to bottom
                                    Color.clear
                                        .frame(height: 1)
                                        .id("bottomAnchor")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        .onAppear {
                            // Scroll to bottom to show most recent log
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.large)
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
            dayLogsVM.loadLogs(for: selectedDate, force: true)
        }
        .onChange(of: selectedDate) { _, newValue in
            dayLogsVM.loadLogs(for: newValue, force: true)
        }
    }

    private var filteredLogs: [CombinedLog] {
        let calendar = Calendar.current
        return dayLogsVM.logs
            .filter { calendar.isDate(logDate(for: $0), inSameDayAs: selectedDate) }
            .sorted { logDate(for: $0) < logDate(for: $1) }  // Oldest first, newest at bottom
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

    /// Returns the coach message if this is the last (newest) food log and it matches
    private func coachMessageForLog(_ log: CombinedLog, at index: Int) -> CoachMessage? {
        // Only show for the last food log in the list (newest, since sorted oldest-first)
        let isLastLog = index == filteredLogs.count - 1
        guard isLastLog,
              log.type == .food,
              let coachMessage = foodManager.lastCoachMessage,
              coachMessage.foodLogId == log.foodLogId else {
            return nil
        }
        return coachMessage
    }

    /// Returns true if the thinking indicator should show for this log
    /// Shows when: it's the last food log, coach message is being generated, and no coach message yet
    private func isThinkingForLog(_ log: CombinedLog, at index: Int) -> Bool {
        let isLastLog = index == filteredLogs.count - 1
        guard isLastLog, log.type == .food else { return false }

        // Show thinking if scanning is active and we don't have a coach message for this log yet
        let isScanningActive = foodManager.foodScanningState.isActive
        let hasCoachMessage = coachMessageForLog(log, at: index) != nil

        return isScanningActive && !hasCoachMessage
    }
}

// MARK: - Timeline Spine Overlay (copied from NewHomeView)

private struct TimelineSpineOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let color = colorScheme == .dark ? Color(.systemGray3) : Color(.systemGray4)
            ZStack(alignment: .center) {
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: geometry.size.height)
                    .position(x: TimelineConnector.iconSize / 2, y: geometry.size.height / 2)

                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .position(x: TimelineConnector.iconSize / 2, y: geometry.size.height - 4)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Timeline Connector (copied from NewHomeView)

private struct TimelineConnector: View {
    @Environment(\.colorScheme) private var colorScheme
    let iconName: String
    var overrideColor: Color? = nil

    static let iconSize: CGFloat = 34

    var body: some View {
        let circleColor = overrideColor ?? (colorScheme == .dark ? Color(.systemGray2) : Color.black.opacity(0.9))

        return ZStack {
            Circle()
                .fill(circleColor)
                .frame(width: Self.iconSize, height: Self.iconSize)
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: Self.iconSize, height: Self.iconSize)
    }
}

// MARK: - Timeline Connector Spacer (copied from NewHomeView)

private struct TimelineConnectorSpacer: View {
    var body: some View {
        Color.clear
            .frame(width: TimelineConnector.iconSize)
    }
}

// MARK: - Quick Actions Row (copied from NewHomeView)

private struct TimelineEmptyQuickActionsRow: View {
    var onAddActivity: (() -> Void)?
    var onScanMeal: (() -> Void)?

    private let foregroundColor = Color("text")

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            TimelineConnector(
                iconName: "plus",
                overrideColor: plusColor
            )

            HStack(spacing: 12) {
                quickActionChip(
                    title: "Add Activity",
                    systemImage: "flame.fill",
                    action: onAddActivity
                )

                quickActionChip(
                    title: "Scan Meal",
                    systemImage: "fork.knife",
                    action: onScanMeal
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quickActionChip(title: String, systemImage: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .regular))
                Text(title)
                    .font(.system(size: 13, weight: .regular))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color("background"))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .opacity(action == nil ? 0.5 : 1)
    }

    private var plusColor: Color {
        if colorScheme == .dark {
            return Color(.systemGray2)
        }
        return Color.black.opacity(0.9)
    }
}

// MARK: - Timeline Log Row (matching TimelineEventRow structure)

private struct TimelineLogRow: View {
    let log: CombinedLog
    let selectedDate: Date
    var coachMessage: CoachMessage? = nil
    var isThinking: Bool = false  // Show thinking indicator while coach message is generating

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

    private static let isoFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .autoupdatingCurrent
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private let labelSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: labelSpacing) {
            // Top: Connector + time label
            HStack(alignment: .center, spacing: 12) {
                TimelineConnector(iconName: iconName(for: log.type))
                    .frame(height: TimelineConnector.iconSize)

                Text(labelText)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            // Bottom: Spacer + Card
            HStack(alignment: .top, spacing: 12) {
                TimelineConnectorSpacer()
                VStack(alignment: .leading, spacing: 8) {
                    TimelineLogCard(log: log)

                    // Show thinking indicator while coach is generating, otherwise show coach message
                    if isThinking {
                        CoachThinkingIndicator()
                    } else if let coach = coachMessage {
                        CoachMessageText(message: coach)
                    }
                }
            }
        }
    }

    private var labelText: String {
        let calendar = Calendar.current
        let logDateValue = logDate(for: log)
        if calendar.isDate(logDateValue, inSameDayAs: selectedDate) {
            return Self.timeFormatter.string(from: logDateValue)
        }
        return Self.dateFormatter.string(from: logDateValue)
    }

    private func logDate(for log: CombinedLog) -> Date {
        if let scheduledAt = log.scheduledAt {
            return scheduledAt
        }
        if let raw = log.logDate, let parsed = Self.isoFormatter.date(from: raw) {
            return parsed
        }
        return selectedDate
    }

    private func iconName(for type: LogType) -> String {
        switch type {
        case .food: return "fork.knife"
        case .meal: return "takeoutbag.and.cup.and.straw"
        case .recipe: return "book.closed"
        case .activity: return "figure.run"
        case .workout: return "dumbbell"
        }
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

// MARK: - Coach Message Text (simple text display for AI coaching)

private struct CoachMessageText: View {
    let message: CoachMessage

    var body: some View {
        Text("\(message.acknowledgement) \(message.nextAction)")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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
                .fill(Color.secondary)
                .frame(width: 6, height: 6)
                .scaleEffect(0.85 + 0.25 * normalized)
                .opacity(0.6 + 0.4 * normalized)
        }
    }

    private func shimmerText(_ text: String) -> some View {
        let shimmerColor = colorScheme == .dark ? Color.white.opacity(0.3) : Color.white.opacity(0.6)

        return Text(text)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
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
                    .font(.system(size: 13))
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
