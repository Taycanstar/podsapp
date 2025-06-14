//
//  LogRepository.swift
//  Pods
//
//  Created by Dimi Nunez on 5/11/25.
//

import Foundation
import Combine
import SwiftUI

//  LogRepository.swift
//  Very small abstraction over NetworkManagerTwo
//

//
//  LogRepository.swift
//  Pods
//
//  Created by RefactorBot on 6/2/25
//

import Foundation

/// A very small wrapper around the single NetworkManagerTwo call we
/// need for "show me everything that happened on <date>".
final class LogRepository {

    private let api = NetworkManagerTwo.shared

    /// Fetch all logs that belong to *one* calendar day.
    /// - note: the server already returns `[CombinedLog]`
    func fetchLogs(email: String,
                   for date: Date,
                   completion: @escaping (Result<LogsByDateResponse, Error>) -> Void) {

        api.getLogsByDate(
            userEmail:       email,
            date:            date,
            includeAdjacent: false,
            timezoneOffset:  TimeZone.current.secondsFromGMT() / 60
        ) { result in
            switch result {
            case .success(let payload):
                completion(.success(payload))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func deleteLogItem(email: String, logId: Int, logType: String, completion: @escaping (Result<Void, Error>) -> Void) {
        api.deleteLogItem(userEmail: email, logId: logId, logType: logType) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func updateLog(userEmail: String, logId: Int, servings: Double, date: Date, mealType: String, completion: @escaping (Result<UpdatedFoodLog, Error>) -> Void) {
        api.updateFoodLog(userEmail: userEmail, logId: logId, servings: servings, date: date, mealType: mealType) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
