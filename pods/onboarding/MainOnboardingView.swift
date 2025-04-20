import SwiftUI

struct MainOnboardingView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Binding var isAuthenticated: Bool
    @Binding var showTourView: Bool
    
    var body: some View {
        ZStack {
            switch viewModel.currentStep {
            case .landing:
                LandingView(isAuthenticated: $isAuthenticated)
            case .signup:
                SignupView()
            case .emailVerification:
                EmailVerificationView()
            case .info:
                InfoView()
            case .gender:
                // This is the entry point to the detailed onboarding flow
                // Each view handles its own progress display
                onboardingFlowView
             case .welcome:
                 WelcomeView(isAuthenticated: $isAuthenticated, showTourView: $showTourView)
            case .login:
                LoginView(isAuthenticated: $isAuthenticated)
            }
        }
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
        case .onboardingGoal:
            OnboardingGoal()
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
        case .connectHealth:
            ConnectToAppleHealth()
        case .caloriesBurned:
            CaloriesBurnedView()
        case .rollover:
            RolloverView()
        case .complete:
            CreatingPlanView()
        }
    }
}





