import SwiftUI

struct DietPreferencesView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedDiet: OnboardingViewModel.DietPreferenceOption?
    private let backgroundColor = Color.onboardingBackground

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        dietList
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
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
            selectedDiet = viewModel.selectedDietPreference
            viewModel.newOnboardingStepIndex = 8
            UserDefaults.standard.set("DietPreferencesView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
        }
        .onDisappear {
            NavigationBarStyler.endOnboardingAppearance()
        }
        .onChange(of: viewModel.selectedDietPreference) { _, newValue in
            selectedDiet = newValue
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("What diet do you follow?")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var dietList: some View {
        VStack(spacing: 16) {
            ForEach(OnboardingViewModel.DietPreferenceOption.allCases) { diet in
                dietRow(for: diet)
            }
        }
        .padding(.horizontal, 24)
    }

    private func dietRow(for diet: OnboardingViewModel.DietPreferenceOption) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                HapticFeedback.generate()
                selectedDiet = diet
                viewModel.selectedDietPreference = diet
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: diet.systemImageName)
                    .foregroundColor(.primary)
                    .font(.title2)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(diet.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(diet.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(selectedDiet == diet ? Color.primary : Color.clear, lineWidth: selectedDiet == diet ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private var continueButton: some View {
        Button {
            guard let diet = selectedDiet else { return }
            viewModel.selectedDietPreference = diet
            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 9)
            viewModel.currentStep = .enableNotifications
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
        .disabled(selectedDiet == nil)
        .opacity(selectedDiet == nil ? 0.5 : 1.0)
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
                viewModel.newOnboardingStepIndex = 7
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
            Button("Skip") {
                viewModel.selectedDietPreference = nil
                selectedDiet = nil
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 9)
                viewModel.currentStep = .enableNotifications
            }
            .font(.headline)
            .foregroundColor(.primary)
        }
    }
}

struct DietPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        DietPreferencesView()
            .environmentObject(OnboardingViewModel())
    }
}
