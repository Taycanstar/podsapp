//
//  TimelineEventRow.swift
//  pods
//
//  Created by Dimi Nunez on 1/20/26.
//


import SwiftUI

// MARK: - TimelineEventRow

struct TimelineEventRow: View {
    let event: TimelineEvent
    let selectedDate: Date
    var coachMessage: CoachMessage? = nil
    var onCoachEditTap: ((CoachMessage) -> Void)? = nil
    var onCoachCopyTap: (() -> Void)? = nil
    var canDelete: Bool = false
    var canToggleSave: Bool = false
    var onDelete: ((CombinedLog) -> Void)? = nil
    var onSave: ((CombinedLog) -> Void)? = nil
    var onUnsave: ((CombinedLog) -> Void)? = nil
    var isLogSaved: ((CombinedLog) -> Bool)? = nil
    var onLogTap: ((CombinedLog) -> Void)? = nil

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
            HStack(alignment: .center, spacing: 12) {
                TimelineConnector(iconName: event.iconName)
                    .frame(height: TimelineConnector.iconSize)

                Text(labelText)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            if event.isGroupedFood {
                // Grouped food event - show full cards for each item (no summary card)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(event.logs, id: \.id) { log in
                        HStack(alignment: .top, spacing: 12) {
                            TimelineConnectorSpacer()
                            fullFoodCard(for: log)
                        }
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    TimelineConnectorSpacer()
                    swipeableCard
                }
            }

            if let coachMessage {
                HStack(alignment: .top, spacing: 12) {
                    TimelineConnectorSpacer()
                    TimelineCoachMessageText(
                        message: coachMessage,
                        onEditTap: onCoachEditTap,
                        onCopyTap: onCoachCopyTap
                    )
                        .padding(.bottom, 16)
                }
            }
        }
    }

    private var labelText: String {
        let calendar = Calendar.current
        if calendar.isDate(event.date, inSameDayAs: selectedDate) {
            return Self.timeFormatter.string(from: event.date)
        }
        return Self.dateFormatter.string(from: event.date)
    }

    @ViewBuilder
    private func fullFoodCard(for log: CombinedLog) -> some View {
        // Create a proper TimelineEvent for this individual log to use the full card
        let individualEvent = makeTimelineEvent(from: log)
        let cardView = TimelineEventCard(event: individualEvent)
            .contentShape(Rectangle())
            .onTapGesture {
                if log.type == .food || log.type == .meal || log.type == .recipe {
                    onLogTap?(log)
                }
            }
        if canDelete || canToggleSave {
            cardView
                .modifier(SwipeableCardModifier(
                    canDelete: canDelete,
                    canSave: canToggleSave,
                    isSaved: isLogSaved?(log) ?? false,
                    onDelete: { onDelete?(log) },
                    onSave: { onSave?(log) },
                    onUnsave: { onUnsave?(log) }
                ))
        } else {
            cardView
        }
    }

    private func makeTimelineEvent(from log: CombinedLog) -> TimelineEvent {
        let title: String
        let calories: Int?
        var protein: Int?
        var carbs: Int?
        var fat: Int?

        // Use CombinedLog's displayCalories which handles all types consistently
        calories = safeRoundedInt(log.displayCalories)

        switch log.type {
        case .food:
            title = log.food?.displayName ?? log.message
            protein = safeRoundedInt(log.food?.protein)
            carbs = safeRoundedInt(log.food?.carbs)
            fat = safeRoundedInt(log.food?.fat)
        case .meal:
            title = log.meal?.title ?? log.message
            protein = safeRoundedInt(log.meal?.protein)
            carbs = safeRoundedInt(log.meal?.carbs)
            fat = safeRoundedInt(log.meal?.fat)
        case .recipe:
            title = log.recipe?.title ?? log.message
            protein = safeRoundedInt(log.recipe?.protein)
            carbs = safeRoundedInt(log.recipe?.carbs)
            fat = safeRoundedInt(log.recipe?.fat)
        default:
            title = log.message
        }

        let details = TimelineEvent.Details(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )

        return TimelineEvent(date: event.date, type: .food, title: title, details: details, log: log)
    }

    private func safeRoundedInt(_ value: Double?, minimum: Double = 0) -> Int? {
        guard let value, value.isFinite, value >= minimum else { return nil }
        return Int(value.rounded())
    }

    @ViewBuilder
    private var swipeableCard: some View {
        if let log = event.log, (canDelete || canToggleSave) {
            TimelineEventCard(event: event)
                .contentShape(Rectangle())
                .onTapGesture {
                    if log.type == .food || log.type == .meal || log.type == .recipe {
                        onLogTap?(log)
                    }
                }
                .modifier(SwipeableCardModifier(
                    canDelete: canDelete,
                    canSave: canToggleSave,
                    isSaved: isLogSaved?(log) ?? false,
                    onDelete: { onDelete?(log) },
                    onSave: { onSave?(log) },
                    onUnsave: { onUnsave?(log) }
                ))
        } else if let log = event.log {
            TimelineEventCard(event: event)
                .contentShape(Rectangle())
                .onTapGesture {
                    if log.type == .food || log.type == .meal || log.type == .recipe {
                        onLogTap?(log)
                    }
                }
        } else {
            TimelineEventCard(event: event)
        }
    }
}

