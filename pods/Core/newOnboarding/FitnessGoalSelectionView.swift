import SwiftUI

struct FitnessGoalSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedGoal: OnboardingViewModel.FitnessGoalOption?
    
    private let goals = OnboardingViewModel.FitnessGoalOption.allCases
    private let backgroundColor = Color.onboardingBackground
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack() {
                    Spacer()
                    
                    VStack(spacing: 24) {
                        Text("What's your main fitness goal?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 16) {
                            ForEach(goals) { goal in
                                fitnessGoalRow(for: goal)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundColor.ignoresSafeArea())
                
                continueButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(backgroundColor, for: .navigationBar)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            NavigationBarStyler.beginOnboardingAppearance()
            selectedGoal = viewModel.selectedFitnessGoal
            viewModel.newOnboardingStepIndex = 1
        }
        .onDisappear {
            NavigationBarStyler.endOnboardingAppearance()
        }
    }
    
    @ViewBuilder
    private func fitnessGoalRow(for goal: OnboardingViewModel.FitnessGoalOption) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                UISelectionFeedbackGenerator().selectionChanged()
                selectedGoal = goal
                viewModel.selectedFitnessGoal = goal
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: goal.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 28, height: 28)
                
                Text(goal.rawValue)
                    .font(.headline)
                    .fontWeight(.regular)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if selectedGoal == goal {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(selectedGoal == goal ? Color.primary : Color.clear, lineWidth: selectedGoal == goal ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var continueButton: some View {
        Button {
            guard let goal = selectedGoal else { return }
            viewModel.selectedFitnessGoal = goal
            viewModel.newOnboardingStepIndex = 2
            viewModel.currentStep = .strengthExperience
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
        .disabled(selectedGoal == nil)
        .opacity(selectedGoal == nil ? 0.5 : 1.0)
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
                viewModel.newOnboardingStepIndex = 1
                viewModel.currentStep = .landing
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
                viewModel.newOnboardingStepIndex = viewModel.newOnboardingTotalSteps
                viewModel.selectedFitnessGoal = nil
                viewModel.selectedStrengthExperience = nil
                UserDefaults.standard.removeObject(forKey: "fitnessLevel")
                viewModel.desiredWeight = nil
                selectedGoal = nil
                viewModel.currentStep = .signup
            }
            .font(.headline)
            .foregroundColor(.primary)
        }
    }
    
    struct FitnessGoalSelectionView_Previews: PreviewProvider {
        static var previews: some View {
            FitnessGoalSelectionView()
                .environmentObject(OnboardingViewModel())
        }
    }
}
