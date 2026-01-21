//
//  QuickActivityInput.swift
//  pods
//
//  Created by Dimi Nunez on 1/20/26.
//


import SwiftUI

// MARK: - QuickActivityInput

struct QuickActivityInput {
    let activityName: String
    let startTime: Date
    let durationMinutes: Int
    let intensity: ActivityIntensity
}

// MARK: - ActivityIntensity

enum ActivityIntensity: String, CaseIterable, Identifiable {
    case easy
    case moderate
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .hard: return "Hard"
        }
    }
}

// MARK: - AddActivityView

struct AddActivityView: View {
    let recentActivities: [String]
    let onSubmit: (QuickActivityInput, @escaping (Result<Void, Error>) -> Void) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedActivity: String = ""
    @State private var startTime: Date
    @State private var durationMinutes: Int = 30
    @State private var intensity: ActivityIntensity = .moderate
    @State private var showMoreActivities = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showStartPicker = false
    @State private var showDurationPicker = false

    private let durationHourOptions = Array(0...12)
    private let durationMinuteOptions = Array(0..<60)

    init(recentActivities: [String], defaultStartDate: Date, onSubmit: @escaping (QuickActivityInput, @escaping (Result<Void, Error>) -> Void) -> Void) {
        self.recentActivities = recentActivities
        self.onSubmit = onSubmit
        _startTime = State(initialValue: defaultStartDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    recentActivitiesSection
                    moreActivitiesButton
                    detailsSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .background(backgroundColor)
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Add Activity")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .tint(Color.accentColor)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isSubmitDisabled ? Color.secondary : Color.accentColor)
                        }
                    }
                    .disabled(isSubmitDisabled)
                }
            }
            .sheet(isPresented: $showMoreActivities) {
                ActivitySearchSheet { activity in
                    selectedActivity = activity.trimmed()
                }
            }
        }
        .background(backgroundColor.ignoresSafeArea())
    }

    private var recentActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activities")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ForEach(displayedRecentActivities, id: \.self) { activity in
                    Button {
                        selectedActivity = activity.trimmed()
                    } label: {
                        Text(activity)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedActivity == activity ? Color.white : textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(selectedActivity == activity ? Color.accentColor : sheetCardColor)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var moreActivitiesButton: some View {
        Button {
            showMoreActivities = true
        } label: {
            HStack {
                Text("More activities")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(secondaryTextColor)
            }
            .foregroundColor(textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(sheetCardColor)
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add details")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showStartPicker.toggle()
                        if showStartPicker { showDurationPicker = false }
                    }
                } label: {
                    detailRowContent(title: "Start time", value: startTimeDisplay)
                }
                .buttonStyle(.plain)

                if showStartPicker {
                    startPickerInline
                }

                Divider()
                    .padding(.leading, 20)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showDurationPicker.toggle()
                        if showDurationPicker { showStartPicker = false }
                    }
                } label: {
                    detailRowContent(title: "Duration", value: durationDisplay)
                }
                .buttonStyle(.plain)

                if showDurationPicker {
                    durationPickerInline
                }

                Divider()
                    .padding(.leading, 20)

                Menu {
                    ForEach(ActivityIntensity.allCases) { level in
                        Button(level.displayName) { intensity = level }
                    }
                } label: {
                    detailRowContent(title: "Intensity", value: intensity.displayName)
                }
            }
            .background(sheetCardColor)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func detailRowContent(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(secondaryTextColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private var startPickerInline: some View {
        DatePicker(
            "",
            selection: $startTime,
            in: Date.distantPast...Date(),
            displayedComponents: [.date, .hourAndMinute]
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .transition(.opacity)
    }

    private var durationPickerInline: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: durationHoursBinding) {
                ForEach(durationHourOptions, id: \.self) { value in
                    Text("\(value) hr").tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Minutes", selection: durationMinutesComponentBinding) {
                ForEach(durationMinuteOptions, id: \.self) { value in
                    Text(String(format: "%02d min", value)).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .transition(.opacity)
    }

    private func submit() {
        guard isSubmitDisabled == false else { return }
        let trimmed = selectedActivity.trimmed()
        guard trimmed.isEmpty == false else {
            errorMessage = "Select an activity"
            return
        }
        isSubmitting = true
        errorMessage = nil
        let input = QuickActivityInput(
            activityName: trimmed,
            startTime: startTime,
            durationMinutes: durationMinutes,
            intensity: intensity
        )
        onSubmit(input) { result in
            switch result {
            case .success:
                isSubmitting = false
                dismiss()
            case .failure(let error):
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private var sheetCardColor: Color { Color("sheetcard") }

    private var textPrimary: Color {
        colorScheme == .dark ? Color.white : Color("text")
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.secondary
    }

    private var backgroundColor: Color {
        Color("sheetbg")
    }

    private var startTimeDisplay: String {
        let time = Self.timeFormatter.string(from: startTime)
        let calendar = Calendar.current
        if calendar.isDateInToday(startTime) {
            return "Today at \(time)"
        }
        if calendar.isDateInYesterday(startTime) {
            return "Yesterday at \(time)"
        }
        return "\(Self.dayFormatter.string(from: startTime)) at \(time)"
    }

    private var durationDisplay: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        switch (hours, minutes) {
        case (0, 0):
            return "0 min"
        case (_, 0):
            return hours == 1 ? "1 hr" : "\(hours) hrs"
        case (0, _):
            return "\(minutes) min"
        default:
            let hourText = hours == 1 ? "1 hr" : "\(hours) hrs"
            return "\(hourText) \(minutes) min"
        }
    }

    private var isSubmitDisabled: Bool {
        selectedActivity.trimmed().isEmpty || isSubmitting
    }

    private var displayedRecentActivities: [String] {
        var activities = recentActivities.isEmpty ? fallbackRecentActivities : Array(recentActivities.prefix(5))
        let trimmed = selectedActivity.trimmed()
        if trimmed.isEmpty == false && activities.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) == false {
            activities.insert(trimmed, at: 0)
            if activities.count > 5 {
                activities.removeLast()
            }
        }
        return activities
    }

    private var fallbackRecentActivities: [String] {
        ["Running", "Biking", "Weightlifting"]
    }

    private var durationHoursBinding: Binding<Int> {
        Binding<Int>(
            get: { durationMinutes / 60 },
            set: { newValue in
                let minutesPart = durationMinutes % 60
                durationMinutes = max(0, newValue) * 60 + minutesPart
            }
        )
    }

    private var durationMinutesComponentBinding: Binding<Int> {
        Binding<Int>(
            get: { durationMinutes % 60 },
            set: { newValue in
                let hoursPart = durationMinutes / 60
                let clamped = max(0, min(59, newValue))
                durationMinutes = hoursPart * 60 + clamped
            }
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E MMM d"
        return formatter
    }()
}

// MARK: - ActivitySearchSheet

struct ActivitySearchSheet: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredOptions: [String] {
        let base = ActivityLibrary.all
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredOptions, id: \.self) { activity in
                    Button {
                        onSelect(activity)
                        dismiss()
                    } label: {
                        Text(activity)
                            .foregroundColor(.primary)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText)
            .navigationTitle("More activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
    }
}

// MARK: - ActivityLibrary

enum ActivityLibrary {
    static let all: [String] = [
        "Archery", "Badminton", "Barre", "Baseball", "Basketball", "Bowling", "Boxing", "Cardiovascular exercise", "Climbing", "Core exercise", "Cricket", "Cross-country skiing", "Cross-training", "Cycling", "Dance", "Disc sports", "Diving", "Downhill skiing", "Elliptical", "Finnish baseball", "Fishing", "Fitness class", "Flexibility", "Floorball", "American Football", "Golf", "Gymnastics", "HIIT", "Handball", "Hiking", "Hockey", "Horseback riding", "Housework", "Hula hoop", "Hunting", "Ice skating", "Jumping rope", "Kettlebell", "Kite skiing", "Kitesurfing", "Lacrosse", "Martial arts", "Motorsport", "Mountain biking", "Musical instrument", "Nordic walking", "Orienteering", "Paddle sports", "Padel", "Pickelball", "Pilates", "Racquetball", "Roller skiing", "Rollerblading", "Rowing", "Rugby", "Running", "Sailing", "Skateboarding", "Snowboarding", "Snowshoeing", "Soccer", "Softball", "Squash", "Stair exercise", "Stremgth training", "Stretching", "Surfing", "Swimming", "Table tennis", "Tai chi", "Tennis", "Trampoline", "Virtual reality", "Volleyball", "Walking", "Water fitness", "Weightlifting", "Windsurfing", "Wrestling", "Yardwork", "Yoga", "Other"
    ]
}
