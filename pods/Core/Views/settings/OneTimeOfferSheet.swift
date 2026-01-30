//
//  OneTimeOfferSheet.swift
//  pods
//
//  Created by Dimi Nunez on 1/29/26.
//


//
//  OneTimeOfferSheet.swift
//  Pods
//
//  One-time exit offer for users who dismiss the paywall without subscribing.
//

import SwiftUI
import StoreKit

struct OneTimeOfferSheet: View {
    @Environment(\.dismiss) var dismiss
    let onDismiss: () -> Void

    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var viewModel: OnboardingViewModel

    // One-time offer configuration
    private let originalPrice = "$79.99"
    private let offerPrice = "$7.99"
    private let monthlyEquivalent = "$0.67/month"
    private let discountPercent = "90%"
    private let offerId = "exit_offer_yearly_90off"
    private let productId = "humuli_pro_yearly"

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    Button {
                        markOfferSeen()
                        onDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                            .padding(20)
                    }
                }

                // Title
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 35))
                        .foregroundColor(.blue)

                    Text("One-Time Offer")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)

                    Text("You will never see this again")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)

                // Discount card
                VStack(spacing: 16) {
                    // Discount message with chip
                    HStack(spacing: 6) {
                        Text("Here's a")
                            .font(.system(size: 16))
                            .foregroundColor(.black)

                        Text(discountPercent)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .cornerRadius(20)

                        Text("Discount 🎁")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                    }

                    // Price display with slashed original
                    HStack(alignment: .center, spacing: 12) {
                        Text(originalPrice)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.gray)
                            .strikethrough(true, color: .gray)

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(offerPrice)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.black)

                            Text("/year")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.97))
                )
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                // Price card at bottom
                VStack(spacing: 0) {
                    // Card header
                    Text("ONE-TIME OFFER")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)

                    // Card content
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Yearly Plan")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)

                            Text("12 mo • \(originalPrice)")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        // Monthly equivalent
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(monthlyEquivalent)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black, lineWidth: 2)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // CTA Button
                Button {
                    Task { await purchaseWithOffer() }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Claim Offer 🙌")
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

                // Reassurance text
                Text("✓ No Commitment - Cancel Anytime")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.light)
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Track that the one-time offer was shown
            AnalyticsManager.shared.trackPaywallViewed(
                paywallVersion: "exit_offer_1.0",
                placement: "exit_intent",
                productsShown: [productId],
                defaultProductId: productId
            )
        }
    }

    private func purchaseWithOffer() async {
        guard !isProcessing else { return }
        guard let email = await currentEmail() else {
            await MainActor.run {
                showError = true
                errorMessage = "Please sign in before purchasing."
            }
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Purchase with promotional offer
            try await subscriptionManager.purchaseWithPromotionalOffer(
                productId: productId,
                offerId: offerId,
                userEmail: email,
                onboardingViewModel: viewModel
            )

            // Mark offer as seen and dismiss
            markOfferSeen()
            await subscriptionManager.fetchSubscriptionInfoIfNeeded(for: email, force: true)
            await MainActor.run {
                onDismiss()
                dismiss()
            }
        } catch let error as SubscriptionError {
            // If user cancelled the Apple purchase dialog, just stay on the sheet (don't show error)
            if case .userCancelled = error {
                return
            }
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

    private func markOfferSeen() {
        UserDefaults.standard.set(true, forKey: "hasSeenOneTimeOffer")
    }

    @MainActor
    private func currentEmail() -> String? {
        if !viewModel.email.isEmpty {
            return viewModel.email
        }
        if let stored = UserDefaults.standard.string(forKey: "userEmail"), !stored.isEmpty {
            return stored
        }
        return nil
    }
}

struct OfferFeatureRow: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.black)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 60)
        }
        .padding(.vertical, 10)
    }
}

// Helper to check if one-time offer should be shown
struct OneTimeOfferHelper {
    static var hasSeenOffer: Bool {
        UserDefaults.standard.bool(forKey: "hasSeenOneTimeOffer")
    }

    static var shouldShowOffer: Bool {
        !hasSeenOffer
    }

    static func markOfferSeen() {
        UserDefaults.standard.set(true, forKey: "hasSeenOneTimeOffer")
    }

    // Reset for testing
    static func resetOfferState() {
        UserDefaults.standard.removeObject(forKey: "hasSeenOneTimeOffer")
    }
}
