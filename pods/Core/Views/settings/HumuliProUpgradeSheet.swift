//
//  HumuliProUpgradeSheet.swift
//  Pods
//
//  Created by Claude Code
//

import SwiftUI
import UIKit

struct HumuliProUpgradeSheet: View {
    @Environment(\.dismiss) var dismiss
    let feature: ProFeatureGate.ProFeature?
    let usageSummary: UsageSummary?
    let onDismiss: () -> Void
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var viewModel: OnboardingViewModel

    enum SubscriptionPlan: String, CaseIterable, Identifiable {
        case monthly
        case yearly

        var id: String { rawValue }

        var duration: SubscriptionDuration {
            switch self {
            case .monthly: return .monthly
            case .yearly: return .yearly
            }
        }

        var pickerTitle: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }

        var renewalText: String {
            switch self {
            case .monthly: return "Auto-renews monthly. Cancel anytime."
            case .yearly: return "Auto-renews yearly. Cancel anytime."
            }
        }
    }
}

// MARK: - Humuli Pro Management

enum HumuliProPlanOption: String, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: return "Humuli Pro Monthly"
        case .yearly: return "Humuli Pro Yearly"
        }
    }

    var tier: SubscriptionTier {
        switch self {
        case .monthly: return .humuliProMonthly
        case .yearly: return .humuliProYearly
        }
    }

    var duration: SubscriptionDuration {
        switch self {
        case .monthly: return .monthly
        case .yearly: return .yearly
        }
    }

    func priceText(using manager: SubscriptionManager) -> String {
        switch self {
        case .monthly:
            return manager.monthlyPrice(for: .humuliProMonthly)
        case .yearly:
            return manager.annualPrice(for: .humuliProYearly)
        }
    }

    func billingInfo(using manager: SubscriptionManager) -> String {
        switch self {
        case .monthly:
            return manager.monthlyBillingInfo(for: .humuliProMonthly)
        case .yearly:
            return manager.annualBillingInfo(for: .humuliProYearly)
        }
    }

    static func option(from planName: String?) -> HumuliProPlanOption {
        guard let name = planName?.lowercased() else {
            return .monthly
        }
        if name.contains("year") {
            return .yearly
        }
        return .monthly
    }
}

