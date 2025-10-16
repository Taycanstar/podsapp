//
//  WorkoutUpgradeSheet.swift
//  Pods
//
//  Created by Codex on 10/15/25.
//

import SwiftUI

struct WorkoutUpgradeSheet: View {
    let usageSummary: UsageSummary?
    let onDismiss: () -> Void

    private let headline = "Get Unlimited Workouts with Pro"

    var body: some View {
        HumuliProUpgradeSheet(
            feature: .workouts,
            usageSummary: usageSummary,
            onDismiss: onDismiss,
            titleOverride: headline,
            messageOverride: nil,
            showUsageDetail: false
        )
    }
}

#Preview {
    WorkoutUpgradeSheet(usageSummary: nil, onDismiss: {})
        .environmentObject(SubscriptionManager())
        .environmentObject(OnboardingViewModel())
}
