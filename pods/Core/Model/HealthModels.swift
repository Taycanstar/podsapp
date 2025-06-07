//
//  HealthModels.swift
//  Pods
//
//  Created by Dimi Nunez on 5/16/25.
//

import Foundation

// MARK: - Weight Log Response

/// Response from logging a weight measurement
struct WeightLogResponse: Codable {
    let id: Int
    let weightKg: Double
    let dateLogged: String
    let notes: String
}

// MARK: - Weight Logs Response

/// Response containing a user's weight log history
struct WeightLogsResponse: Codable {
    let logs: [WeightLogResponse]
    let totalCount: Int
} 