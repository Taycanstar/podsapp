//
//  AnalyticsProUpgradeSheet.swift
//  pods
//
//  Created by Dimi Nunez on 10/21/25.
//

import SwiftUI

struct AnalyticsProUpgradeSheet: View {
    let usageSummary: UsageSummary?
    let onDismiss: () -> Void

    private let headline = "Get Advanced Analytics with Pro"

    var body: some View {
        HumuliProUpgradeSheet(
            feature: .analytics,
            usageSummary: usageSummary,
            onDismiss: onDismiss,
            titleOverride: headline,
            messageOverride: nil,
            showUsageDetail: false
        )
    }
}