// MARK: - TimelineEventCard

struct TimelineEventCard: View {
    let event: TimelineEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(event.title)
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

    // Using AnyView to cap type depth and prevent SwiftUI type explosion
    private var detailView: some View {
        switch event.type {
        case .food:
            AnyView(FoodTimelineDetails(details: event.details))
        case .workout:
            AnyView(WorkoutTimelineDetails(details: event.details))
        case .cardio:
            AnyView(CardioTimelineDetails(details: event.details))
        case .water:
            if let amount = event.details.amountText {
                AnyView(
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color.cyan)
                        Text(amount)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                )
            } else {
                AnyView(EmptyView())
            }
        case .wake:
            AnyView(WakeTimelineDetails(details: event.details))
        }
    }
}

// MARK: - TimelineCoachMessageText

struct TimelineCoachMessageText: View {
    let message: CoachMessage
    var onEditTap: ((CoachMessage) -> Void)?
    var onCopyTap: (() -> Void)?

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

            if streamingComplete {
                HStack(spacing: 16) {
                    Button {
                        UIPasteboard.general.string = fullText
                        onCopyTap?()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onEditTap?(message)
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
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
        .onChange(of: message.logId) { _, _ in
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

// MARK: - SwipeableCardModifier

struct SwipeableCardModifier: ViewModifier {
    let canDelete: Bool
    let canSave: Bool
    let isSaved: Bool
    let onDelete: () -> Void
    let onSave: () -> Void
    let onUnsave: () -> Void

    @State private var offset: CGFloat = 0
    @GestureState private var isDragging = false

    private let buttonWidth: CGFloat = 70
    private let swipeThreshold: CGFloat = 50

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background(alignment: .trailing) {
                // Delete button (trailing - revealed when swiping left)
                if canDelete && offset < 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { offset = 0 }
                        onDelete()
                    }) {
                        ZStack {
                            Color.red
                            Image(systemName: "trash.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: -offset)
                    }
                }
            }
            .background(alignment: .leading) {
                // Save button (leading - revealed when swiping right)
                if canSave && offset > 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { offset = 0 }
                        if isSaved { onUnsave() } else { onSave() }
                    }) {
                        ZStack {
                            (isSaved ? Color(.systemGray) : Color.accentColor)
                            Image(systemName: isSaved ? "bookmark.slash.fill" : "bookmark.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: offset)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        // Only respond to horizontal swipes (horizontal > vertical)
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)
                        guard horizontal > vertical else { return }

                        let translation = value.translation.width
                        if canDelete && translation < 0 {
                            offset = max(translation, -buttonWidth)
                        } else if canSave && translation > 0 {
                            offset = min(translation, buttonWidth)
                        }
                    }
                    .onEnded { value in
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            // Only snap to button if was a horizontal swipe
                            if horizontal > vertical {
                                if value.translation.width < -swipeThreshold && canDelete {
                                    offset = -buttonWidth
                                } else if value.translation.width > swipeThreshold && canSave {
                                    offset = buttonWidth
                                } else {
                                    offset = 0
                                }
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
    }
}
