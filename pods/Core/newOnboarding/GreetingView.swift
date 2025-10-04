//
//  GreetingView.swift
//  pods
//
//  Created by Dimi Nunez on 10/3/25.
//


import SwiftUI

struct GreetingView: View {
    @EnvironmentObject private var viewModel: OnboardingViewModel

    private let backgroundColor = Color.onboardingBackground

    private var displayName: String {
        let trimmed = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "there" : trimmed
    }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                VStack(spacing: 24) {
                    Image(systemName: "laser.burst")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.primary)

                    VStack(spacing: 12) {
                        Text("Nice to meet you, \(displayName)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 32)

                        Text("Humuli puts your wellness on autopilot with nutrition, workouts, and insights planned for you.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                continueButton
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                    .background(backgroundColor.ignoresSafeArea())
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(backgroundColor, for: .navigationBar)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear(perform: handleAppear)
        .onDisappear { NavigationBarStyler.endOnboardingAppearance() }
    }

    private var continueButton: some View {
        Button {
            proceed()
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
                viewModel.currentStep = .enterName
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
                viewModel.currentStep = .signup
            }
            .font(.headline)
            .foregroundColor(.primary)
        }
    }

    private func handleAppear() {
        NavigationBarStyler.beginOnboardingAppearance()
        viewModel.newOnboardingStepIndex = 2
        saveProgressMarker()
    }

    private func proceed() {
        viewModel.newOnboardingStepIndex = 3
        viewModel.currentStep = .fitnessGoal
    }

    private func saveProgressMarker() {
        UserDefaults.standard.set("GreetingView", forKey: "currentOnboardingStep")
        UserDefaults.standard.set(true, forKey: "onboardingInProgress")
        UserDefaults.standard.synchronize()
    }
}

struct GreetingView_Previews: PreviewProvider {
    static var previews: some View {
        GreetingView()
            .environmentObject(OnboardingViewModel())
    }
}
