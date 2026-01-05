//
//  AnalyticsManager.swift
//  pods
//
//  Created by Dimi Nunez on 12/13/25.
//


import Foundation
import Mixpanel
import UIKit
#if canImport(MixpanelSessionReplay)
import MixpanelSessionReplay
#endif

/// Centralized analytics manager for standardized event tracking.
/// Provides consistent event naming, property enrichment, and request ID correlation
/// between iOS frontend and Django backend.
final class AnalyticsManager {

    // MARK: - Singleton

    static let shared = AnalyticsManager()

    private init() {}

    // MARK: - Properties

    /// Current request ID for correlation with backend events
    private(set) var currentRequestId: String?

    /// User ID for tracking (set after authentication)
    private var userId: String?

    /// Device ID for cross-device tracking
    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    /// App version from bundle
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    /// Current environment
    private var environment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }

    // MARK: - Request ID Management

    /// Generates a new request ID for tracking a user action through the system.
    /// Call this at the start of any user-initiated action that will call the backend.
    @discardableResult
    func generateRequestId() -> String {
        let requestId = UUID().uuidString
        currentRequestId = requestId
        return requestId
    }

    /// Clears the current request ID after an action completes.
    func clearRequestId() {
        currentRequestId = nil
    }

    // MARK: - Identity Management

    /// Identifies the user after authentication.
    /// - Parameters:
    ///   - userId: The user's unique ID (typically their UUID from backend)
    ///   - email: User's email (optional, for Mixpanel people profile)
    ///   - name: User's name (optional, for Mixpanel people profile)
    func identify(userId: String, email: String? = nil, name: String? = nil) {
        self.userId = userId
        Mixpanel.mainInstance().identify(distinctId: userId)

        var properties: [String: MixpanelType] = [:]
        if let email = email {
            properties["$email"] = email
        }
        if let name = name {
            properties["$name"] = name
        }
        if !properties.isEmpty {
            Mixpanel.mainInstance().people.set(properties: properties)
        }

        #if canImport(MixpanelSessionReplay)
        MPSessionReplay.getInstance()?.identify(distinctId: userId)
        #endif
    }

    /// Resets identity on logout.
    func reset() {
        userId = nil
        currentRequestId = nil
        Mixpanel.mainInstance().reset()

        #if canImport(MixpanelSessionReplay)
        let newDistinctId = Mixpanel.mainInstance().distinctId
        MPSessionReplay.getInstance()?.identify(distinctId: newDistinctId)
        #endif
    }

    // MARK: - Base Properties

    /// Builds base properties included with every event.
    private func baseProperties() -> [String: MixpanelType] {
        var props: [String: MixpanelType] = [
            "environment": environment,
            "source": "ios",
            "platform": "iOS",
            "app_version": appVersion,
            "device_id": deviceId,
            "auth_state": userId != nil ? "authenticated" : "anonymous"
        ]

        if let requestId = currentRequestId {
            props["request_id"] = requestId
        }

        if let userId = userId {
            props["user_id"] = userId
        }

        return props
    }

    // MARK: - Error Sanitization

    /// Sanitizes error messages to remove potential PII before logging.
    /// - Parameters:
    ///   - error: The error to sanitize
    ///   - maxLength: Maximum length of returned string
    /// - Returns: Sanitized error message
    func sanitizeError(_ error: Error, maxLength: Int = 200) -> String {
        var message = error.localizedDescription

        // Remove email patterns
        let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        message = message.replacingOccurrences(
            of: emailPattern,
            with: "[EMAIL]",
            options: .regularExpression
        )

        // Remove phone number patterns (10+ digit sequences)
        let phonePattern = "\\b\\d{10,}\\b"
        message = message.replacingOccurrences(
            of: phonePattern,
            with: "[NUMBER]",
            options: .regularExpression
        )

        // Truncate if needed
        if message.count > maxLength {
            message = String(message.prefix(maxLength - 3)) + "..."
        }

        return message
    }

    // MARK: - Generic Tracking

    /// Tracks an event with automatic property enrichment.
    /// - Parameters:
    ///   - event: Event name
    ///   - properties: Additional properties to include
    func track(_ event: String, properties: [String: MixpanelType]? = nil) {
        var mergedProps = baseProperties()
        if let properties = properties {
            for (key, value) in properties {
                mergedProps[key] = value
            }
        }
        Mixpanel.mainInstance().track(event: event, properties: mergedProps)
    }

    // MARK: - Request Headers

    /// Returns headers to include with network requests for tracking correlation.
    var requestHeaders: [String: String] {
        var headers: [String: String] = [
            "X-App-Version": appVersion,
            "X-Platform": "iOS",
            "X-Device-ID": deviceId
        ]

        if let requestId = currentRequestId {
            headers["X-Request-ID"] = requestId
        }

        return headers
    }

    // MARK: - Signup Events

    func trackSignupUIOpened() {
        track("signup_ui_opened")
    }

    func trackSignupSubmitTapped(method: String) {
        track("signup_submit_tapped", properties: ["signup_method": method])
    }

    func trackSignupClientError(method: String, error: Error) {
        track("signup_client_error", properties: [
            "signup_method": method,
            "error_message": sanitizeError(error)
        ])
    }

    // MARK: - Food Logging Events

    func trackLogUIOpened(modality: String) {
        track("log_ui_opened", properties: ["modality": modality])
    }

    func trackLogSubmitTapped(modality: String) {
        track("log_submit_tapped", properties: ["modality": modality])
    }

    func trackLogClientError(modality: String, errorStage: String, error: Error) {
        track("log_client_error", properties: [
            "modality": modality,
            "error_stage": errorStage,
            "error_message": sanitizeError(error)
        ])
    }

    // MARK: - Workout Events

    func trackWorkoutUIOpened(source: String) {
        track("workout_ui_opened", properties: ["workout_source": source])
    }

    func trackWorkoutSubmitTapped(source: String, workoutType: String) {
        track("workout_submit_tapped", properties: [
            "workout_source": source,
            "workout_type": workoutType
        ])
    }

    func trackWorkoutClientError(source: String, errorStage: String, error: Error) {
        track("workout_client_error", properties: [
            "workout_source": source,
            "error_stage": errorStage,
            "error_message": sanitizeError(error)
        ])
    }

    // MARK: - Subscription Events

    func trackPaywallViewed(variant: String = "default") {
        track("paywall_viewed", properties: ["paywall_variant": variant])
    }

    func trackUpgradeTapped(plan: String) {
        track("upgrade_tapped", properties: ["plan": plan])
    }

    func trackCheckoutCancelled(plan: String) {
        track("checkout_cancelled", properties: ["plan": plan])
    }

    // MARK: - Onboarding Events

    /// Tracks when a user completes the onboarding flow.
    /// - Parameters:
    ///   - goalType: The user's fitness goal (cut/lean_bulk/recomp)
    ///   - durationMs: Time spent in onboarding flow in milliseconds
    ///   - onboardingVersion: Version of the onboarding flow (defaults to "1.0")
    func trackOnboardingCompleted(goalType: String, durationMs: Int, onboardingVersion: String = "1.0") {
        track("onboarding_completed", properties: [
            "goal_type": goalType,
            "onboarding_duration_ms": durationMs,
            "onboarding_version": onboardingVersion
        ])
    }

    // MARK: - Coach Messaging Events

    /// Tracks when a user sends a message to the coach.
    /// - Parameters:
    ///   - conversationId: Unique identifier for the conversation thread
    ///   - messageId: Unique identifier for this message
    ///   - messageIndex: 1-based index of this message in the conversation
    ///   - inputMethod: How the message was entered ("text" or "voice")
    ///   - triggerSource: What triggered the message ("user_tap", "quick_reply", "notification_deeplink", "unknown")
    ///   - textLengthChars: Number of characters in the message (no raw content)
    ///   - voiceDurationMs: Duration of voice recording in ms (nil for text)
    ///   - transcriptionSuccess: Whether voice transcription succeeded (nil for text)
    ///   - screenName: Screen where the message was sent from
    func trackUserMessageSent(
        conversationId: String?,
        messageId: String,
        messageIndex: Int,
        inputMethod: String,
        triggerSource: String,
        textLengthChars: Int,
        voiceDurationMs: Int? = nil,
        transcriptionSuccess: Bool? = nil,
        screenName: String
    ) {
        var props: [String: MixpanelType] = [
            "message_id": messageId,
            "message_index": messageIndex,
            "input_method": inputMethod,
            "trigger_source": triggerSource,
            "text_length_chars": textLengthChars,
            "screen_name": screenName
        ]

        if let conversationId = conversationId {
            props["conversation_id"] = conversationId
        }

        if let voiceDurationMs = voiceDurationMs {
            props["voice_duration_ms"] = voiceDurationMs
        }

        if let transcriptionSuccess = transcriptionSuccess {
            props["transcription_success"] = transcriptionSuccess
        }

        track("user_message_sent", properties: props)

        // Record message for session counting (triggers session_message_count on session end)
        MessageSessionTracker.shared.recordUserMessage()
    }

    /// Tracks when a coach response is displayed to the user.
    /// - Parameters:
    ///   - conversationId: Unique identifier for the conversation thread
    ///   - coachMessageId: Unique identifier for the coach message
    ///   - coachMessageIndex: 1-based index of this coach message in the conversation (1 = first reply)
    ///   - inReplyToMessageId: The user message this is responding to
    ///   - responseLatencyMs: Time from user send to coach response shown
    func trackCoachMessageShown(
        conversationId: String?,
        coachMessageId: String,
        coachMessageIndex: Int,
        inReplyToMessageId: String?,
        responseLatencyMs: Int
    ) {
        var props: [String: MixpanelType] = [
            "coach_message_id": coachMessageId,
            "coach_message_index": coachMessageIndex,
            "response_latency_ms": responseLatencyMs
        ]

        if let conversationId = conversationId {
            props["conversation_id"] = conversationId
        }

        if let inReplyToMessageId = inReplyToMessageId {
            props["in_reply_to_message_id"] = inReplyToMessageId
        }

        track("coach_message_shown", properties: props)
    }

    // MARK: - Food Logging Success Events

    /// Tracks when a food entry is successfully logged.
    /// - Parameters:
    ///   - logMethod: How the food was logged ("chat_text", "chat_voice", "manual_search", "barcode", "unknown")
    ///   - conversationId: Conversation ID if logged via chat
    ///   - sourceMessageId: Message ID that triggered the log if via chat
    ///   - itemsCount: Number of food items in this log entry
    ///   - caloriesEstimate: Estimated calories (optional)
    ///   - wasEdit: Whether this was an edit of an existing log
    func trackFoodLogged(
        logMethod: String,
        conversationId: String? = nil,
        sourceMessageId: String? = nil,
        itemsCount: Int,
        caloriesEstimate: Double? = nil,
        wasEdit: Bool = false
    ) {
        var props: [String: MixpanelType] = [
            "log_method": logMethod,
            "items_count": itemsCount,
            "was_edit": wasEdit
        ]

        if let conversationId = conversationId {
            props["conversation_id"] = conversationId
        }

        if let sourceMessageId = sourceMessageId {
            props["source_message_id"] = sourceMessageId
        }

        if let caloriesEstimate = caloriesEstimate {
            props["calories_estimate"] = caloriesEstimate
        }

        track("food_logged", properties: props)
    }

    // MARK: - Session Message Count

    /// Tracks the total number of user messages in a completed session.
    /// This event fires exactly ONCE per session when the session ends.
    /// Used to compute Median User Messages per Session in Mixpanel.
    ///
    /// - Parameters:
    ///   - sessionId: Unique identifier for this session
    ///   - messagesCount: Total number of user messages sent during the session
    ///   - sessionStartTs: When the session started (first message sent)
    ///   - sessionEndTs: When the session ended (background/timeout)
    ///   - sessionDurationMs: Duration of the session in milliseconds
    func trackSessionMessageCount(
        sessionId: String,
        messagesCount: Int,
        sessionStartTs: Date,
        sessionEndTs: Date,
        sessionDurationMs: Int
    ) {
        // Generate $insert_id for deduplication
        let insertId = UUID().uuidString

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let props: [String: MixpanelType] = [
            "session_id": sessionId,
            "messages_count": messagesCount,
            "session_start_ts": isoFormatter.string(from: sessionStartTs),
            "session_end_ts": isoFormatter.string(from: sessionEndTs),
            "session_duration_ms": sessionDurationMs,
            "$insert_id": insertId
        ]

        track("session_message_count", properties: props)

        print("[AnalyticsManager] Tracked session_message_count: \(messagesCount) messages in session \(sessionId)")
    }
}
