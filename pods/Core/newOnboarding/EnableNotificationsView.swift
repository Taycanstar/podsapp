import SwiftUI
import UserNotifications

struct EnableNotificationsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var isRequesting = false
    @State private var showTimePicker = false
    @State private var tempTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
Spacer()
                ScrollView {

                    VStack {
                        
                        header
                
                        notificationPreviews
                        previewTimeCard
                        
                    }
                   
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())

Spacer()
                actionButtons
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        }
        .onAppear {
            tempTime = viewModel.notificationPreviewTime
            viewModel.setNotificationTime(tempTime)
            refreshAuthorizationStatus()
            viewModel.newOnboardingStepIndex = viewModel.newOnboardingTotalSteps
        }
        .sheet(isPresented: $showTimePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "Preview Time",
                        selection: $tempTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            tempTime = viewModel.notificationPreviewTime
                            showTimePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            HapticFeedback.generate()
                            viewModel.setNotificationTime(tempTime)
                            showTimePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.fraction(0.35)])
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
        .padding(.bottom, 24)
    }

    private var notificationPreviews: some View {
        VStack(spacing: 10) {
            Image("foodnoti")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
            Image("wknoti")
                .resizable()
                .scaledToFit()

                .frame(maxWidth: .infinity)
    
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var previewTimeCard: some View {
        VStack(alignment: .leading) {
       
            Button {
                HapticFeedback.generate()
                tempTime = viewModel.notificationPreviewTime
                showTimePicker = true
            } label: {
                HStack {
                    Text("Preview time")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(timeFormatter.string(from: viewModel.notificationPreviewTime))
                        .font(.body)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.6))
                }
        
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
        .padding()
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
                viewModel.currentStep = .signup
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
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 6)
                viewModel.currentStep = .workoutSchedule
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
        guard !isRequesting else { return }
        isRequesting = true
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isRequesting = false
                refreshAuthorizationStatus()
                HapticFeedback.generate()
                viewModel.currentStep = .signup
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
}

struct EnableNotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = OnboardingViewModel()
        return EnableNotificationsView()
            .environmentObject(viewModel)
    }
}
