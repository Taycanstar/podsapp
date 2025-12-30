//
//  HumuliProUpgradeSheet.swift
//  Pods
//
//  Created by Claude Code
//

import SwiftUI
import UIKit
import StoreKit

struct HumuliProUpgradeSheet: View {
    @Environment(\.dismiss) var dismiss
    let feature: ProFeatureGate.ProFeature?
    let usageSummary: UsageSummary?
    let onDismiss: () -> Void
    let titleOverride: String?
    let messageOverride: String?
    let showUsageDetail: Bool
    let allowDismiss: Bool
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isProcessing = false
    @State private var isRestoring = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var infoMessage: String?
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var viewModel: OnboardingViewModel

    init(feature: ProFeatureGate.ProFeature?,
         usageSummary: UsageSummary?,
         onDismiss: @escaping () -> Void,
         titleOverride: String? = nil,
         messageOverride: String? = nil,
         showUsageDetail: Bool = true,
         allowDismiss: Bool = true) {
        self.feature = feature
        self.usageSummary = usageSummary
        self.onDismiss = onDismiss
        self.titleOverride = titleOverride
        self.messageOverride = messageOverride
        self.showUsageDetail = showUsageDetail
        self.allowDismiss = allowDismiss
    }

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

    }
}


enum HumuliProPlanOption: String, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: return "Metryc Pro Monthly"
        case .yearly: return "Metryc Pro Yearly"
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
    @State private var isRestoring = false
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

                Button {
                    Task { await restorePurchases() }
                } label: {
                    if isRestoring {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .disabled(isProcessing || isRestoring)

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
                .disabled(isProcessing || isRestoring)

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
                    Text("Metryc Pro")
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
        viewModel.subscriptionPlan ?? subscriptionManager.subscriptionInfo?.plan ?? "Metryc Pro"
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

    private func restorePurchases() async {
        guard isRestoring == false else { return }
        guard let email = await currentEmail() else {
            await presentError("We couldn't find your account email. Please sign in again.")
            return
        }

        await MainActor.run {
            isRestoring = true
            infoMessage = nil
        }

        do {
            try await subscriptionManager.restorePurchases(userEmail: email)
            await refreshSubscription()
            await MainActor.run {
                infoMessage = "Purchases restored successfully."
            }
        } catch {
            await presentError(error.localizedDescription)
        }

        await MainActor.run {
            isRestoring = false
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
                // Header with close button (only shown if dismissible)
                HStack {
                    Spacer()
                    if allowDismiss {
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
                }

                // Icon and title
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 35))
                        .foregroundColor(.blue)

                    Text(titleOverride ?? "Metryc Pro")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)

                    VStack(spacing: 6) {
                        if showUsageDetail,
                           let usageSummary = usageSummary,
                           let detail = usageDetail(for: feature, summary: usageSummary) {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else if let messageOverride {
                            Text(messageOverride)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            Text("Unlock the complete Metryc experience.")
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

                // Redeem offer code button
                redeemCodeButton()
                    .padding(.bottom, 8)

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
                Button {
                    Task { await restorePurchases() }
                } label: {
                    if isRestoring {
                        ProgressView()
                            .padding(.top, 8)
                    } else {
                        Text("Restore Purchases")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    }
                }
                .disabled(isProcessing || isRestoring)
                .padding(.top, 8)

                if let infoMessage {
                    Text(infoMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .padding(.horizontal, 24)
                }

                Spacer().frame(height: 24)
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

    @ViewBuilder
    private func redeemCodeButton() -> some View {
        if #available(iOS 14.0, *) {
            Button {
                Task { await presentRedemptionSheet() }
            } label: {
                Text("Redeem Offer Code")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
            }
            .disabled(isProcessing)
        }
    }

    @available(iOS 14.0, *)
    private func presentRedemptionSheet() async {
        guard let email = await currentEmail() else {
            await MainActor.run {
                showError = true
                errorMessage = "Please sign in to redeem an offer code."
            }
            return
        }

        await MainActor.run {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
        // Transaction.updates listener will automatically catch the redemption
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

    private func restorePurchases() async {
        guard isRestoring == false else { return }
        guard let email = await currentEmail() else {
            await MainActor.run {
                showError = true
                errorMessage = "Please sign in before restoring purchases."
            }
            return
        }

        await MainActor.run {
            isRestoring = true
            infoMessage = nil
        }

        do {
            try await subscriptionManager.restorePurchases(userEmail: email)
            await subscriptionManager.fetchSubscriptionInfoIfNeeded(for: email, force: true)
            await MainActor.run {
                infoMessage = "Purchases restored successfully."
            }
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isRestoring = false
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
            // Feature rows - all included in Pro
            FeatureRow(name: "Slip-Up Recovery Mode", pro: true)
            FeatureRow(name: "24/7 Hands-Free Voice Coach", pro: true)
            FeatureRow(name: "1M+ Foods & Barcode Database", pro: true)
            FeatureRow(name: "Autopilot Plan Repair", pro: true)
             FeatureRow(name: "Log with Voice, Text, Photo", pro: true)
            FeatureRow(name: "Context-Aware Check-Ins", pro: true)
             FeatureRow(name: "Shame-Safe Tracking", pro: true)
             FeatureRow(name: "Personalized Workout Program", pro: true)
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
        case .agentFeatures:
            // Agent features don't have specific usage tracking
            return nil
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
    let pro: Bool

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 15))
                .foregroundColor(.black)
            Spacer()
            Image(systemName: pro ? "checkmark" : "minus")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(pro ? .blue : .gray)
                .frame(width: 60)
        }
        .padding(.vertical, 10)
    }
}
