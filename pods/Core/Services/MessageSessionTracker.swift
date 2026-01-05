//
//  MessageSessionTracker.swift
//  pods
//
//  Created by Dimi Nunez on 1/5/26.
//


//
//  MessageSessionTracker.swift
//  pods
//
//  Created by Dimi Nunez on 1/4/26.
//

//
//  MessageSessionTracker.swift
//  pods
//
//  Tracks user message counts per session and emits a single
//  `session_message_count` event when each session ends.
//
//  Session lifecycle:
//  - Starts on first `user_message_sent` call
//  - Ends when app goes to background OR 30 min inactivity
//  - Crash recovery: persisted data is flushed on next launch
//

import Foundation
import UIKit
import Mixpanel

/// Tracks user message counts per session for analytics.
/// Emits exactly one `session_message_count` event per session.
final class MessageSessionTracker {

    // MARK: - Singleton

    static let shared = MessageSessionTracker()

    // MARK: - Constants

    /// Session timeout duration (30 minutes to match Mixpanel default)
    private static let sessionTimeoutInterval: TimeInterval = 30 * 60

    /// UserDefaults key for persisted session data (crash recovery)
    private static let persistenceKey = "MessageSessionTracker.pendingSession"

    // MARK: - Session State

    /// Current session ID (UUID)
    private var sessionId: String?

    /// Count of user messages in current session
    private var messagesCount: Int = 0

    /// Timestamp when session started
    private var sessionStartTime: Date?

    /// Timestamp of last user message
    private var lastMessageTime: Date?

    /// Flag to prevent double-flush
    private var isFlushing = false

    /// Serial queue for thread safety
    private let queue = DispatchQueue(label: "com.metryc.messagesessiontracker", qos: .utility)

    /// Timer for inactivity timeout
    private var inactivityTimer: Timer?

    // MARK: - Initialization

    private init() {
        // Restore any pending session from a prior crash
        restorePendingSession()

        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    deinit {
        inactivityTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    /// Initialize the tracker early to ensure notification observers are registered.
    /// Call this from AppDelegate or podsApp on launch.
    func initialize() {
        // No-op, but accessing the singleton registers notifications
        print("[MessageSessionTracker] Initialized")
    }

    /// Called every time `user_message_sent` is tracked.
    /// Increments the session message count.
    func recordUserMessage() {
        queue.async { [weak self] in
            self?._recordUserMessage()
        }
    }

    // MARK: - Internal Logic

    private func _recordUserMessage() {
        let now = Date()

        // Check if we need to start a new session
        if sessionId == nil {
            startNewSession(at: now)
        } else if let lastTime = lastMessageTime,
                  now.timeIntervalSince(lastTime) >= Self.sessionTimeoutInterval {
            // Inactivity timeout exceeded - flush old session, start new one
            _flushSession(endTime: lastTime.addingTimeInterval(Self.sessionTimeoutInterval))
            startNewSession(at: now)
        }

        // Increment message count
        messagesCount += 1
        lastMessageTime = now

        // Persist for crash recovery
        persistSession()

        // Reset inactivity timer
        resetInactivityTimer()

        print("[MessageSessionTracker] Recorded message #\(messagesCount) for session \(sessionId ?? "nil")")
    }

    private func startNewSession(at time: Date) {
        sessionId = UUID().uuidString
        messagesCount = 0
        sessionStartTime = time
        lastMessageTime = time

        print("[MessageSessionTracker] Started new session: \(sessionId ?? "nil")")
    }

    // MARK: - Session Flushing

    /// Flush the current session and emit `session_message_count` event
    private func flushSession(endTime: Date? = nil) {
        queue.async { [weak self] in
            self?._flushSession(endTime: endTime)
        }
    }

    private func _flushSession(endTime: Date? = nil) {
        // Capture all values FIRST before any guards or state changes
        let sid = sessionId
        let count = messagesCount
        let startTime = sessionStartTime
        let lastTime = lastMessageTime

        print("[MessageSessionTracker] _flushSession called - sessionId: \(sid ?? "nil"), count: \(count), isFlushing: \(isFlushing)")

        guard !isFlushing else {
            print("[MessageSessionTracker] Already flushing, skipping")
            return
        }
        guard let sid = sid, count > 0 else {
            // No session or no messages - nothing to flush
            print("[MessageSessionTracker] No session or no messages (sid: \(sid ?? "nil"), count: \(count)) - clearing")
            clearSession()
            return
        }
        guard let sessionStart = startTime else {
            print("[MessageSessionTracker] No start time - clearing")
            clearSession()
            return
        }

        isFlushing = true

        let end = endTime ?? lastTime ?? Date()
        let durationMs = Int(end.timeIntervalSince(sessionStart) * 1000)

        print("[MessageSessionTracker] Flushing session \(sid) with \(count) messages, duration: \(durationMs)ms")

        // Clear session state BEFORE emitting event
        clearSession()
        isFlushing = false

        // Emit the event on main thread
        DispatchQueue.main.async {
            AnalyticsManager.shared.trackSessionMessageCount(
                sessionId: sid,
                messagesCount: count,
                sessionStartTs: sessionStart,
                sessionEndTs: end,
                sessionDurationMs: durationMs
            )
        }
    }

    private func clearSession() {
        sessionId = nil
        messagesCount = 0
        sessionStartTime = nil
        lastMessageTime = nil
        clearPersistedSession()
    }

    // MARK: - Inactivity Timer

    private func resetInactivityTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.inactivityTimer?.invalidate()
            self?.inactivityTimer = Timer.scheduledTimer(
                withTimeInterval: Self.sessionTimeoutInterval,
                repeats: false
            ) { [weak self] _ in
                print("[MessageSessionTracker] Inactivity timeout - flushing session")
                self?.flushSession()
            }
        }
    }

