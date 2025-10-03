import SwiftUI

struct AllowHealthView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    private let healthKitManager = HealthKitManager.shared
    private let backgroundColor = Color.onboardingBackground
    @State private var isRequestingPermission = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        Image("health")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)

                        Text("Allow Apple Health Integration")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Text("Your health data helps Humuli design your workouts, give accurate insights, and record your activity.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 24)
                .background(backgroundColor.ignoresSafeArea())

                actionButtons
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(backgroundColor, for: .navigationBar)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            NavigationBarStyler.beginOnboardingAppearance()
            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 8)
            UserDefaults.standard.set("AllowHealthView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            advanceIfHealthKitAlreadyAuthorized()
        }
        .onDisappear {
            NavigationBarStyler.endOnboardingAppearance()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button("Not now") {
                HapticFeedback.generate()
                UserDefaults.standard.set(false, forKey: "healthKitEnabled")
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 8)
                viewModel.currentStep = .aboutYou
            }
            .foregroundColor(.primary)

            Button {
                HapticFeedback.generate()
                requestHealthPermissions()
            } label: {
                ZStack {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .opacity(isRequestingPermission ? 0 : 1)

                    if isRequestingPermission {
                        ProgressView()
                            .tint(Color(.systemBackground))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .foregroundColor(Color(.systemBackground))
                .cornerRadius(36)
            }
            .disabled(isRequestingPermission)
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
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 8)
                viewModel.currentStep = .enableNotifications
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
            EmptyView()
        }
    }
}

struct AllowHealthView_Previews: PreviewProvider {
    static var previews: some View {
        AllowHealthView()
            .environmentObject(OnboardingViewModel())
    }
}

private extension AllowHealthView {
    func requestHealthPermissions() {
        guard !isRequestingPermission else { return }

        isRequestingPermission = true
        healthKitManager.checkAndRequestHealthPermissions { _ in
            DispatchQueue.main.async {
                completeStep()
            }
        }
    }

    func advanceIfHealthKitAlreadyAuthorized() {
        if healthKitManager.isAuthorized {
            completeStep()
        }
    }

    func completeStep() {
        isRequestingPermission = false
        viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 8)
        viewModel.currentStep = .aboutYou
    }
}
