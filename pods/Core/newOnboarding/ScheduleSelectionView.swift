import SwiftUI

struct ScheduleSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    private let backgroundColor = Color.onboardingBackground

    @State private var daysPerWeek: Int = 4
    @State private var sessionDuration: Int = 60
    @State private var totalWeeks: Int = 6

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                    Form {
                        Section {
                            Stepper("\(daysPerWeek) days per week", value: $daysPerWeek, in: 2...7)
                                .onChange(of: daysPerWeek) { _, newValue in
                                    viewModel.setTrainingDaysPerWeek(newValue, autoSelectDays: true)
                                }
                            Stepper("\(sessionDuration) min per session", value: $sessionDuration, in: 30...120, step: 15)
                                .onChange(of: sessionDuration) { _, newValue in
                                    viewModel.sessionDurationMinutes = newValue
                                }
                            Stepper("\(totalWeeks) weeks", value: $totalWeeks, in: 4...12)
                                .onChange(of: totalWeeks) { _, newValue in
                                    viewModel.programTotalWeeks = newValue
                                }
                        } header: {
                            Text("Schedule")
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(backgroundColor)

                    Spacer(minLength: 100)
                }
                .background(backgroundColor.ignoresSafeArea())

                continueButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            // Initialize from viewModel
            daysPerWeek = max(2, viewModel.trainingDaysPerWeek > 0 ? viewModel.trainingDaysPerWeek : 4)
            sessionDuration = viewModel.sessionDurationMinutes > 0 ? viewModel.sessionDurationMinutes : 60
            totalWeeks = viewModel.programTotalWeeks > 0 ? viewModel.programTotalWeeks : 6

            viewModel.setTrainingDaysPerWeek(daysPerWeek, autoSelectDays: true)
            viewModel.sessionDurationMinutes = sessionDuration
            viewModel.programTotalWeeks = totalWeeks

            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 7)
            UserDefaults.standard.set("ScheduleSelectionView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Set workout schedule")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("Choose how often you train and how long each session should be.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var continueButton: some View {
        Button {
            viewModel.syncWorkoutSchedule()
            viewModel.setNotificationTime(viewModel.notificationPreviewTime)
            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 8)
            viewModel.currentStep = .dietPreferences
        } label: {
            Text("Continue")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .foregroundColor(Color(.systemBackground))
                .cornerRadius(36)
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
                if viewModel.selectedGymLocation == .noEquipment || viewModel.selectedGymLocation == nil {
                    viewModel.newOnboardingStepIndex = 5
                    viewModel.currentStep = .gymLocation
                } else {
                    viewModel.newOnboardingStepIndex = 6
                    viewModel.currentStep = .reviewEquipment
                }
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
            Button("Skip") {
                viewModel.syncWorkoutSchedule()
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 7)
                viewModel.currentStep = .dietPreferences
            }
            .font(.headline)
            .foregroundColor(.primary)
        }
    }
}

struct ScheduleSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = OnboardingViewModel()
        viewModel.setTrainingDaysPerWeek(4)
        return ScheduleSelectionView()
            .environmentObject(viewModel)
    }
}
