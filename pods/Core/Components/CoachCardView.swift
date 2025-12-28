//
//  CoachCardView.swift
//  pods
//
//  Created by Dimi Nunez on 12/28/25.
//


import SwiftUI

/// A home card component for coach interventions.
/// Displayed on the home screen when the backend has a proactive message.
struct CoachCardView: View {
    let card: NetworkManager.CoachHomeCard
    let onOpenChat: () -> Void
    let onDismiss: () -> Void

    @State private var hasLoggedImpression = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, title, and dismiss button
            HStack {
                // Coach icon
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)

                Text("Coach")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                        .padding(6)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }

            // Message content (3 line limit)
            Text(card.content)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Open Chat button
            Button {
                // Track the tap event
                EventTracker.shared.trackHomeCardTap(interventionId: card.interventionId)
                onOpenChat()
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 13, weight: .medium))
                    Text("Open Chat")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(20)
            }
        }
        .padding(16)
        .background(Color("containerbg"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 2)
        .onAppear {
            // Log impression event once when card appears
            if !hasLoggedImpression {
                hasLoggedImpression = true
                EventTracker.shared.trackHomeCardImpression(interventionId: card.interventionId)
            }
        }
    }
}

#Preview {
    VStack {
        CoachCardView(
            card: NetworkManager.CoachHomeCard(
                interventionId: "test-123",
                content: "I noticed you've been making great progress lately! Would you like to chat about your goals for this week?",
                action: "HOME_CARD_SUPPORT",
                userState: "NEUTRAL",
                createdAt: "2025-01-15T10:00:00Z"
            ),
            onOpenChat: { print("Open chat") },
            onDismiss: { print("Dismissed") }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
