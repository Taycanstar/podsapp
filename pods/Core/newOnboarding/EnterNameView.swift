//
//  EnterNameView.swift
//  pods
//
//  Created by Dimi Nunez on 10/3/25.
//


import SwiftUI

struct EnterNameView: View {
    @EnvironmentObject private var viewModel: OnboardingViewModel
    @State private var name: String = ""
    @FocusState private var isNameFieldFocused: Bool

    private let backgroundColor = Color.onboardingBackground

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                VStack(spacing: 16) {
                    Text("What's your name?")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)

                    VStack(spacing: 8) {
                        TextField("Enter your name", text: $name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.center)
                            .font(.title3)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 5)
                            .padding(.top, 12)
                            .focused($isNameFieldFocused)

                        Rectangle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(height: 1)
                            .padding(.horizontal, 24)
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
        .onTapGesture {
            isNameFieldFocused = false
        }
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
        .disabled(trimmedName.isEmpty)
        .opacity(trimmedName.isEmpty ? 0.5 : 1)
    }

    private var progressView: some View {
        ProgressView(value: viewModel.newOnboardingProgress)
            .progressViewStyle(.linear)
            .frame(width: 160)
            .tint(.primary)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleAppear() {
        NavigationBarStyler.beginOnboardingAppearance()
        name = trimmedNameIfNeeded(from: viewModel.name)
        viewModel.newOnboardingStepIndex = 1
        saveProgressMarker()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isNameFieldFocused = true
        }
    }

    private func proceed() {
        let cleanedName = trimmedName
        guard !cleanedName.isEmpty else { return }

        viewModel.name = cleanedName
        viewModel.profileInitial = String(cleanedName.prefix(1)).uppercased()
        UserDefaults.standard.set(cleanedName, forKey: "userName")
        UserDefaults.standard.set(viewModel.profileInitial, forKey: "profileInitial")
        UserDefaults.standard.synchronize()

        viewModel.newOnboardingStepIndex = 2
        viewModel.currentStep = .greeting
    }

    private func saveProgressMarker() {
        UserDefaults.standard.set("EnterNameView", forKey: "currentOnboardingStep")
        UserDefaults.standard.set(true, forKey: "onboardingInProgress")
        UserDefaults.standard.synchronize()
    }

    private func trimmedNameIfNeeded(from source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }
}

struct EnterNameView_Previews: PreviewProvider {
    static var previews: some View {
        EnterNameView()
            .environmentObject(OnboardingViewModel())
    }
}
