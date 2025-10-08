//
//  HumuliProUpgradeSheet.swift
//  Pods
//
//  Created by Claude Code
//

import SwiftUI

struct HumuliProUpgradeSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: SubscriptionPlan = .yearly

    enum SubscriptionPlan: String, CaseIterable, Identifiable {
        case monthly
        case yearly

        var id: String { rawValue }

        var name: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }

        var displayPrice: String {
            switch self {
            case .monthly: return "$19.99/month"
            case .yearly: return "$8.00/month"
            }
        }

        var billingSubtitle: String? {
            switch self {
            case .monthly: return nil
            case .yearly: return "$95.99 billed annually"
            }
        }

        var actualPrice: String {
            switch self {
            case .monthly: return "$19.99"
            case .yearly: return "$95.99"
            }
        }

        var savings: Int {
            switch self {
            case .monthly: return 0
            case .yearly: return 60
            }
        }

        var upgradeButtonText: String {
            switch self {
            case .monthly: return "Upgrade for $19.99 per month"
            case .yearly: return "Upgrade for $95.99 per year"
            }
        }

        var renewalText: String {
            switch self {
            case .monthly: return "Auto-renews monthly. Cancel anytime."
            case .yearly: return "Auto-renews yearly. Cancel anytime."
            }
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

                    Text("Get more access with advanced intelligence\nand agents.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 20)

                // Plan picker
                Picker("Subscription Plan", selection: $selectedPlan) {
                    Text("Monthly").tag(SubscriptionPlan.monthly)
                    Text("Yearly").tag(SubscriptionPlan.yearly)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                // Feature comparison table
                featureComparisonView
                    .padding(.horizontal, 24)

                Spacer()

                // Single upgrade button
                Button {
                    // For now, just dismiss (no purchase flow)
                    dismiss()
                } label: {
                    Text(selectedPlan.upgradeButtonText)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .cornerRadius(36)
                }
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

