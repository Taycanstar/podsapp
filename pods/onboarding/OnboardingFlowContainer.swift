import SwiftUI

struct OnboardingFlowContainer: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) var dismiss
    @State private var currentStep: OnboardingViewModel.OnboardingFlowStep = .gender
    
    var body: some View {
        NavigationView {
            VStack {
                // Content based on current step
                switch currentStep {
                case .gender:
                    GenderView(nextStep: moveToNextStep)
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .workoutDays:
                    WorkoutDaysView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .heightWeight:
                    HeightWeightView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .dob:
                    DobView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .onboardingGoal:
                    OnboardingGoal()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .desiredWeight:
                    DesiredWeightView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .goalInfo:
                    GoalInfoView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .goalTime:
                    GoalTimeView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .twoX:
                    TwoXView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .obstacles:
                    ObstaclesView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .specificDiet:
                    SpecificDietView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .accomplish:
                    AccomplishView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .connectHealth:
                    ConnectToAppleHealth()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .caloriesBurned:
                    CaloriesBurnedView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .rollover:
                    RolloverView()
                        .environmentObject(viewModel)
                        .onAppear { updateCurrentStep() }
                case .complete:
                    CreatingPlanView()
                        .environmentObject(viewModel)
                        .onAppear { completeOnboarding() }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func moveToNextStep() {
        if let nextIndex = OnboardingViewModel.OnboardingFlowStep.allCases.firstIndex(where: { $0.rawValue == currentStep.rawValue + 1 }) {
            currentStep = OnboardingViewModel.OnboardingFlowStep.allCases[nextIndex]
        } else {
            completeOnboarding()
        }
    }
    
    private func updateCurrentStep() {
        // Update the ViewModel's currentFlowStep to match our local state
        viewModel.currentFlowStep = currentStep
    }
    
    private func completeOnboarding() {
        viewModel.onboardingCompleted = true
        viewModel.isShowingOnboarding = false
    }
}

