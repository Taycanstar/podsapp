//
//  WorkoutTelemetryEvent.swift
//  pods
//
//  Created by Dimi Nunez on 11/4/25.
//


//
//  WorkoutGenerationTelemetry.swift
//

import Foundation

enum WorkoutTelemetryEvent: String {
    case filterRejected
    case llmRequestStarted
    case llmRequestFinished
    case llmFallbackUsed
    case planValidationWarning
    case feedbackSubmitted
}

enum WorkoutGenerationTelemetry {
    static func record(_ event: WorkoutTelemetryEvent, metadata: [String: Any] = [:]) {
#if DEBUG
        let metaDescription = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        if metaDescription.isEmpty {
            print("📊 [WorkoutTelemetry] \(event.rawValue)")
        } else {
            print("📊 [WorkoutTelemetry] \(event.rawValue): \(metaDescription)")
        }
#endif
    }
}
