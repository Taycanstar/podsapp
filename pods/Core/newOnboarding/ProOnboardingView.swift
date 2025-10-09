import SwiftUI

struct ProOnboardingView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var viewModel: OnboardingViewModel
    @State private var selectedPlan: PlanOption = .yearly
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    private enum PlanOption: String, CaseIterable, Identifiable {
        case monthly
        case yearly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }

        var duration: SubscriptionDuration {
            switch self {
            case .monthly: return .monthly
            case .yearly: return .yearly
            }
        }

        var tier: SubscriptionTier {
            switch self {
            case .monthly: return .humuliProMonthly
            case .yearly: return .humuliProYearly
            }
        }

        var renewalText: String {
            switch self {
            case .monthly: return "Auto-renews monthly. Cancel anytime."
            case .yearly: return "Auto-renews yearly. Cancel anytime."
            }
        }
    }

    private let proFeatures: [String] = [
        "Unlimited Food Scans",
        "Unlimited Workout Sessions",
        "Pro Food Search",
        "Advanced Analytics",
        "Scheduled Meal Logging",
        "Bulk Photo Logging"
    ]

    private var isSubscribed: Bool {
        subscriptionManager.hasActiveSubscription() || viewModel.subscriptionStatus == "active"
    }

    private var subscribeButtonTitle: String {
        if isSubscribed {
            return "Continue to Humuli"
        }
        switch selectedPlan {
        case .monthly:
            return "Subscribe for \(subscriptionManager.monthlyPrice(for: .humuliProMonthly))"
        case .yearly:
            return "Subscribe for \(subscriptionManager.annualPrice(for: .humuliProYearly))"
        }
    }

    private var billingDescription: String {
        switch selectedPlan {
        case .monthly:
            return subscriptionManager.monthlyBillingInfo(for: .humuliProMonthly)
        case .yearly:
            return subscriptionManager.annualBillingInfo(for: .humuliProYearly)
        }
    }

    private var savingsText: String? {
        guard selectedPlan == .yearly else { return nil }
        let savings = subscriptionManager.savingsPercentage(for: .humuliProMonthly)
        return savings > 0 ? "Save \(savings)% versus monthly" : nil
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        titleSection
                        planPickerSection
                        featureSection
                    }
                    .padding(.horizontal, 24)
                }

                footer
            }
        }
        .preferredColorScheme(.light)
        .alert("Purchase Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionUpdated)) { _ in
            if isSubscribed {
                isPresented = false
            }
        }
        .task {
            if let email = await currentEmail() {
                await subscriptionManager.fetchSubscriptionInfoIfNeeded(for: email)
            }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(20)
            }
        }
    }

    private var titleSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 35))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Welcome to Humuli Pro")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                Text("Unlock everything you just previewed with your personalized plan.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var planPickerSection: some View {
        VStack(spacing: 20) {
            Picker("Plan", selection: $selectedPlan) {
                ForEach(PlanOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 0) {
      

                if let savingsText {
                    Text(savingsText)
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Included with Pro")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)

            VStack(spacing: 0) {
                ForEach(proFeatures, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))

                        Text(feature)
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color("mdBg"))
                    .cornerRadius(14)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                if isSubscribed {
                    isPresented = false
                } else {
                    Task { await subscribe() }
                }
            } label: {
                if isProcessing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text(subscribeButtonTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .cornerRadius(36)
                }
            }
            .disabled(isProcessing)
            .padding(.horizontal, 24)

            Text(selectedPlan.renewalText)
                .font(.system(size: 13))
                .foregroundColor(.gray)

        }
        .background(
            Color.white
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func subscribe() async {
        guard isProcessing == false else { return }
        guard let email = await currentEmail() else {
            await MainActor.run {
                showError = true
                errorMessage = "Please sign in again before subscribing."
            }
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await subscriptionManager.purchase(
                tier: selectedPlan.tier,
                duration: selectedPlan.duration,
                userEmail: email,
                onboardingViewModel: viewModel
            )
            await subscriptionManager.fetchSubscriptionInfoIfNeeded(for: email, force: true)
            await MainActor.run {
                isPresented = false
            }
        } catch let error as SubscriptionError {
            await MainActor.run {
                showError = true
                errorMessage = error.localizedDescription
            }
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func currentEmail() -> String? {
        if viewModel.email.isEmpty == false {
            return viewModel.email
        }
        if let stored = UserDefaults.standard.string(forKey: "userEmail"), stored.isEmpty == false {
            return stored
        }
        return nil
    }
}

