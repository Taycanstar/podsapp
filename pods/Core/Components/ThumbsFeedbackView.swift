//
//  ThumbsFeedbackView.swift
//  pods
//
//  Created by Dimi Nunez on 12/28/25.
//


import SwiftUI

/// A thumbs up/down feedback component for coach messages.
/// Allows users to rate coach interventions for policy learning.
struct ThumbsFeedbackView: View {
    let interventionId: String
    @State private var currentRating: Int?
    @State private var isSubmitting = false
    var onFeedbackSubmitted: (() -> Void)?

    init(interventionId: String, initialRating: Int? = nil, onFeedbackSubmitted: (() -> Void)? = nil) {
        self.interventionId = interventionId
        self._currentRating = State(initialValue: initialRating)
        self.onFeedbackSubmitted = onFeedbackSubmitted
    }

    /// Thumbs up button - call this for inline use in a parent HStack
    var thumbsUpButton: some View {
        Button {
            submitRating(1)
        } label: {
            Image(systemName: currentRating == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(.systemGray))
        }
        .disabled(isSubmitting)
    }

    /// Thumbs down button - call this for inline use in a parent HStack
    var thumbsDownButton: some View {
        Button {
            submitRating(-1)
        } label: {
            Image(systemName: currentRating == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(.systemGray))
        }
        .disabled(isSubmitting)
    }

    var body: some View {
        HStack(spacing: 16) {
            thumbsUpButton
            thumbsDownButton
        }
    }

    private func submitRating(_ rating: Int) {
        guard !isSubmitting else { return }

        // Toggle if tapping same rating (allows un-rating)
        let newRating = (currentRating == rating) ? nil : rating

        isSubmitting = true

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Optimistic UI update
        currentRating = newRating

        // Submit to backend
        Task {
            do {
                if let newRating = newRating {
                    try await CoachFeedbackAPI.rateIntervention(
                        interventionId: interventionId,
                        rating: newRating
                    )
                    // Notify parent to show toast
                    await MainActor.run {
                        onFeedbackSubmitted?()
                    }
                }
                await MainActor.run {
                    isSubmitting = false
                }
            } catch {
                print("[ThumbsFeedback] Failed to submit rating: \(error)")
                // Revert on failure
                await MainActor.run {
                    currentRating = currentRating == newRating ? nil : currentRating
                    isSubmitting = false
                }
            }
        }
    }
}

/// API helper for coach feedback
enum CoachFeedbackAPI {
    static func rateIntervention(interventionId: String, rating: Int) async throws {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            throw CoachFeedbackError.notAuthenticated
        }

        guard let url = URL(string: "\(NetworkManager.baseURL)/api/v1/coach/interventions/\(interventionId)/rate") else {
            throw CoachFeedbackError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_email": userEmail,
            "rating": rating,
            "source": "ios_chat"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CoachFeedbackError.serverError
        }
    }
}

enum CoachFeedbackError: Error {
    case notAuthenticated
    case invalidURL
    case serverError
}

/// Inline version that renders both thumbs buttons as a Group (no wrapper)
/// for use inside a parent HStack. The .id() modifier on this view
/// ensures SwiftUI preserves the @State across parent rebuilds.
struct ThumbsFeedbackInlineView: View {
    let interventionId: String
    @State private var currentRating: Int?
    @State private var isSubmitting = false
    var onFeedbackSubmitted: (() -> Void)?

    init(interventionId: String, initialRating: Int? = nil, onFeedbackSubmitted: (() -> Void)? = nil) {
        self.interventionId = interventionId
        self._currentRating = State(initialValue: initialRating)
        self.onFeedbackSubmitted = onFeedbackSubmitted
    }

    var body: some View {
        Group {
            // Thumbs up
            Button {
                submitRating(1)
            } label: {
                Image(systemName: currentRating == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.systemGray))
            }
            .disabled(isSubmitting)

            // Thumbs down
            Button {
                submitRating(-1)
            } label: {
                Image(systemName: currentRating == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.systemGray))
            }
            .disabled(isSubmitting)
        }
    }

    private func submitRating(_ rating: Int) {
        guard !isSubmitting else { return }

        // Toggle if tapping same rating (allows un-rating)
        let newRating = (currentRating == rating) ? nil : rating

        isSubmitting = true

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Optimistic UI update
        currentRating = newRating

        // Submit to backend
        Task {
            do {
                if let newRating = newRating {
                    try await CoachFeedbackAPI.rateIntervention(
                        interventionId: interventionId,
                        rating: newRating
                    )
                    // Notify parent to show toast
                    await MainActor.run {
                        onFeedbackSubmitted?()
                    }
                }
                await MainActor.run {
                    isSubmitting = false
                }
            } catch {
                print("[ThumbsFeedback] Failed to submit rating: \(error)")
                // Revert on failure
                await MainActor.run {
                    currentRating = currentRating == newRating ? nil : currentRating
                    isSubmitting = false
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ThumbsFeedbackView(interventionId: "test-id", initialRating: nil)
        ThumbsFeedbackView(interventionId: "test-id", initialRating: 1)
        ThumbsFeedbackView(interventionId: "test-id", initialRating: -1)
    }
    .padding()
}
