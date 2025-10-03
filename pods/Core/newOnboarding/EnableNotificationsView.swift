import SwiftUI
import UserNotifications

struct EnableNotificationsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var isRequesting = false
    @State private var tempTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var isShowingPicker = false
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private let backgroundColor = Color.onboardingBackground

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 32) {
                        header
                        notificationPreviews
                        previewTimeCard
                        Spacer(minLength: 120)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                    .padding(.bottom, 32)
                }
                .background(backgroundColor.ignoresSafeArea())

                actionButtons
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(backgroundColor, for: .navigationBar)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            NavigationBarStyler.beginOnboardingAppearance()
            tempTime = viewModel.notificationPreviewTime
            viewModel.setNotificationTime(tempTime)
            refreshAuthorizationStatus()
            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 8)
        }
        .onDisappear {
            NavigationBarStyler.endOnboardingAppearance()
        }
        .onChange(of: tempTime) { newValue in
            viewModel.setNotificationTime(newValue)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Get meal reminders and workout previews personalized for you")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
    }

    private var notificationPreviews: some View {
        VStack(spacing: 16) {
            Image("foodnoti")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
            Image("wknoti")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
    }

    private var previewTimeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                HapticFeedback.generate()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingPicker.toggle()
                }
            } label: {
                HStack {
                    Text("Preview time")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(timeFormatter.string(from: tempTime))
                        .font(.body)
                        .foregroundColor(.secondary)
                    Image(systemName: isShowingPicker ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if isShowingPicker {
                HStack {
                    Spacer()
                    DatePicker(
                        "Preview time",
                        selection: $tempTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    Spacer()
                }
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 24)
    }
    

    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button("Not now") {
                HapticFeedback.generate()
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
                viewModel.setNotificationTime(viewModel.notificationPreviewTime)
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 9)
                viewModel.currentStep = .allowHealth
            }
            .foregroundColor(.primary)

            Button {
                requestNotifications()
            } label: {
                HStack {
                    if isRequesting {
                        ProgressView()
                            .tint(Color(.systemBackground))
                    } else {
                        Text("Enable Notifications")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .foregroundColor(Color(.systemBackground))
                .cornerRadius(36)
            }
            .disabled(isRequesting)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private var progressView: some View {
        ProgressView(value: viewModel.newOnboardingProgress)
            .progressViewStyle(.linear)
            .frame(width: 160)
            .tint(.primary)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 7)
                viewModel.currentStep = .dietPreferences
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }

        ToolbarItem(placement: .principal) {
            progressView
        }

        ToolbarItem(placement: .topBarTrailing) {
            EmptyView()
        }
    }

    private func requestNotifications() {
        if authorizationStatus == .authorized {
            schedulePreviewNotification()
            HapticFeedback.generate()
            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 9)
            viewModel.currentStep = .allowHealth
            return
        }

        guard !isRequesting else { return }
        isRequesting = true
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isRequesting = false
                refreshAuthorizationStatus()
                if granted {
                    schedulePreviewNotification()
                }
                HapticFeedback.generate()
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 9)
                viewModel.currentStep = .allowHealth
            }
        }
    }

    private func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    private func schedulePreviewNotification() {
        viewModel.setNotificationTime(viewModel.notificationPreviewTime)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])

        let content = UNMutableNotificationContent()
        let (title, body) = workoutPreviewContent()
        content.title = title
        content.body = body
        content.sound = .default

        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: viewModel.notificationPreviewTime)
        components.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule workout preview notification: \(error.localizedDescription)")
            }
        }
    }

    private func workoutPreviewContent() -> (String, String) {
        let title = "Here's today's workout plan 🏃‍♂️"

        if let workout = workoutManager.todayWorkout ?? workoutManager.currentWorkout {
            let displayTitle: String
            if workoutManager.todayWorkout != nil {
                displayTitle = workoutManager.todayWorkoutDisplayTitle
            } else {
                let trimmed = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
                displayTitle = trimmed.isEmpty ? workoutManager.todayWorkoutDisplayTitle : trimmed
            }
            let exerciseNames = workout.exercises.map { $0.exercise.name }.filter { !$0.isEmpty }
            if !exerciseNames.isEmpty {
                let primaryNames = Array(exerciseNames.prefix(3))
                var body = "\(displayTitle): \(primaryNames.joined(separator: ", "))"
                let remaining = exerciseNames.count - primaryNames.count
                if remaining > 0 {
                    body += " and \(remaining) more."
                } else {
                    body += "."
                }
                return (title, body)
            } else {
                return (title, "\(displayTitle): Tap to see the latest exercises in the app.")
            }
        }

        return (title, "Your personalized workout is ready. Open Humuli to preview today's plan.")
    }

    private static let notificationIdentifier = "daily_workout_preview"
}

struct EnableNotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = OnboardingViewModel()
        let workoutManager = WorkoutManager.shared
        return EnableNotificationsView()
            .environmentObject(viewModel)
            .environmentObject(workoutManager)
    }
}
