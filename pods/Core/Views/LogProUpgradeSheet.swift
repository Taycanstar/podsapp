//
//  WorkoutUpgradeSheet.swift
//  Pods
//
//  Created by Codex on 10/15/25.
//

import SwiftUI

struct LogProUpgradeSheet: View {
    let usageSummary: UsageSummary?
    let onDismiss: () -> Void

    private let headline = "Get Unlimited Food Scans with Pro"

    var body: some View {
        HumuliProUpgradeSheet(
            feature: .workouts,
            usageSummary: nil,
            onDismiss: onDismiss,
            titleOverride: headline,
            messageOverride: nil,
            showUsageDetail: false
        )
    }
}


