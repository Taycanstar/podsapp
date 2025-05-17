//
//  HealthModels.swift
//  Pods
//
//  Created by Dimi Nunez on 5/16/25.
//

import Foundation

// MARK: - Height Log Response

/// Response from logging a height measurement
struct HeightLogResponse: Codable {
    let id: Int
    let heightCm: Double
    let dateLogged: String
    let notes: String
}

// MARK: - Weight Log Response

/// Response from logging a weight measurement
struct WeightLogResponse: Codable {
    let id: Int
    let weightKg: Double
    let dateLogged: String
    let notes: String
}

// MARK: - Height Logs Response

/// Response containing a user's height log history
struct HeightLogsResponse: Codable {
    let logs: [HeightLogResponse]
    let totalCount: Int
}

// MARK: - Weight Logs Response

/// Response containing a user's weight log history
struct WeightLogsResponse: Codable {
    let logs: [WeightLogResponse]
    let totalCount: Int
} 