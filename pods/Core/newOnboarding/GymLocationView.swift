import SwiftUI

struct GymLocationView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedOption: OnboardingViewModel.GymLocationOption?
    
    private let options = OnboardingViewModel.GymLocationOption.allCases
    private let backgroundColor = Color.onboardingBackground
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack() {
                   
                    VStack(spacing: 24) {
                        Text("Where do you usually workout?")
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
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(backgroundColor, for: .navigationBar)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            NavigationBarStyler.beginOnboardingAppearance()
            selectedOption = viewModel.selectedGymLocation
            viewModel.newOnboardingStepIndex = 5
            UserDefaults.standard.set("GymLocationView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
        }
        .onDisappear {
            NavigationBarStyler.endOnboardingAppearance()
        }
    }
    
    private func optionRow(_ option: OnboardingViewModel.GymLocationOption) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                UISelectionFeedbackGenerator().selectionChanged()
                selectedOption = option
                viewModel.selectedGymLocation = option
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(option.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(option.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
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
                    .fill(Color(.systemBackground))
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
            viewModel.selectedGymLocation = option
            if option == .noEquipment {
                viewModel.equipmentInventory.removeAll()
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 7)
                viewModel.currentStep = .workoutSchedule
            } else {
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 6)
                viewModel.currentStep = .reviewEquipment
            }
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
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 4)
                viewModel.currentStep = .strengthExperience
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
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 6)
                viewModel.selectedGymLocation = nil
                viewModel.equipmentInventory.removeAll()
                viewModel.currentStep = .workoutSchedule
            }
            .font(.headline)
            .foregroundColor(.primary)
        }
    }
}

struct GymLocationView_Previews: PreviewProvider {
    static var previews: some View {
        GymLocationView()
            .environmentObject(OnboardingViewModel())
    }
}