    // MARK: - App Lifecycle

    @objc private func appWillResignActive() {
        // App going to inactive state - persist but don't flush yet
        queue.async { [weak self] in
            self?.persistSession()
        }
    }

    @objc private func appDidEnterBackground() {
        // App going to background - flush the session with background task protection
        print("[MessageSessionTracker] App entered background - flushing session")

        // Request background time to ensure the event is sent before app is suspended
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "FlushSessionMessageCount") {
            // Cleanup if we run out of time
            print("[MessageSessionTracker] Background task expired")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        // Flush synchronously on the queue to capture state before app suspends
        queue.async { [weak self] in
            self?._flushSession()

            // Force Mixpanel to send events immediately, then end the background task
            DispatchQueue.main.async {
                print("[MessageSessionTracker] Forcing Mixpanel flush")
                Mixpanel.mainInstance().flush()

                // Give Mixpanel time to send the network request
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if backgroundTaskID != .invalid {
                        print("[MessageSessionTracker] Ending background task")
                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                        backgroundTaskID = .invalid
                    }
                }
            }
        }
    }

    @objc private func appWillTerminate() {
        // App terminating - flush synchronously
        print("[MessageSessionTracker] App will terminate - flushing session")
        queue.sync { [weak self] in
            self?._flushSession()
        }
        // Force Mixpanel to send immediately
        Mixpanel.mainInstance().flush()
    }

    // MARK: - Crash Recovery Persistence

    /// Persisted session structure
    private struct PersistedSession: Codable {
        let sessionId: String
        let messagesCount: Int
        let sessionStartTs: Date
        let lastMessageTs: Date
    }

    private func persistSession() {
        guard let sid = sessionId,
              let startTime = sessionStartTime,
              let lastTime = lastMessageTime else {
            return
        }

        let data = PersistedSession(
            sessionId: sid,
            messagesCount: messagesCount,
            sessionStartTs: startTime,
            lastMessageTs: lastTime
        )

        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: Self.persistenceKey)
        }
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: Self.persistenceKey)
    }

    private func restorePendingSession() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey) else {
            print("[MessageSessionTracker] No pending session to restore")
            return
        }

        guard let persisted = try? JSONDecoder().decode(PersistedSession.self, from: data) else {
            print("[MessageSessionTracker] Failed to decode pending session - clearing stale data")
            clearPersistedSession()
            return
        }

        // Clear the persisted data first
        clearPersistedSession()

        print("[MessageSessionTracker] Found pending session: id=\(persisted.sessionId), count=\(persisted.messagesCount)")

        // Only emit if there were messages
        guard persisted.messagesCount > 0 else {
            print("[MessageSessionTracker] Pending session has 0 messages - skipping")
            return
        }

        print("[MessageSessionTracker] Recovered pending session \(persisted.sessionId) with \(persisted.messagesCount) messages")

        // Calculate duration - end time is the last message time
        let durationMs = Int(persisted.lastMessageTs.timeIntervalSince(persisted.sessionStartTs) * 1000)

        // Emit the event for the crashed session
        DispatchQueue.main.async {
            AnalyticsManager.shared.trackSessionMessageCount(
                sessionId: persisted.sessionId,
                messagesCount: persisted.messagesCount,
                sessionStartTs: persisted.sessionStartTs,
                sessionEndTs: persisted.lastMessageTs,
                sessionDurationMs: durationMs
            )
        }
    }
}
