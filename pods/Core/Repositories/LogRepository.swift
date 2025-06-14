import Foundation

class LogRepository {
    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    func getLogs(for date: String, completion: @escaping (Result<[CombinedLog], Error>) -> Void) {
        networkManager.getLogs(for: date) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    completion(.success(response.logs))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func updateLog(logId: Int, servings: Double, date: Date, mealType: String, completion: @escaping (Result<UpdatedFoodLog, Error>) -> Void) {
        networkManager.updateFoodLog(logId: logId, servings: servings, date: date, mealType: mealType) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func fetchLogs(email: String, for date: Date, onComplete: @escaping (Result<ServerLogResponse, Error>) -> Void) {
        // Implementation for fetchLogs
    }
} 