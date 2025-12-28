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
        .buttonStyle(.plain)
        .onAppear {
            if !hasLoggedImpression {
                hasLoggedImpression = true
                EventTracker.shared.trackHomeCardImpression(interventionId: card.interventionId)
            }
        }
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
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