struct ManageSubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject var viewModel: OnboardingViewModel
    let onDismiss: () -> Void

    @State private var showPlans = false
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var infoMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                currentPlanCard

                Button {
                    showPlans = true
                } label: {
                    Text("See All Plans")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(12)
                }

                Button {
                    openManageSubscriptions()
                } label: {
                    Text("Manage in App Store")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }

                Button(role: .destructive) {
                    Task { await cancelSubscription() }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Cancel Subscription")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .disabled(isProcessing)

                if let infoMessage {
                    Text(infoMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Link("About Subscriptions and Privacy",
                     destination: URL(string: "https://support.apple.com/en-us/HT202039")!)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Manage Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showPlans) {
                AvailablePlansSheet(
                    subscriptionManager: subscriptionManager,
                    viewModel: viewModel
                ) {
                    showPlans = false
                    Task { await refreshSubscription() }
                }
            }
            .onDisappear {
                onDismiss()
            }
        }
    }

    private var currentPlanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
                    .padding(12)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(planName)
                        .font(.headline)
                    Text("Humuli Pro")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            HStack(spacing: 12) {
                Label(priceDescription, systemImage: "creditcard")
                Spacer()
            }
            .font(.subheadline)

            if let renewalDescription {
                HStack(spacing: 12) {
                    Label(renewalDescription, systemImage: "calendar")
                    Spacer()
                }
                .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("mdBg"))
        .cornerRadius(16)
    }

    private var planName: String {
        viewModel.subscriptionPlan ?? subscriptionManager.subscriptionInfo?.plan ?? "Humuli Pro"
    }

    private var currentOption: HumuliProPlanOption {
        HumuliProPlanOption.option(from: viewModel.subscriptionPlan ?? subscriptionManager.subscriptionInfo?.plan)
    }

    private var priceDescription: String {
        currentOption.priceText(using: subscriptionManager)
    }

    private var renewalDescription: String? {
        guard let expires = subscriptionManager.subscriptionInfo?.expiresAt ??
                viewModel.subscriptionExpiresAt,
              let date = ISO8601DateFormatter.fullFormatter.date(from: expires) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return "Renews \(formatter.string(from: date))"
    }

    private func cancelSubscription() async {
        guard isProcessing == false else { return }
        guard let email = await currentEmail() else {
            await presentError("We couldn't find your account email. Please sign in again.")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await subscriptionManager.cancelSubscription(userEmail: email)
            await refreshSubscription()
            await MainActor.run {
                infoMessage = "Your subscription has been cancelled. You'll retain access until the current period ends."
            }
        } catch {
            await presentError(error.localizedDescription)
        }
    }

    private func refreshSubscription() async {
        guard let email = await currentEmail() else { return }
        await subscriptionManager.fetchSubscriptionInfoIfNeeded(for: email, force: true)
    }

    private func presentError(_ message: String) async {
        await MainActor.run {
            errorMessage = message
            showError = true
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

    private func openManageSubscriptions() {
        guard let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }
}

struct AvailablePlansSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject var viewModel: OnboardingViewModel
    let onPlanChange: () -> Void

    @State private var selectedOption: HumuliProPlanOption
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(subscriptionManager: SubscriptionManager,
         viewModel: OnboardingViewModel,
         onPlanChange: @escaping () -> Void) {
        self.subscriptionManager = subscriptionManager
        self.viewModel = viewModel
        self.onPlanChange = onPlanChange
        _selectedOption = State(initialValue: HumuliProPlanOption.option(from: viewModel.subscriptionPlan ?? subscriptionManager.subscriptionInfo?.plan))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                ForEach(HumuliProPlanOption.allCases) { option in
                    Button {
                        selectedOption = option
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.title)
                                    .font(.headline)
                                Text(option.billingInfo(using: subscriptionManager))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedOption == option ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedOption == option ? .accentColor : .gray)
                                .font(.title3)
                        }
                        .padding()
                        .background(Color("mdBg"))
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Task { await subscribe() }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Continue with \(selectedOption.title)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(14)
                    }
                }
                .disabled(isProcessing)

                Spacer()
            }
            .padding()
            .navigationTitle("Available Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func subscribe() async {
        guard isProcessing == false else { return }
        guard let email = await currentEmail() else {
            await presentError("We couldn't find your account email. Please sign in again.")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await subscriptionManager.purchase(
                tier: selectedOption.tier,
                duration: selectedOption.duration,
                userEmail: email,
                onboardingViewModel: viewModel
            )
            await subscriptionManager.fetchSubscriptionInfoIfNeeded(for: email, force: true)
            await MainActor.run {
                onPlanChange()
                dismiss()
            }
        } catch {
            await presentError(error.localizedDescription)
        }
    }

    private func presentError(_ message: String) async {
        await MainActor.run {
            errorMessage = message
            showError = true
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

extension HumuliProUpgradeSheet {
    private var selectedTier: SubscriptionTier {
        switch selectedPlan {
        case .monthly: return .humuliProMonthly
        case .yearly: return .humuliProYearly
        }
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                            .padding(20)
                    }
                }

                // Icon and title
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 35))
                        .foregroundColor(.blue)

                    Text("Humuli Pro")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)

                    VStack(spacing: 6) {
                        if let usageSummary = usageSummary,
                           let detail = usageDetail(for: feature, summary: usageSummary) {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            Text("Unlock the complete Humuli experience.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                }
                .padding(.top, 20)

                // Plan picker
                Picker("Subscription Plan", selection: $selectedPlan) {
                    ForEach(SubscriptionPlan.allCases) { plan in
                        Text(plan.pickerTitle).tag(plan)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 20)

                planSummary

                Spacer()

                // Feature comparison table
                featureComparisonView
                    .padding(.horizontal, 24)

                Spacer()

                // Single upgrade button
                Button {
                    Task { await upgrade() }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text(upgradeButtonTitle)
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
                .padding(.bottom, 12)

                // Auto-renew text
                Text(selectedPlan.renewalText)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.light)
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var planSummary: some View {
        VStack(spacing: 8) {
            if let savings = savingsText() {
                Text(savings)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.top, 16)
    }

    private var upgradeButtonTitle: String {
        switch selectedPlan {
        case .monthly:
            return "Upgrade for \(subscriptionManager.monthlyPrice(for: .humuliProMonthly))"
        case .yearly:
            return "Upgrade for \(subscriptionManager.annualPrice(for: .humuliProYearly))"
        }
    }

    private func priceText(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .monthly:
            return subscriptionManager.monthlyPrice(for: .humuliProMonthly)
        case .yearly:
            return subscriptionManager.annualPrice(for: .humuliProYearly)
        }
    }

    private func billingInfo(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .monthly:
            return subscriptionManager.monthlyBillingInfo(for: .humuliProMonthly)
        case .yearly:
            return subscriptionManager.annualBillingInfo(for: .humuliProYearly)
        }
    }

    private func savingsText() -> String? {
        let savings = subscriptionManager.savingsPercentage(for: .humuliProMonthly)
        guard savings > 0, selectedPlan == .yearly else { return nil }
        return "Save \(savings)% compared to monthly"
    }

    private func upgrade() async {
        guard isProcessing == false else { return }
        guard let email = await currentEmail() else {
            await MainActor.run {
                showError = true
                errorMessage = "Please sign in before upgrading."
            }
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await subscriptionManager.purchase(
                tier: selectedTier,
                duration: selectedPlan.duration,
                userEmail: email,
                onboardingViewModel: viewModel
            )
            await subscriptionManager.fetchSubscriptionInfoIfNeeded(for: email, force: true)
            await MainActor.run {
                onDismiss()
                dismiss()
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

    var featureComparisonView: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Features")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black)
                Spacer()
                Text("Free")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 60)
                Text("Pro")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 60)
            }
            .padding(.vertical, 12)

            // Feature rows - first 2 are included in both Free and Plus
            FeatureRow(name: "Food Scanning", free: true, plus: true)
            FeatureRow(name: "Personalized Workout Program", free: true, plus: true)

            // Remaining 6 features - Plus only
            FeatureRow(name: "Unlimited Food Scans", free: false, plus: true)
            FeatureRow(name: "Unlimited Workout Sessions", free: false, plus: true)
            FeatureRow(name: "Pro Food Search", free: false, plus: true)
            FeatureRow(name: "Advanced Analytics", free: false, plus: true)
            FeatureRow(name: "Scheduled Meal Logging", free: false, plus: true)
            FeatureRow(name: "Bulk Photo Logging", free: false, plus: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.97))
        )
    }
    private func usageDetail(for feature: ProFeatureGate.ProFeature?,
                             summary: UsageSummary) -> String? {
        guard let feature else { return nil }
        switch feature {
        case .foodScans, .bulkLogging, .proSearch, .scheduledLogging:
            if let detail = summary.foodScans {
                return usageText(current: detail.current, limit: detail.limit, resetAt: detail.resetAt)
            }
        case .workouts, .analytics:
            if let detail = summary.workouts {
                return usageText(current: detail.current, limit: detail.limit, resetAt: detail.resetAt)
            }
        }
        return nil
    }
    
    private func usageText(current: Int, limit: Int?, resetAt: Date?) -> String {
        var components: [String] = []
        if let limit = limit, limit >= 0 {
            components.append("Used \(current)/\(limit)")
        } else {
            components.append("Used \(current)")
        }
        if let resetAt = resetAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let relative = formatter.localizedString(for: resetAt, relativeTo: Date())
            components.append("Resets \(relative)")
        }
        return components.joined(separator: " • ")
    }
}

struct FeatureRow: View {
    let name: String
    let free: Bool
    let plus: Bool

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 15))
                .foregroundColor(.black)
            Spacer()
            Image(systemName: free ? "checkmark" : "minus")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(free ? .blue : .gray)
                .frame(width: 60)
            Image(systemName: plus ? "checkmark" : "minus")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(plus ? .blue : .gray)
                .frame(width: 60)
        }
        .padding(.vertical, 10)
    }
}
