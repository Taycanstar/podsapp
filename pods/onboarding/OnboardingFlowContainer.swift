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
        
        // Save to UserDefaults for persistence across app restarts
        viewModel.saveOnboardingState()
        
        // Mark that onboarding is in progress - FORCE SAVE
        UserDefaults.standard.set(true, forKey: "onboardingInProgress")
        UserDefaults.standard.set(currentStep.viewType, forKey: "currentOnboardingStep")
        UserDefaults.standard.set(currentStep.rawValue, forKey: "onboardingFlowStep")
        
        // Force synchronize to ensure data is written immediately
        UserDefaults.standard.synchronize()
        
        print("📝 Saved onboarding step: \(currentStep.viewType) (raw: \(currentStep.rawValue))")
    }
    
    private func completeOnboarding() {
        viewModel.onboardingCompleted = true
        viewModel.isShowingOnboarding = false
        
        // Clear onboarding progress flags when complete
        UserDefaults.standard.removeObject(forKey: "currentOnboardingStep")
        UserDefaults.standard.set(false, forKey: "onboardingInProgress")
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        
        // Force synchronize to ensure changes are saved immediately
        UserDefaults.standard.synchronize()
        
        print("✅ Onboarding completed and flags cleared")
    }
}

// Add initializer to sync with viewModel's state
extension OnboardingFlowContainer {
    init(viewModel: OnboardingViewModel) {
        // Can't initialize EnvironmentObject directly
        self._currentStep = State(initialValue: viewModel.currentFlowStep)
    }
}

