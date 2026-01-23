import SwiftUI

struct MainOnboardingView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isAuthenticated: Bool
    @Binding var showTourView: Bool

    var body: some View {
        ZStack {
            switch viewModel.currentStep {
            case .landing:
                StartupView(isAuthenticated: $isAuthenticated)
            case .fitnessGoal:
                FitnessGoalSelectionView()
            case .enterName:
                EnterNameView()
            case .greeting:
                GreetingView()
            case .strengthExperience:
                StrengthExperienceView()
            case .programOverview:
                ProgramOverviewView()
            case .desiredWeight:
                DesiredWeightSelectionView()
            case .gymLocation:
                GymLocationView()
            case .reviewEquipment:
                ReviewEquipmentView()
            case .workoutSchedule:
                ScheduleSelectionView()
            case .dietPreferences:
                DietPreferencesView()
            case .enableNotifications:
                EnableNotificationsView()
            case .demo:
                DemoView()
            case .allowHealth:
                AllowHealthView()
            case .aboutYou:
                AboutYouView()
            case .signup:
                RegisterView(isAuthenticated: $isAuthenticated)
            case .emailVerification:
                EmailVerificationView()
            case .info:
                InfoView()
            case .gender:
                // Legacy step - redirect to new onboarding
                FitnessGoalSelectionView()
                    .onAppear {
                        viewModel.currentStep = .fitnessGoal
                    }
            case .welcome:
                WelcomeView(isAuthenticated: $isAuthenticated, showTourView: $showTourView)
            case .login:
                LoginView(isAuthenticated: $isAuthenticated)
            }
        }
        .preferredColorScheme(themeManager.currentTheme == .system ? nil : (themeManager.currentTheme == .dark ? .dark : .light))
        .onAppear {
            viewModel.loadProgress()
        }
    }
}
