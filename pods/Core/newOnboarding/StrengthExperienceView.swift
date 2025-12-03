import SwiftUI

struct StrengthExperienceView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: OnboardingViewModel.StrengthExperienceOption?
    
    private let options = OnboardingViewModel.StrengthExperienceOption.allCases
    private let backgroundColor = Color.onboardingBackground
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack() {
                    Spacer()
                    
                    VStack(spacing: 24) {
                        Text("What's your strength training experience?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 16) {
                            ForEach(options) { option in
                                optionRow(option)
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
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            selectedOption = viewModel.selectedStrengthExperience
            viewModel.newOnboardingStepIndex = 4
            UserDefaults.standard.set("StrengthExperienceView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
        }
    }
    
    private func optionRow(_ option: OnboardingViewModel.StrengthExperienceOption) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                UISelectionFeedbackGenerator().selectionChanged()
                selectedOption = option
                viewModel.selectedStrengthExperience = option
            }
        } label: {
            HStack(spacing: 16) {
                Text(option.rawValue)
                    .font(.headline)
                    .fontWeight(.regular)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if selectedOption == option {
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
                    .fill(Color.onboardingCardBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(selectedOption == option ? Color.primary : Color.clear, lineWidth: selectedOption == option ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var continueButton: some View {
        Button {
            guard let option = selectedOption else { return }
            viewModel.selectedStrengthExperience = option
            let experienceLevel = option.experienceLevel
            UserDefaults.standard.set(experienceLevel.rawValue, forKey: "fitnessLevel")
            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 5)
            viewModel.currentStep = .gymLocation
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
        .disabled(selectedOption == nil)
        .opacity(selectedOption == nil ? 0.5 : 1.0)
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
                viewModel.newOnboardingStepIndex = 3
                viewModel.currentStep = .fitnessGoal
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
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 5)
                viewModel.selectedStrengthExperience = nil
                selectedOption = nil
                UserDefaults.standard.removeObject(forKey: "fitnessLevel")
                viewModel.desiredWeight = nil
                viewModel.desiredWeightKg = 0
                viewModel.currentStep = .gymLocation
            }
            .font(.headline)
            .foregroundColor(.primary)
        }
    }
    
    struct StrengthExperienceView_Previews: PreviewProvider {
        static var previews: some View {
            StrengthExperienceView()
                .environmentObject(OnboardingViewModel())
        }
    }
}
