//
//  TimelineSectionView.swift
//  pods
//
//  Created by Dimi Nunez on 1/20/26.
//


import SwiftUI

// MARK: - TimelineSectionView

struct TimelineSectionView: View {
    let events: [TimelineEvent]
    let selectedDate: Date
    var onShowAll: (() -> Void)? = nil
    var onAddActivity: (() -> Void)? = nil
    var onScanMeal: (() -> Void)? = nil
    var onCoachEditTap: ((CoachMessage) -> Void)? = nil
    var onCoachCopyTap: (() -> Void)? = nil
    var onDeleteLog: ((CombinedLog) -> Void)? = nil
    var onSaveLog: ((CombinedLog) -> Void)? = nil
    var onUnsaveLog: ((CombinedLog) -> Void)? = nil
    var isLogSaved: ((CombinedLog) -> Bool)? = nil
    var onLogTap: ((CombinedLog) -> Void)? = nil
    @EnvironmentObject private var foodManager: FoodManager

    var body: some View {
        let rowSpacing: CGFloat = 20

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Timeline")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if let onShowAll, !events.isEmpty {
                    Button(action: onShowAll) {
                        Text("Show All")
                            .font(.system(size: 15))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            ZStack(alignment: .leading) {
                TimelineSpineOverlay()

                VStack(spacing: rowSpacing) {
                    TimelineEmptyQuickActionsRow(
                        onAddActivity: onAddActivity,
                        onScanMeal: onScanMeal
                    )

                    if events.isEmpty {
                        Text("No entries yet")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .padding(.top, rowSpacing)
                    } else {
                        ForEach(Array(events.enumerated()), id: \.element.id) { _, event in
                            TimelineEventRow(
                                event: event,
                                selectedDate: selectedDate,
                                coachMessage: coachMessageForEvent(event),
                                onCoachEditTap: onCoachEditTap,
                                onCoachCopyTap: onCoachCopyTap,
                                canDelete: event.log.map { canDelete(log: $0) } ?? false,
                                canToggleSave: event.log.map { canSave(log: $0) } ?? false,
                                onDelete: onDeleteLog,
                                onSave: onSaveLog,
                                onUnsave: onUnsaveLog,
                                isLogSaved: isLogSaved,
                                onLogTap: onLogTap
                            )
                        }
                    }
                }
            }
        }
    }
}

extension TimelineSectionView {
    func canDelete(log: CombinedLog) -> Bool {
        switch log.type {
        case .workout:
            return false
        case .activity:
            if let activityId = log.activityId, activityId.count > 10 && activityId.contains("-") {
                return false
            }
            return true
        default:
            return true
        }
    }

    func canSave(log: CombinedLog) -> Bool {
        switch log.type {
        case .food, .meal:
            return true
        default:
            return false
        }
    }

    func coachMessageForEvent(_ event: TimelineEvent) -> CoachMessage? {
        guard let coachMessage = foodManager.lastCoachMessage else { return nil }

        for log in event.logs {
            if log.type == .food,
               let foodLogId = coachMessage.foodLogId,
               foodLogId == log.foodLogId {
                return coachMessage
            }
            if log.type == .recipe,
               let recipeLogId = coachMessage.recipeLogId,
               recipeLogId == log.recipeLogId {
                return coachMessage
            }
        }
        return nil
    }
}

// MARK: - TimelineSpineOverlay

