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
            case .allowHealth:
                AllowHealthView()
            case .aboutYou:
                AboutYouView()
            case .signup:
                SignupView()
            case .emailVerification:
                EmailVerificationView()
            case .info:
                InfoView()
            case .gender:
                onboardingFlowView
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
    
    // Helper view to handle the detailed onboarding flow
    private var onboardingFlowView: some View {
        flowStepView()
    }
    
    // Helper method to return the appropriate view based on the current flow step
    @ViewBuilder
    private func flowStepView() -> some View {
        switch viewModel.currentFlowStep {
        case .gender:
            GenderView()
        case .workoutDays:
            WorkoutDaysView()
        case .heightWeight:
            HeightWeightView()
        case .dob:
            DobView()
        case .desiredWeight:
            DesiredWeightView()
        case .goalInfo:
            GoalInfoView()
        case .goalTime:
            GoalTimeView()
        case .twoX:
            TwoXView()
        case .obstacles:
            ObstaclesView()
        case .specificDiet:
            SpecificDietView()
        case .accomplish:
            AccomplishView()
        case .fitnessLevel:
            FitnessLevelView()
        case .fitnessGoal:
            FitnessGoalView()
        case .sportSelection:
            SportSelectionView()
        case .connectHealth:
            ConnectToAppleHealth()
        case .complete:
            CreatingPlanView()
        }
    }
}
