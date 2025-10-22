import SwiftUI
import StoreKit
import UIKit
import Combine

struct SubscriptionView: View {
    @EnvironmentObject private var viewModel: OnboardingViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.isTabBarVisible) private var isTabBarVisible

    @State private var isLoading = true
    @State private var showPricingSheet = false
    @State private var alertContent: AlertContent?
    @State private var isProcessingAction = false
    @State private var mainCTAText: String?

    private let displayedTier: SubscriptionTier = .humuliProMonthly

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("dkBg")
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading subscription info...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            if subscriptionManager.hasActiveSubscription() {
                                activeSection()
                            } else {
                                inactiveSection(in: geometry)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarTitle("Subscription", displayMode: .inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showPricingSheet) {
            PricingView(tier: displayedTier, subscriptionManager: subscriptionManager)
                .environmentObject(viewModel)
        }
        .alert(item: $alertContent) { content in
            Alert(title: Text(content.title),
                  message: Text(content.message),
                  dismissButton: .default(Text("OK")))
        }
        .onAppear {
            isTabBarVisible.wrappedValue = false
            subscriptionManager.setOnboardingViewModel(viewModel)
            Task {
                await fetchSubscriptionInfo(force: true)

                // Load CTA text with intro offer if available
                if let monthlyProduct = subscriptionManager.products.first(where: {
                    $0.id == displayedTier.productIdentifier(for: .monthly)
                }),
                let introOffer = await subscriptionManager.getIntroductoryOfferDescription(for: monthlyProduct) {
                    mainCTAText = "Try \(introOffer)"
                } else {
                    mainCTAText = "Starting at \(subscriptionManager.startingPrice(for: displayedTier))"
                }
            }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .subscriptionUpdated)
                .receive(on: RunLoop.main)
        ) { _ in
            Task { await fetchSubscriptionInfo(force: true) }
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
        }
    }

    private func fetchSubscriptionInfo(force: Bool = false) async {
        guard let email = await currentEmail() else {
            await MainActor.run {
                isLoading = false
                alertContent = AlertContent(title: "Unavailable",
                                            message: "Please sign in to manage your subscription.")
            }
            return
        }

        await subscriptionManager.fetchSubscriptionInfoIfNeeded(for: email, force: force)
        await MainActor.run {
            isLoading = false
        }
    }

    private func activeSection() -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(subscriptionManager.subscriptionInfo?.plan ?? "Humuli Pro")
                    .font(.title2)
                    .fontWeight(.bold)

                if let expiresAt = subscriptionManager.subscriptionInfo?.expiresAt {
                    Text("Renews \(formatDate(expiresAt))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let plan = subscriptionManager.subscriptionInfo?.plan,
                   let tier = SubscriptionTier(rawValue: plan) {
                    Text(subscriptionManager.monthlyBillingInfo(for: tier))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()

                Text("Included with your plan")
                    .font(.headline)

                if let plan = subscriptionManager.subscriptionInfo?.plan,
                   let tier = SubscriptionTier(rawValue: plan) {
                    ForEach(tier.features, id: \.self) { feature in
                        Label(feature, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color("mdBg"))
            .cornerRadius(15)

            Button(action: openManageSubscriptions) {
                Text("Manage in App Store")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(Color.accentColor)
                    .cornerRadius(10)
            }

            if subscriptionManager.shouldShowRenewButton() {
                actionButton(title: "Renew Subscription") {
                    await renewSubscription()
                }
            } else if subscriptionManager.isSubscriptionCancelled() == false {
                actionButton(title: "Cancel Subscription", role: .destructive) {
                    await cancelSubscription()
                }
            }

            restoreButton()

            termsFooter
        }
    }

    private func inactiveSection(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            Text(displayedTier.name)
                .font(.headline)
                .fontWeight(.bold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color("mdBg"))
                .cornerRadius(15)

            SubscriptionTierView(tier: displayedTier)
                .frame(height: geometry.size.height * 0.6)

            Button {
                showPricingSheet = true
            } label: {
                Text(mainCTAText ?? "Loading...")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }

            restoreButton()

            termsFooter
        }
    }

    private func actionButton(title: String, role: ButtonRole? = nil, action: @escaping () async -> Void) -> some View {
        Button(role: role) {
            Task { await action() }
        } label: {
            if isProcessingAction {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(role == .destructive ? .red : .accentColor)
        .disabled(isProcessingAction)
    }

    private func restoreButton() -> some View {
        Button {
            Task { await restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.bordered)
        .disabled(isProcessingAction)
    }

    private var termsFooter: some View {
        HStack(spacing: 4) {
            Text("By continuing, you agree to the")
                .foregroundColor(.secondary)
            Button("Terms") {
                if let url = URL(string: "http://humuli.com/policies/terms") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.footnote)

            Text("and")
                .foregroundColor(.secondary)

            Button("Privacy Policy") {
                if let url = URL(string: "https://humuli.com/policies/privacy-policy") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.footnote)
        }
        .font(.footnote)
        .foregroundColor(.secondary)
    }

    private func openManageSubscriptions() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    private func cancelSubscription() async {
        guard let email = await currentEmail() else { return }
        await performAction {
            try await subscriptionManager.cancelSubscription(userEmail: email)
        } successMessage: {
            return "Your subscription has been cancelled. You can continue using it until it expires."
        }
    }

    private func renewSubscription() async {
        guard let email = await currentEmail() else { return }
        await performAction {
            try await subscriptionManager.renewSubscription(userEmail: email)
        } successMessage: {
            return "Your subscription has been renewed successfully."
        }
    }

    private func restorePurchases() async {
        guard let email = await currentEmail() else {
            await MainActor.run {
                alertContent = AlertContent(title: "Restore Failed",
                                            message: "Please sign in to restore purchases.")
            }
            return
        }

        await performAction {
            try await subscriptionManager.restorePurchases(userEmail: email)
        } successMessage: {
            return "Any available purchases have been restored."
        }
    }

    private func performAction(_ action: @escaping () async throws -> Void,
                               successMessage: @escaping () -> String) async {
        guard isProcessingAction == false else { return }
        await MainActor.run { isProcessingAction = true }
        defer {
            Task { @MainActor in isProcessingAction = false }
        }

        do {
            try await action()
            await MainActor.run {
                alertContent = AlertContent(title: "Success", message: successMessage())
            }
        } catch let error as SubscriptionError {
            await MainActor.run {
                alertContent = AlertContent(title: "Error", message: error.localizedDescription)
            }
        } catch {
            await MainActor.run {
                alertContent = AlertContent(title: "Error", message: error.localizedDescription)
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

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter.fullFormatter
        guard let date = formatter.date(from: isoString) else {
            return "soon"
        }
        let output = DateFormatter()
        output.dateStyle = .medium
        return output.string(from: date)
    }
}

private struct AlertContent: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct SubscriptionTierView: View {
    let tier: SubscriptionTier
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(tier.features, id: \.self) { feature in
                HStack {
                    Text(feature)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color("mxdBg"))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0.5)
        )
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 44, 44, 44) : Color(rgb: 230, 230, 230)
    }
}

struct PricingView: View {
    let tier: SubscriptionTier
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var viewModel: OnboardingViewModel

    @State private var selectedPlan: PlanType = .yearly
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var monthlyIntroOffer: String?
    @State private var yearlyIntroOffer: String?

    enum PlanType {
        case monthly
        case yearly

        var duration: SubscriptionDuration {
            switch self {
            case .monthly: return .monthly
            case .yearly: return .yearly
            }
        }

        var title: String {
            switch self {
            case .monthly: return "Monthly plan"
            case .yearly: return "Annual plan"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text(tier.name)
                    .font(.title)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    PricingOptionView(
                        title: PlanType.yearly.title,
                        price: subscriptionManager.annualPrice(for: tier),
                        savings: savingsDescription(),
                        billingInfo: subscriptionManager.annualBillingInfo(for: tier),
                        introOffer: yearlyIntroOffer,
                        isSelected: selectedPlan == .yearly
                    ) {
                        selectedPlan = .yearly
                    }

                    PricingOptionView(
                        title: PlanType.monthly.title,
                        price: subscriptionManager.monthlyPrice(for: tier),
                        billingInfo: subscriptionManager.monthlyBillingInfo(for: tier),
                        introOffer: monthlyIntroOffer,
                        isSelected: selectedPlan == .monthly
                    ) {
                        selectedPlan = .monthly
                    }
                }

                Button {
                    Task { await purchaseSelectedPlan() }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text(purchaseButtonTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                }
                .disabled(isProcessing)

                TermsFooter()
            }
            .padding()
            .navigationBarTitle("Choose a Plan", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                Task {
                    // Load intro offer descriptions for both plans
                    if let monthlyProduct = subscriptionManager.products.first(where: {
                        $0.id == tier.productIdentifier(for: .monthly)
                    }) {
                        monthlyIntroOffer = await subscriptionManager.getIntroductoryOfferDescription(for: monthlyProduct)
                    }

                    if let yearlyProduct = subscriptionManager.products.first(where: {
                        $0.id == tier.productIdentifier(for: .yearly)
                    }) {
                        yearlyIntroOffer = await subscriptionManager.getIntroductoryOfferDescription(for: yearlyProduct)
                    }
                }
            }
        }
    }

    private var purchaseButtonTitle: String {
        let introOffer = selectedPlan == .yearly ? yearlyIntroOffer : monthlyIntroOffer
        if let intro = introOffer {
            return "Start \(intro)"
        } else {
            let price = selectedPlan == .yearly
                ? subscriptionManager.annualPrice(for: tier)
                : subscriptionManager.monthlyPrice(for: tier)
            return "Subscribe for \(price)"
        }
    }

    private func savingsDescription() -> String? {
        let percentage = subscriptionManager.savingsPercentage(for: tier)
        guard percentage > 0 else { return nil }
        return "SAVE \(percentage)%"
    }

    private func purchaseSelectedPlan() async {
        guard isProcessing == false else { return }
        guard let email = resolvedEmail else {
            showError = true
            errorMessage = "Please sign in before purchasing."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await subscriptionManager.purchase(
                tier: tier,
                duration: selectedPlan.duration,
                userEmail: email,
                onboardingViewModel: viewModel
            )
            await subscriptionManager.fetchSubscriptionInfoIfNeeded(for: email, force: true)
            presentationMode.wrappedValue.dismiss()
        } catch let error as SubscriptionError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private var resolvedEmail: String? {
        if viewModel.email.isEmpty == false {
            return viewModel.email
        }
        if let stored = UserDefaults.standard.string(forKey: "userEmail"), stored.isEmpty == false {
            return stored
        }
        return nil
    }
}

struct PricingOptionView: View {
    let title: String
    let price: String
    var savings: String? = nil
    let billingInfo: String
    var introOffer: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()

                    // Show intro offer badge prominently
                    if let introOffer = introOffer {
                        Text(introOffer)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                    }

                    Text(price)
                        .font(.headline)
                }

                if let savings = savings {
                    Text(savings)
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                }

                Text(billingInfo)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Show trial details below
                if let introOffer = introOffer {
                    Text("Then \(price) after trial")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Auto-renews unless cancelled 24h before trial ends")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("mdBg"))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TermsFooter: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("By subscribing, you agree to our")
                .foregroundColor(.secondary)
            Button("Terms") {
                if let url = URL(string: "http://humuli.com/policies/terms") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.footnote)

            Text("and")
                .foregroundColor(.secondary)

            Button("Privacy Policy") {
                if let url = URL(string: "https://humuli.com/policies/privacy-policy") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.footnote)
        }
        .font(.footnote)
        .foregroundColor(.secondary)
    }
}