struct TimelineSpineOverlay: View {
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

// MARK: - TimelineConnector

struct TimelineConnector: View {
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

// MARK: - TimelineConnectorSpacer

struct TimelineConnectorSpacer: View {
    var body: some View {
        Color.clear
            .frame(width: TimelineConnector.iconSize)
    }
}

// MARK: - TimelineEmptyQuickActionsRow

struct TimelineEmptyQuickActionsRow: View {
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

// MARK: - TimelineFullSheetView

struct TimelineFullSheetView: View {
    let events: [TimelineEvent]
    let selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                TimelineSectionView(events: events, selectedDate: selectedDate)
                    .padding(.top, 16)
                    .padding(.horizontal)
            }
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - TimelineSectionWrapper

/// Wrapper view that breaks the closure capture chain from NewHomeView.
/// By using Bindings and EnvironmentObjects instead of closures that capture `self`,
/// we prevent Swift from needing to resolve type metadata for NewHomeView's 250+ properties.
/// All DayLogsViewModel properties are accessed here via EnvironmentObject, not passed from NewHomeView.
struct TimelineSectionWrapper: View {
    @Binding var showAddActivitySheet: Bool
    @Binding var selectedLogForDetails: CombinedLog?
    @Binding var showLogDetails: Bool
    @Binding var showCoachCopyToast: Bool
    @Binding var pendingCoachMessageText: String?
    @Binding var showAgentChat: Bool
    let onBarcodeTapped: () -> Void

    @EnvironmentObject private var foodMgr: FoodManager
    @EnvironmentObject private var vm: DayLogsViewModel

    var body: some View {
        TimelineSectionView(
            events: vm.timelineEvents,
            selectedDate: vm.selectedDate,
            onShowAll: nil,
            onAddActivity: { showAddActivitySheet = true },
            onScanMeal: onBarcodeTapped,
            onCoachEditTap: { coachMessage in
                pendingCoachMessageText = coachMessage.fullText
                showAgentChat = true
            },
            onCoachCopyTap: {
                withAnimation {
                    showCoachCopyToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showCoachCopyToast = false
                    }
                }
            },
            onDeleteLog: { log in
                deleteLogItem(log: log)
            },
            onSaveLog: { log in
                saveMealAction(log: log)
            },
            onUnsaveLog: { log in
                unsaveMealAction(log: log)
            },
            isLogSaved: { log in
                switch log.type {
                case .food:
                    guard let id = log.foodLogId else { return false }
                    return foodMgr.isLogSaved(foodLogId: id)
                case .meal:
                    guard let id = log.mealLogId else { return false }
                    return foodMgr.isLogSaved(mealLogId: id)
                default:
                    return false
                }
            },
            onLogTap: { log in
                selectedLogForDetails = log
                showLogDetails = true
            }
        )
    }

    private func saveMealAction(log: CombinedLog) {
        switch log.type {
        case .food:
            guard let foodLogId = log.foodLogId else { return }
            HapticFeedback.generateLigth()
            foodMgr.saveMeal(
                itemType: .foodLog,
                itemId: foodLogId,
                customName: nil,
                notes: nil
            ) { _ in }

        case .meal:
            guard let mealLogId = log.mealLogId else { return }
            HapticFeedback.generateLigth()
            foodMgr.saveMeal(
                itemType: .mealLog,
                itemId: mealLogId,
                customName: nil,
                notes: nil
            ) { _ in }

        case .recipe, .activity, .workout:
            break
        }
    }

    private func unsaveMealAction(log: CombinedLog) {
        switch log.type {
        case .food:
            guard let foodLogId = log.foodLogId else { return }
            HapticFeedback.generateLigth()
            foodMgr.unsaveByLogId(foodLogId: foodLogId) { _ in }

        case .meal:
            guard let mealLogId = log.mealLogId else { return }
            HapticFeedback.generateLigth()
            foodMgr.unsaveByLogId(mealLogId: mealLogId) { _ in }

        case .recipe, .activity, .workout:
            break
        }
    }

    private func deleteLogItem(log: CombinedLog) {
        switch log.type {
        case .activity:
            if let activityId = log.activityId, activityId.count > 10 && activityId.contains("-") {
                return
            }
            fallthrough
        case .food, .meal, .recipe:
            HapticFeedback.generate()
            Task { await vm.removeLog(log) }
        case .workout:
            break
        }
    }
}
