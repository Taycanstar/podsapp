//
//  CoachCardView.swift
//  pods
//
//  Created by Dimi Nunez on 12/28/25.
//


import SwiftUI

/// A home card component for coach interventions.
/// Displayed on the home screen when the backend has a proactive message.
/// Tapping anywhere opens the agent chat to continue the conversation.
struct CoachCardView: View {
    let card: NetworkManager.CoachHomeCard
    let onTap: () -> Void

    @State private var hasLoggedImpression = false

    /// Check if this is a weekly check-in card
    private var isCheckinCard: Bool {
        card.action == "HOME_CARD_CHECKIN"
    }

    /// Extract headline from JSON content
    private var headlineText: String? {
        if let data = card.content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let headline = json["headline"] as? String {
            return headline
        }
        return nil
    }

    /// Extract body from JSON content or use raw content
    private var bodyText: String {
        if let data = card.content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let body = json["body"] as? String {
            return body
        }
        return card.content
    }

    var body: some View {
        Button {
            EventTracker.shared.trackHomeCardTap(interventionId: card.interventionId)
            onTap()
        } label: {
            if isCheckinCard {
                checkinCardContent
            } else {
                standardCardContent
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if !hasLoggedImpression {
                hasLoggedImpression = true
                EventTracker.shared.trackHomeCardImpression(interventionId: card.interventionId)
            }
        }
    }

    /// Standard coach card layout (for behavioral interventions)
    private var standardCardContent: some View {
        Text(bodyText)
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color("containerbg"))
            .cornerRadius(28)
    }

    /// Check-in card layout with headline, body, and CTA
    private var checkinCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let headline = headlineText {
                Text(headline)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Text(bodyText)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            HStack {
                Spacer()
                Text("Check in")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color("containerbg"))
        .cornerRadius(28)
    }
}

#Preview {
    VStack(spacing: 16) {
        CoachCardView(
            card: NetworkManager.CoachHomeCard(
                interventionId: "test-123",
                content: "{\"headline\": \"This isn't failure\", \"body\": \"One meal doesn't undo your progress. Tap and I'll help you choose a low-stress next move.\"}",
                action: "HOME_CARD_SUPPORT",
                userState: "POST_SLIPUP",
                createdAt: "2025-01-15T10:00:00Z"
            ),
            onTap: { print("Tapped") }
        )
        .padding(.horizontal)

        CoachCardView(
            card: NetworkManager.CoachHomeCard(
                interventionId: "test-456",
                content: "You've been away for a few days. No pressure—just tap if you want to ease back in.",
                action: "HOME_CARD_MINIMAL",
                userState: "AT_RISK",
                createdAt: "2025-01-15T10:00:00Z"
            ),
            onTap: { print("Tapped") }
        )
        .padding(.horizontal)

        // Weekly check-in card preview
        CoachCardView(
            card: NetworkManager.CoachHomeCard(
                interventionId: "test-789",
                content: "{\"headline\": \"Weekly Check-In\", \"body\": \"Update your weight and adjust your calorie targets for next week.\"}",
                action: "HOME_CARD_CHECKIN",
                userState: "NEUTRAL",
                createdAt: "2025-01-15T10:00:00Z"
            ),
            onTap: { print("Check-in tapped") }
        )
        .padding(.horizontal)
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
