//
//  EventTracker.swift
//  pods
//
//  Created by Dimi Nunez on 12/28/25.
//


import Foundation
import UIKit

/// Tracks user events for coach intervention policy learning.
/// Events are queued in memory and batch-sent to the backend periodically.
final class EventTracker {
    static let shared = EventTracker()

    private var pendingEvents: [[String: Any]] = []
    private let queue = DispatchQueue(label: "com.metryc.eventtracker", qos: .utility)
    private var flushTimer: Timer?
    private let flushInterval: TimeInterval = 30  // Flush every 30 seconds

    private init() {
        startFlushTimer()

        // Flush on app background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    deinit {
        flushTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Event Types

    /// Track app becoming active (foregrounded)
    func trackAppOpen() {
        track(eventType: "app_open")
    }

    /// Track when user opens chat from a coach message
    func trackCoachMessageOpenChat(interventionId: String?) {
        track(eventType: "coach_message_open_chat", interventionId: interventionId)
    }

    /// Track when a home card is displayed to the user
    func trackHomeCardImpression(interventionId: String) {
        track(eventType: "home_card_impression", interventionId: interventionId)
    }

    /// Track when user taps a home card
    func trackHomeCardTap(interventionId: String) {
        track(eventType: "home_card_tap", interventionId: interventionId)
    }

    // MARK: - Core Tracking

    private func track(
        eventType: String,
        interventionId: String? = nil,
        metadata: [String: Any] = [:]
    ) {
        let event: [String: Any] = [
            "event_type": eventType,
            "event_ts": ISO8601DateFormatter().string(from: Date()),
            "intervention_id": interventionId as Any,
            "tz_identifier": TimeZone.current.identifier,
            "metadata": metadata
        ]

        queue.async { [weak self] in
            self?.pendingEvents.append(event)
            print("[EventTracker] Queued event: \(eventType)")
        }
    }

    // MARK: - Timer

    private func startFlushTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.flushTimer = Timer.scheduledTimer(
                withTimeInterval: self.flushInterval,
                repeats: true
            ) { [weak self] _ in
                self?.flush()
            }
        }
    }

    @objc private func appDidEnterBackground() {
        flush()
    }

    // MARK: - Flush

    /// Send all pending events to the backend
    func flush() {
        queue.async { [weak self] in
            guard let self = self, !self.pendingEvents.isEmpty else { return }

            let eventsToSend = self.pendingEvents
            self.pendingEvents = []

            print("[EventTracker] Flushing \(eventsToSend.count) events")

            Task {
                do {
                    try await self.sendEvents(eventsToSend)
                    print("[EventTracker] Successfully sent \(eventsToSend.count) events")
                } catch {
                    print("[EventTracker] Failed to send events: \(error)")
                    // Re-add failed events to queue for retry
                    self.queue.async {
                        self.pendingEvents.insert(contentsOf: eventsToSend, at: 0)
                    }
                }
            }
        }
    }

    private func sendEvents(_ events: [[String: Any]]) async throws {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail"),
              !userEmail.isEmpty else {
            throw EventTrackerError.notAuthenticated
        }

        guard let url = URL(string: "\(NetworkManager.baseURL)/api/v1/events/batch") else {
            throw EventTrackerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_email": userEmail,
            "events": events
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EventTrackerError.serverError
        }
    }
}

enum EventTrackerError: Error {
    case notAuthenticated
    case invalidURL
    case serverError
}
