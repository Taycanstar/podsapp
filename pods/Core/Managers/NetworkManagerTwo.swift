//
//  NetworkManagerTwo.swift
//  Pods
//
//  Created by Dimi Nunez on 5/22/25.
//

import Foundation

class NetworkManagerTwo {
    // Shared instance (singleton)
    static let shared = NetworkManagerTwo()
    
    

   //  let baseUrl = "https://humuli-2b3070583cda.herokuapp.com"
//   let baseUrl = "http://192.168.1.92:8000"
    let baseUrl = "http://172.20.10.3:8000"
    
    // Network errors
    enum NetworkError: Error {
        case invalidURL
        case noData
        case decodingError
        case serverError(String)
    }
    
    // MARK: - Barcode Lookup
    
    /// Look up food by barcode (UPC/EAN code)
    /// - Parameters:
    ///   - barcode: The barcode string
    ///   - userEmail: User's email address
    ///   - imageData: Optional base64 image data from the photo taken during barcode scanning
    ///   - mealType: Type of meal (Breakfast, Lunch, Dinner, Snack)
    ///   - completion: Result callback with Food object or error
    func lookupFoodByBarcode(
        barcode: String,
        userEmail: String,
        imageData: String? = nil,
        mealType: String = "Lunch",
        completion: @escaping (Result<Food, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/lookup_food_by_barcode/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Create request body
        var parameters: [String: Any] = [
            "user_email": userEmail,
            "barcode": barcode,
            "meal_type": mealType
        ]
        
        // Add optional image data if available
        if let imageData = imageData {
            parameters["image_data"] = imageData
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Log what we're sending to server
        print("🔍 Looking up barcode: \(barcode) for user: \(userEmail)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.noData))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(errorMessage)))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                // Try to parse the food response
                let food = try decoder.decode(Food.self, from: data)
                
                DispatchQueue.main.async {
                    print("✅ Successfully looked up food by barcode: \(food.displayName)")
                    completion(.success(food))
                }
            } catch {
                print("❌ Decoding error in barcode lookup: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }
}
