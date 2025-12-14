//
//  AnalyticsManager.swift
//  pods
//
//  Created by Dimi Nunez on 12/13/25.
//


import Foundation
import Mixpanel
import UIKit

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
    }

    /// Resets identity on logout.
    func reset() {
        userId = nil
        currentRequestId = nil
        Mixpanel.mainInstance().reset()
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
}
