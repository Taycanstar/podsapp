import Foundation
import SwiftUI

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
    case encodingError
    case serverError(String)
    case unknownError
    case noData
        case configurationError
    case imageProcessingError
    case uploadError
    case cleanupError
    case configError
    case badURL
    case uploadFailed
    case decodingFailed(Error)
    case jsonEncodingFailed
    case invalidData
} 

 struct GracieResponse: Codable {
        let response: String
    }
    
    // Add this new response type
    struct PaginatedActivityLogResponse: Codable {
        let logs: [PodItemActivityLogJSON]
        let hasMore: Bool
        let totalPages: Int
        let currentPage: Int
    }

struct AppVersionResponse: Codable {
    let minimumVersion: String
    let needsUpdate: Bool
    let storeUrl: String
    
    enum CodingKeys: String, CodingKey {
        case minimumVersion = "minimum_version"
        case needsUpdate = "needs_update"
        case storeUrl = "store_url"
    }
}
extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: self)
    }
}




class NetworkManager {
 
 let baseUrl = "https://humuli-2b3070583cda.herokuapp.com"
//   let baseUrl = "http://192.168.1.92:8000"  
    // let baseUrl = "http://172.20.10.4:8000" 
    
    private let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private let iso8601Formatter = ISO8601DateFormatter()
    private let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()


    // ### STAGING ###
    let baseUrl = "https://humuli-staging-b3e9cef208dd.herokuapp.com"


    func determineUserLocation() {
        let url = URL(string: "https://ipapi.co/json/")!
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    RegionManager.shared.region = "centralus" // Default region
                    print("Error fetching location data: \(error?.localizedDescription ?? "Unknown error")")
                }
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let regionCode = json["region_code"] as? String {
                    let region = self.mapRegionToAzureBlobLocation(region: regionCode)
                    DispatchQueue.main.async {
                        RegionManager.shared.region = region
                        print("Determined region: \(region)")
                    }
                } else {
                    DispatchQueue.main.async {
                        RegionManager.shared.region = "centralus" // 
                        print("Region code not found in JSON response.")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    RegionManager.shared.region = "centralus" // Default region
                    print("Failed to parse JSON response.")
                }
            }
        }
        task.resume()
    }
        
    func mapRegionToAzureBlobLocation(region: String) -> String {
        switch region {
        case "CA", "OR", "WA", "NV", "AZ", "UT", "ID", "MT", "WY", "CO", "NM", "HI", "AK":
            return "westus"
        case "NY", "NJ", "PA", "CT", "RI", "MA", "NH", "VT", "ME", "MD", "DE", "VA", "WV", "NC", "SC", "GA", "FL", "AL", "TN", "KY":
            return "eastus"
        case "TX", "OK", "LA", "AR", "MO", "KS", "NE", "IA", "MN", "SD", "ND", "IL", "WI", "IN", "OH", "MI":
            return "centralus"
        default:
            return "centralus" // Default region
        }
    }

    

    func getStorageAccountCredentials(for region: String) -> (accountName: String, sasToken: String)? {
           let accountNameKey = "BLOB_NAME_\(region.uppercased())"
           let sasTokenKey = "SAS_TOKEN_\(region.uppercased())"
           
           guard let accountName = ConfigurationManager.shared.getValue(forKey: accountNameKey) as? String,
                 let sasToken = ConfigurationManager.shared.getValue(forKey: sasTokenKey) as? String else {
               print("Missing configuration values for region \(region)")
               return nil
           }
           
           print(accountName, sasToken, "hot shit")
           return (accountName, sasToken)
       }


    func signup(email: String, password: String, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseUrl)/signup/") else {
            completion(false, "Invalid URL")
            return
        }
        
        let body: [String: Any] = ["email": email, "password": password]
        let finalBody = try? JSONSerialization.data(withJSONObject: body)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = finalBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Signup failed: \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, "No response from server")
                }
                return
            }
            
            if httpResponse.statusCode == 201 {
                DispatchQueue.main.async {
                    completion(true, "User created successfully. Verification email sent.")
                }
            } else if let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(false, errorMessage)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "Signup failed with statusCode: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    func completeEmailSignup(
        email: String,
        password: String,
        name: String?,
        onboarding: [String: Any]?,
        completion: @escaping (Bool, String?, String?, String?, String?, String?, String?, String?, String?, Bool?, Int?, Int?, Bool, Bool) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/email-signup/") else {
            completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            return
        }

        var body: [String: Any] = [
            "email": email,
            "password": password
        ]

        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            body["name"] = trimmedName
        }

        if let onboarding = onboarding {
            body["onboarding"] = onboarding
        }

        guard let finalBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(false, "Failed to encode request body", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = finalBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Signup failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(false, "No data from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let errorMessage = json["error"] as? String {
                        DispatchQueue.main.async {
                            completion(false, errorMessage, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
                        }
                        return
                    }

                    let email = json["email"] as? String
                    let username = json["username"] as? String
                    let profileInitial = json["profileInitial"] as? String
                    let profileColor = json["profileColor"] as? String
                    let subscriptionStatus = json["subscriptionStatus"] as? String
                    let subscriptionPlan = json["subscriptionPlan"] as? String
                    let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
                    let subscriptionRenews = json["subscriptionRenews"] as? Bool ?? false
                    let subscriptionSeats = (json["subscriptionSeats"] as? NSNumber)?.intValue
                    let userId = (json["userId"] as? NSNumber)?.intValue
                    let onboardingCompleted = json["onboarding_completed"] as? Bool ?? false
                    let isNewUser = json["isNewUser"] as? Bool ?? false

                    DispatchQueue.main.async {
                        completion(true, nil, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, "Unexpected server response", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
                }
            }
        }.resume()
    }
    
    func checkEmailVerified(email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/check-email-verified/") else {
            completion(false, "Invalid URL")
            return
        }

        let body: [String: Any] = ["email": email]
        let finalBody = try? JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = finalBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Failed to check email verification: \(error.localizedDescription)")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, "No response from server")
                }
                return
            }

            if httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } else {
                DispatchQueue.main.async {
                    let message = (try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any])?["error"] as? String
                    completion(false, message ?? "Email verification check failed.")
                }
            }
        }.resume()
    }

    func resendVerificationEmail(email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/resend-email/") else {
            completion(false, "Invalid URL")
            return
        }

        let body: [String: Any] = ["email": email]
        let finalBody = try? JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = finalBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Failed to resend verification email: \(error.localizedDescription)")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, "No response from server")
                }
                return
            }

            if httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } else {
                DispatchQueue.main.async {
                    let message = (try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any])?["error"] as? String
                    completion(false, message ?? "Resending verification email failed.")
                }
            }
        }.resume()
    }



    
    func login(identifier: String, password: String, completion: @escaping (Bool, String?, String?, String?, String?, String?, String?, String?, String?, Bool?, Int?, Int?, Bool?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/login/") else {
            completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
            return
        }

        let body: [String: Any] = ["username": identifier, "password": password]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Login failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, "No response from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                }
                return
            }
            
            if httpResponse.statusCode == 200, let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let email = json["email"] as? String
                        let username = json["username"] as? String
                        let profileInitial = json["profileInitial"] as? String
                        let profileColor = json["profileColor"] as? String
                        let subscriptionStatus = json["subscriptionStatus"] as? String
                        let subscriptionPlan = json["subscriptionPlan"] as? String
                        let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
                        let subscriptionRenews = json["subscriptionRenews"] as? Bool
                        let subscriptionSeats = json["subscriptionSeats"] as? Int
                        let userId = json["userId"] as? Int
                        let onboardingCompleted = json["onboarding_completed"] as? Bool
                        
                        DispatchQueue.main.async {
                            completion(true, nil, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "Login failed", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                }
            }
        }.resume()
    }



    func updateUserInformation(email: String, name: String, username: String, completion: @escaping (Bool, String) -> Void) {
    guard let url = URL(string: "\(baseUrl)/add-info/") else {
        completion(false, "Invalid URL")
        return
    }
    
    let body: [String: Any] = [
        "email": email,
        "name": name,
        "username": username
    ]
    
    guard let finalBody = try? JSONSerialization.data(withJSONObject: body) else {
        completion(false, "Error encoding data")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = finalBody
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            DispatchQueue.main.async {
                completion(false, "Update failed: \(error.localizedDescription)")
            }
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            DispatchQueue.main.async {
                completion(false, "No response from server")
            }
            return
        }
        
        if httpResponse.statusCode == 200 {
            DispatchQueue.main.async {
                completion(true, "User information updated successfully")
            }
        } else if let data = data,
                 let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                 let errorMessage = json["error"] as? String {
            DispatchQueue.main.async {
                completion(false, errorMessage)
            }
        } else {
            DispatchQueue.main.async {
                completion(false, "Update failed with status code: \(httpResponse.statusCode)")
            }
        }
    }.resume()
}
    
    func markOnboardingCompleted(email: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseUrl)/mark_onboarding_completed/") else {
            completion(false)
            return
        }
        
        let parameters: [String: Any] = [
            "email": email
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success {
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    func createPod(podTitle: String, items: [PodItem], email: String, completion: @escaping (Bool, String?) -> Void) {
        print("Starting createPod...")
        let dispatchGroup = DispatchGroup()
        var updatedItems = [PodItem]()
        var uploadErrors = [String]()
        
        guard let containerName = ConfigurationManager.shared.getValue(forKey: "BLOB_CONTAINER") as? String
                       else {
                    print("Missing configuration values for container")
                    completion(false, "No container name found.")
                    return
                }

        items.forEach { item in
            dispatchGroup.enter()
            if let videoURL = item.videoURL {
                let videoBlobName = UUID().uuidString + ".mp4"
                do {
                    let videoData = try Data(contentsOf: videoURL)
                    print("Uploading video for item \(item.id)...")
                    uploadFileToAzureBlob(containerName: containerName, blobName: videoBlobName, fileData: videoData, contentType: "video/mp4") { success, videoUrlString in
                        if success, let videoUrl = videoUrlString {
                            print("Video uploaded successfully for item \(item.id)")
                            var updatedItem = PodItem(id: item.id, videoURL: URL(string: videoUrl), metadata: item.metadata, thumbnail: nil, thumbnailURL: nil, itemType: item.itemType, notes: item.notes)
                            if let thumbnailImage = item.thumbnail, let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.8) {
                                let thumbnailBlobName = UUID().uuidString + ".jpg"
                                print("Uploading thumbnail for item \(item.id)...")
                                self.uploadFileToAzureBlob(containerName: containerName, blobName: thumbnailBlobName, fileData: thumbnailData, contentType: "image/jpeg") { success, thumbnailUrlString in
                                    if success, let thumbnailUrl = thumbnailUrlString {
                                        print("Thumbnail uploaded successfully for item \(item.id)")
                                        updatedItem.thumbnailURL = URL(string: thumbnailUrl)
                                    } else {
                                        print("Failed to upload thumbnail for item \(item.id)")
                                        uploadErrors.append("Failed to upload thumbnail for item \(item.id)")
                                    }
                                    updatedItems.append(updatedItem)
                                    dispatchGroup.leave()
                                }
                            } else {
                                updatedItems.append(updatedItem)
                                dispatchGroup.leave()
                            }
                        } else {
                            print("Failed to upload video for item \(item.id)")
                            uploadErrors.append("Failed to upload video for item \(item.id)")
                            dispatchGroup.leave()
                        }
                    }
                } catch {
                    print("Failed to load video data for URL: \(videoURL)")
                    uploadErrors.append("Failed to load video data for URL: \(videoURL)")
                    dispatchGroup.leave()
                }
            } else if let image = item.image, let imageData = image.jpegData(compressionQuality: 0.8) {
                let imageBlobName = UUID().uuidString + ".jpg"
                print("Uploading image for item \(item.id)...")
                uploadFileToAzureBlob(containerName: containerName, blobName: imageBlobName, fileData: imageData, contentType: "image/jpeg") { success, imageUrlString in
                    if success, let imageUrl = imageUrlString {
                        print("Image uploaded successfully for item \(item.id)")
                        let updatedItem = PodItem(id: item.id, videoURL: nil, image: nil, metadata: item.metadata, thumbnail: nil, thumbnailURL: URL(string: imageUrl), imageURL: URL(string: imageUrl), itemType: item.itemType, notes: item.notes)
                        updatedItems.append(updatedItem)
                    } else {
                        print("Failed to upload image for item \(item.id)")
                        uploadErrors.append("Failed to upload image for item \(item.id)")
                    }
                    dispatchGroup.leave()
                }
            } else {
                print("No video or image to upload for item \(item.id)")
                uploadErrors.append("No video or image to upload for item \(item.id)")
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            if !uploadErrors.isEmpty {
                print("Failed to upload one or more items: \(uploadErrors.joined(separator: ", "))")
                completion(false, "Failed to upload one or more items: \(uploadErrors.joined(separator: ", "))")
                return
            }

            print("Sending pod creation request...")
            self.sendPodCreationRequest(podTitle: podTitle, items: updatedItems, email: email) { success, message in
                print("Pod creation request result: \(success), message: \(String(describing: message))")
                completion(success, message)
            }
        }
    }


    func sendPodCreationRequest(podTitle: String, items: [PodItem], email: String, completion: @escaping (Bool, String?) -> Void) {

        guard let url = URL(string: "\(baseUrl)/create-pod/") else {
              print("Invalid URL for pod creation")
              completion(false, "Invalid URL")
              return
          }

          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let itemsForBody = items.map { item -> [String: Any] in
            var itemDict: [String: Any] = ["label": item.metadata, "itemType": item.itemType, "thumbnail": item.thumbnailURL?.absoluteString ?? "", "notes": item.notes]
            print(item, "item")
            if item.itemType == "video", let videoURL = item.videoURL?.absoluteString {
                itemDict["videoURL"] = videoURL
            } else if item.itemType == "image", let imageURL = item.imageURL?.absoluteString {
                itemDict["imageURL"] = imageURL
            }
            
            
            
            return itemDict
        }


          let body: [String: Any] = ["title": podTitle, "items": itemsForBody, "email": email]
          do {
              request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            print(body, "body")
              print("Sending data to server: \(String(data: request.httpBody!, encoding: .utf8)!)")
          } catch {
              print("Failed to encode request body, error: \(error)")
              completion(false, "Failed to encode request body")
              return
          }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error on pod creation request: \(error.localizedDescription)")
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Pod creation response status code: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 201 {
                    print("Pod created successfully.")
                    completion(true, nil)
                } else {
                    var errorMessage = "Server returned status code: \(httpResponse.statusCode)"
                    if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                        print("Server response: \(responseString)")
                        errorMessage += ", Response: \(responseString)"
                    }
                    completion(false, errorMessage)
                }
            } else {
                print("No response received from server.")
                completion(false, "No response from server")
            }
        }.resume()
    }
    
    func addItemsToPod(podId: Int, items: [PodItem], completion: @escaping (Bool, String?) -> Void) {
        let dispatchGroup = DispatchGroup()
        var updatedItems = [PodItem]()
        var uploadErrors = [String]()
        
        guard let containerName = ConfigurationManager.shared.getValue(forKey: "BLOB_CONTAINER") as? String else {
            print("Missing configuration values for container")
            completion(false, "No container name found.")
            return
        }

        items.forEach { item in
            dispatchGroup.enter()
            if let videoURL = item.videoURL {
                let videoBlobName = UUID().uuidString + ".mp4"
                do {
                    let videoData = try Data(contentsOf: videoURL)
                    print("Uploading video for item \(item.id)...")
                    uploadFileToAzureBlob(containerName: containerName, blobName: videoBlobName, fileData: videoData, contentType: "video/mp4") { success, videoUrlString in
                        if success, let videoUrl = videoUrlString {
                            print("Video uploaded successfully for item \(item.id)")
                            var updatedItem = PodItem(id: item.id, videoURL: URL(string: videoUrl), metadata: item.metadata, thumbnail: nil, thumbnailURL: nil, itemType: item.itemType, notes: item.notes)
                            if let thumbnailImage = item.thumbnail, let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.8) {
                                let thumbnailBlobName = UUID().uuidString + ".jpg"
                                print("Uploading thumbnail for item \(item.id)...")
                                self.uploadFileToAzureBlob(containerName: containerName, blobName: thumbnailBlobName, fileData: thumbnailData, contentType: "image/jpeg") { success, thumbnailUrlString in
                                    if success, let thumbnailUrl = thumbnailUrlString {
                                        print("Thumbnail uploaded successfully for item \(item.id)")
                                        updatedItem.thumbnailURL = URL(string: thumbnailUrl)
                                    } else {
                                        print("Failed to upload thumbnail for item \(item.id)")
                                        uploadErrors.append("Failed to upload thumbnail for item \(item.id)")
                                    }
                                    updatedItems.append(updatedItem)
                                    dispatchGroup.leave()
                                }
                            } else {
                                updatedItems.append(updatedItem)
                                dispatchGroup.leave()
                            }
                        } else {
                            print("Failed to upload video for item \(item.id)")
                            uploadErrors.append("Failed to upload video for item \(item.id)")
                            dispatchGroup.leave()
                        }
                    }
                } catch {
                    print("Failed to load video data for URL: \(videoURL)")
                    uploadErrors.append("Failed to load video data for URL: \(videoURL)")
                    dispatchGroup.leave()
                }
            } else if let image = item.image, let imageData = image.jpegData(compressionQuality: 0.8) {
                let imageBlobName = UUID().uuidString + ".jpg"
                print("Uploading image for item \(item.id)...")
                uploadFileToAzureBlob(containerName: containerName, blobName: imageBlobName, fileData: imageData, contentType: "image/jpeg") { success, imageUrlString in
                    if success, let imageUrl = imageUrlString {
                        print("Image uploaded successfully for item \(item.id)")
                        let updatedItem = PodItem(id: item.id, videoURL: nil, image: nil, metadata: item.metadata, thumbnail: nil, thumbnailURL: URL(string: imageUrl), imageURL: URL(string: imageUrl), itemType: item.itemType, notes: item.notes)
                        updatedItems.append(updatedItem)
                    } else {
                        print("Failed to upload image for item \(item.id)")
                        uploadErrors.append("Failed to upload image for item \(item.id)")
                    }
                    dispatchGroup.leave()
                }
            } else {
                print("No video or image to upload for item \(item.id)")
                uploadErrors.append("No video or image to upload for item \(item.id)")
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            if !uploadErrors.isEmpty {
                print("Failed to upload one or more items: \(uploadErrors.joined(separator: ", "))")
                completion(false, "Failed to upload one or more items: \(uploadErrors.joined(separator: ", "))")
                return
            }

            print("Sending add items to pod request...")
            self.sendAddItemsToPodRequest(podId: podId, items: updatedItems) { success, message in
                print("Add items to pod request result: \(success), message: \(String(describing: message))")
                completion(success, message)
            }
        }
    }

    func sendAddItemsToPodRequest(podId: Int, items: [PodItem], completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/add-items-to-pod/") else {
            print("Invalid URL for adding items to pod")
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let itemsForBody = items.map { item -> [String: Any] in
            var itemDict: [String: Any] = ["label": item.metadata, "itemType": item.itemType, "thumbnail": item.thumbnailURL?.absoluteString ?? "", "notes": item.notes]
            if item.itemType == "video", let videoURL = item.videoURL?.absoluteString {
                itemDict["videoURL"] = videoURL
            } else if item.itemType == "image", let imageURL = item.imageURL?.absoluteString {
                itemDict["imageURL"] = imageURL
            }
            return itemDict
        }

        let body: [String: Any] = ["pod_id": podId, "items": itemsForBody]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            print("Sending data to server: \(String(data: request.httpBody!, encoding: .utf8)!)")
        } catch {
            print("Failed to encode request body, error: \(error)")
            completion(false, "Failed to encode request body")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error on add items to pod request: \(error.localizedDescription)")
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Add items to pod response status code: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 201 {
                    print("Items added to pod successfully.")
                    completion(true, nil)
                } else {
                    var errorMessage = "Server returned status code: \(httpResponse.statusCode)"
                    if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                        print("Server response: \(responseString)")
                        errorMessage += ", Response: \(responseString)"
                    }
                    completion(false, errorMessage)
                }
            } else {
                print("No response received from server.")
                completion(false, "No response from server")
            }
        }.resume()
    }


     func uploadFileToAzureBlob(containerName: String, blobName: String, fileData: Data, contentType: String, completion: @escaping (Bool, String?) -> Void) {
        
        let region = RegionManager.shared.region
                
          
        guard let credentials = getStorageAccountCredentials(for: region) else {
            print("Missing required configuration for region \(region)")
              completion(false, "Missing required configuration")
              return
          }

          let endpoint = "https://\(credentials.accountName).blob.core.windows.net/\(containerName)/\(blobName)?\(credentials.sasToken)"
          guard let url = URL(string: endpoint) else {
              print("Invalid URL for Azure Blob Storage")
              completion(false, "Invalid URL")
              return
          }

        //   print("Attempting to upload to: \(url)")
          var request = URLRequest(url: url)
          request.httpMethod = "PUT"
          request.setValue(contentType, forHTTPHeaderField: "Content-Type")
          request.setValue("\(fileData.count)", forHTTPHeaderField: "Content-Length")
          request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
          request.httpBody = fileData

          URLSession.shared.dataTask(with: request) { data, response, error in
              if let error = error {
                  print("Network error during upload to Azure Blob Storage: \(error.localizedDescription)")
                  completion(false, "Network error: \(error.localizedDescription)")
                  return
              }

              if let httpResponse = response as? HTTPURLResponse {
                  print("Response status code: \(httpResponse.statusCode)")
                  if httpResponse.statusCode == 201 {
                      let blobUrl = "https://\(credentials.accountName).blob.core.windows.net/\(containerName)/\(blobName)"
                      print("Upload successful to Azure Blob Storage: \(blobUrl)")
                      completion(true, blobUrl)
                  } else {
                      if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                          print("Response Data: \(responseString)")
                      }
                      print("Failed to upload to Azure Blob Storage, status code: \(httpResponse.statusCode)")
                      completion(false, "Upload failed with status code: \(httpResponse.statusCode)")
                  }
              } else {
                  print("No HTTP response received.")
                  completion(false, "No response from server")
              }
          }.resume()
      }

            func uploadMealImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
    // Generate a UUID for the image filename
    let imageId = UUID().uuidString
    let filename = "\(imageId).jpg"
    
    // Get the current region
    let region = RegionManager.shared.region
    
    // Use the same container name as other functions
    guard let containerName = ConfigurationManager.shared.getValue(forKey: "BLOB_CONTAINER") as? String else {
        print("Missing configuration values for container")
        completion(.failure(NetworkError.configError))
        return
    }
    
    // Convert image to data
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        completion(.failure(NetworkError.encodingError))
        return
    }
    
    // Use the existing, proven upload function
    uploadFileToAzureBlob(
        containerName: containerName,
        blobName: filename,
        fileData: imageData,
        contentType: "image/jpeg"
    ) { success, imageUrlString in
        if success, let imageUrl = imageUrlString {
            print("Meal image uploaded successfully: \(imageUrl)")
            completion(.success(imageUrl))
        } else {
            print("Failed to upload meal image")
            completion(.failure(NetworkError.uploadFailed))
        }
    }
}

    func cleanupOrphanedImages(olderThan hours: Int = 24, completion: @escaping (Bool) -> Void) {
    let cutoffDate = Calendar.current.date(byAdding: .hour, value: -hours, to: Date())!
    
    // Get list of orphaned images from your Django API
    guard let url = URL(string: "\(baseUrl)/orphaned-images?before=\(cutoffDate.iso8601)") else {
        completion(false)
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data,
              let blobNames = try? JSONDecoder().decode([String].self, from: data) 
        else {
            completion(false)
            return
        }
        
        let deleteGroup = DispatchGroup()
        var deleteErrors = [Error]()
        
        blobNames.forEach { blobName in
            deleteGroup.enter()
            self.deleteAzureBlob(blobName: blobName) { success in
                if !success {
                    deleteErrors.append(NetworkError.cleanupError)
                }
                deleteGroup.leave()
            }
        }
        
        deleteGroup.notify(queue: .main) {
            completion(deleteErrors.isEmpty)
        }
    }.resume()
}

private func deleteAzureBlob(blobName: String, completion: @escaping (Bool) -> Void) {
    guard let containerName = ConfigurationManager.shared.getValue(forKey: "BLOB_CONTAINER") as? String else {
        completion(false)
        return
    }
    
    let region = RegionManager.shared.region
    guard let credentials = getStorageAccountCredentials(for: region) else {
        completion(false)
        return
    }
    
    let endpoint = "https://\(credentials.accountName).blob.core.windows.net/\(containerName)/\(blobName)?\(credentials.sasToken)"
    
    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpMethod = "DELETE"
    
    URLSession.shared.dataTask(with: request) { _, response, error in
        completion((response as? HTTPURLResponse)?.statusCode == 202)
    }.resume()
}

    func fetchPodsForUser(email: String, workspaceId: Int? = nil, showFavorites: Bool = false, showRecentlyVisited: Bool = false, completion: @escaping (Result<[Pod], Error>) -> Void) {
        var urlString = "\(baseUrl)/get-user-pods2/\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let workspaceId = workspaceId {
            urlString += "?workspaceId=\(workspaceId)"
        }
        if showFavorites {
            urlString += urlString.contains("?") ? "&" : "?"
            urlString += "favorites=true"
        }
        if showRecentlyVisited {
            urlString += urlString.contains("?") ? "&" : "?"
            urlString += "recentlyVisited=true"
        }
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
             
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    let formatterWithFractionalSeconds = ISO8601DateFormatter()
                    formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    let formatterWithoutFractionalSeconds = ISO8601DateFormatter()
                    formatterWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]
                    
                    if let date = formatterWithFractionalSeconds.date(from: dateString) {
                        return date
                    } else if let date = formatterWithoutFractionalSeconds.date(from: dateString) {
                        return date
                    } else {
                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                    }
                }
                
                let podResponse = try decoder.decode(PodResponse.self, from: data)
                let pods = podResponse.pods.map { Pod(from: $0) }
                completion(.success(pods))
            } catch {
                print("Decoding error: \(error)")
                if let decodingError = error as? DecodingError {
                      switch decodingError {
                      case .keyNotFound(let key, _):
                          print("Key not found:", key)
                      case .typeMismatch(let type, let context):
                          print("Type mismatch:", type, context)
                      default:
                          print("Other decoding error:", decodingError)
                      }
                  }
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchPodsForUser2(email: String, folderName: String = "Pods", completion: @escaping (Result<PodResponse, Error>) -> Void) {
            let urlString = "\(baseUrl)/get-user-pods2/\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")?folder=\(folderName)"
            
            guard let url = URL(string: urlString) else {
                completion(.failure(NetworkError.invalidURL))
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(PodResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }
    
    
    func fetchUserFolders(email: String, completion: @escaping (Result<FolderResponse, Error>) -> Void) {
        let urlString = "\(baseUrl)/get-user-folders/\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(FolderResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateFoldersOrder(folderIds: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/update-folders-order/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let body = ["folder_ids": folderIds]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            if httpResponse.statusCode == 200 {
                completion(.success(()))
            } else {
                completion(.failure(NetworkError.unknownError))
            }
        }.resume()
    }


    func fetchFullPodDetails(email: String, podId: Int, completion: @escaping (Result<Pod, Error>) -> Void) {
        let urlString = "\(baseUrl)/get-full-pod-details/\(email)/\(podId)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("No data received.")
                completion(.failure(NetworkError.noData))
                return
            }
            
            // Debug: Print the raw JSON response
            if let rawResponse = String(data: data, encoding: .utf8) {
//                print("Raw JSON response:\n\(rawResponse)")I still see a fucking sheet 
            }
            
            do {
                let decoder = JSONDecoder()
                
                let createdAtFormatter = DateFormatter()
                createdAtFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                // Create a custom date formatter that can handle Python's isoformat() output
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                
                // Try multiple different date format patterns
                let dateFormats = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",  // With 6 fractional digits, no timezone
                    "yyyy-MM-dd'T'HH:mm:ss.SSS",     // With 3 fractional digits, no timezone
                    "yyyy-MM-dd'T'HH:mm:ss",         // No fractional digits, no timezone
                    "yyyy-MM-dd"                     // Just date
                ]
                
                // Use custom date formatting strategy to handle different Python date formats
                decoder.dateDecodingStrategy = .custom { decoder -> Date in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // Log every date string we're trying to decode
                    print("🕒 Attempting to decode date string: '\(dateString)'")
                    
                    // If string is empty or null, return current date
                    if dateString.isEmpty {
                        print("⚠️ Empty date string, using current date")
                        return Date()
                    }
                    
                    // Try ISO8601 first with various options
                    let iso8601 = ISO8601DateFormatter()
                    if let date = iso8601.date(from: dateString) {
                        print("✅ Successfully parsed date with standard ISO8601")
                        return date
                    }
                    
                    // Try with fractional seconds
                    iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = iso8601.date(from: dateString) {
                        print("✅ Successfully parsed date with ISO8601 + fractional seconds")
                        return date
                    }
                    
                    // Try each of our custom formats
                    for format in dateFormats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            print("✅ Successfully parsed date with format: \(format)")
                            return date
                        }
                    }
                    
                    // Last resort - try to fix the date string
                    var fixedDateString = dateString
                    
                    // If it looks like ISO8601 but missing Z, add it
                    if dateString.contains("T") && !dateString.hasSuffix("Z") && !dateString.contains("+") {
                        fixedDateString = dateString + "Z"
                        print("🔄 Trying to fix date string by adding Z: '\(fixedDateString)'")
                        
                        // Try again with the fixed string
                        if let date = iso8601.date(from: fixedDateString) {
                            print("✅ Successfully parsed fixed date string")
                            return date
                        }
                    }
                    
                    // If we still couldn't parse it, log the context and paths
                    print("⚠️ Failed to parse date string: '\(dateString)'")
                    print("⚠️ Attempted ISO8601 formats and these custom formats: \(dateFormats.joined(separator: ", "))")
                    
                    // Get coding path
                    let context = DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Failed to decode date: \(dateString)"
                    )
                    
                    print("⚠️ Coding path: \(context.codingPath.map { $0.stringValue })")
                    
                    // Last resort - return current date rather than crashing
                    print("⚠️ Using current date as fallback")
                    return Date()
                }
                
                // Decode the JSON into your temporary PodJSON model.
                let podJSON = try decoder.decode(PodJSON.self, from: data)
                // Convert the PodJSON into your Pod model.
                let pod = Pod(from: podJSON)
                
                
                completion(.success(pod))
            } catch {
                print("Decoding error: \(error)")
                if let dataString = String(data: data, encoding: .utf8) {
                    print("Received data: \(dataString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    
    func fetchPodActivityLogs(podId: Int, completion: @escaping (Result<[PodItemActivityLog], Error>) -> Void) {
        let urlString = "\(baseUrl)/get-pod-activity-logs/\(podId)/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(ActivityLogResponse.self, from: data)
                
                let activityLogs = try response.logs.compactMap { jsonLog -> PodItemActivityLog? in
                    do {
                        return try PodItemActivityLog(from: jsonLog)
                    } catch {
                        print("Error converting log: \(error)")
                        return nil
                    }
                }
                
                completion(.success(activityLogs))
            } catch {
           
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchUserActivityLogs2(podId: Int, userEmail: String, completion: @escaping (Result<[PodItemActivityLog], Error>) -> Void) {
        let encodedEmail = userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseUrl)/get-user-activity-logs/\(podId)/\(encodedEmail)/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(ActivityLogResponse.self, from: data)
                
                let activityLogs = try response.logs.compactMap { jsonLog -> PodItemActivityLog? in
                    do {
                        return try PodItemActivityLog(from: jsonLog)
                    } catch {
                        print("Error converting log: \(error)")
                        return nil
                    }
                }
                
                completion(.success(activityLogs))
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    func fetchUserActivityLogs(podId: Int, userEmail: String, page: Int = 1, completion: @escaping (Result<(logs: [PodItemActivityLog], hasMore: Bool), Error>) -> Void) {
        let encodedEmail = userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseUrl)/get-user-activity-logs/\(podId)/\(encodedEmail)/?page=\(page)"
        print("Fetching URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(PaginatedActivityLogResponse.self, from: data)
                
                let activityLogs = try response.logs.compactMap { jsonLog -> PodItemActivityLog? in
                    do {
                        return try PodItemActivityLog(from: jsonLog)
                    } catch {
                        print("Error converting log: \(error)")
                        return nil
                    }
                }
                
                completion(.success((logs: activityLogs, hasMore: response.hasMore)))
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

   

    func fetchWorkspacesForUser(email: String, completion: @escaping (Bool, [Workspace]?, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/get-user-workspaces/\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            completion(false, nil, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, nil, "Network request failed: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, nil, "Invalid response")
                return
            }
            
            if let data = data {
                if httpResponse.statusCode == 200 {
                    do {
                        let decoder = JSONDecoder()
                        let workspaces = try decoder.decode([Workspace].self, from: data)
                        completion(true, workspaces, nil)
                    } catch {
                        let responseString = String(data: data, encoding: .utf8) ?? "Unable to parse response"
                        completion(false, nil, "Failed to decode workspaces: \(error.localizedDescription). Response: \(responseString)")
                    }
                } else {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to parse response"
                    completion(false, nil, "Failed to fetch workspaces. Status code: \(httpResponse.statusCode). Response: \(responseString)")
                }
            } else {
                completion(false, nil, "No data received")
            }
        }.resume()
    }
    
    func fetchTeamsForUser(email: String, completion: @escaping (Result<[Team], Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/get-user-teams/\(email)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            do {
                let teams = try JSONDecoder().decode([Team].self, from: data)
                completion(.success(teams))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func deletePod(podId: Int, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/delete-pod/\(podId)/") else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        // Add any headers if needed, e.g., Authorization
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse, error == nil else {
                DispatchQueue.main.async {
                    completion(false, "Network request failed: \(error?.localizedDescription ?? "Unknown error")")
                }
                return
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                // Pod deleted successfully
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } else {
                // Handle errors
                var errorMessage = "Failed to delete pod with statusCode: \(httpResponse.statusCode)"
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverMessage = json["error"] as? String {
                    errorMessage = serverMessage
                }
                DispatchQueue.main.async {
                    completion(false, errorMessage)
                }
            }
        }.resume()
    }
    
    func createFolder(email: String, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/create-folder/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let body = [
            "email": email,
            "name": name
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(CreateFolderResponse.self, from: data)
                let folder = Folder(id: response.id, name: response.name, isDefault: response.isDefault, podCount: response.podCount)
                completion(.success(folder))
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteFolder(folderId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/delete-folder/\(folderId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            switch httpResponse.statusCode {
            case 200, 204:
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            default:
                var errorMessage = "Failed to delete folder: \(httpResponse.statusCode)"
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverMessage = json["error"] as? String {
                    errorMessage = serverMessage
                }
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                }
            }
        }.resume()
    }
    
    func reorderPods(email: String, podIds: [Int], completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/reorder-pods/") else {
            completion(false, "Invalid URL")
            return
        }
        
        let body: [String: Any] = [
            "email": email,
            "pod_ids": podIds
        ]
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, "Network error: \(error.localizedDescription)")
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        completion(false, "No response from server")
                    }
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        let errorMessage = "Server returned status code: \(httpResponse.statusCode)"
                        completion(false, errorMessage)
                    }
                }
            }.resume()
        } catch {
            completion(false, "Failed to encode request body")
        }
    }
    
    func deletePodItem(itemId: Int, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/delete-pod-item/\(itemId)/") else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        // Add any necessary headers here, e.g., Authorization

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse, error == nil else {
                DispatchQueue.main.async {
                    completion(false, "Network request failed: \(error?.localizedDescription ?? "Unknown error")")
                }
                return
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                // PodItem deleted successfully
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } else {
                // Handle errors
                var errorMessage = "Failed to delete pod item with statusCode: \(httpResponse.statusCode)"
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverMessage = json["error"] as? String {
                    errorMessage = serverMessage
                }
                DispatchQueue.main.async {
                    completion(false, errorMessage)
                }
            }
        }.resume()
    }

    func reorderPodItems(podId: Int, itemIds: [Int], completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/reorder-items/\(podId)/") else {
            completion(false, "Invalid URL")
            return
        }
        
        let body: [String: Any] = [
            "item_ids": itemIds
        ]
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, "Network error: \(error.localizedDescription)")
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        completion(false, "No response from server")
                    }
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        let errorMessage = "Server returned status code: \(httpResponse.statusCode)"
                        completion(false, errorMessage)
                    }
                }
            }.resume()
        } catch {
            DispatchQueue.main.async {
                completion(false, "Failed to encode request body")
            }
        }
    }


    func transcribeAudio(from url: URL, completion: @escaping (Bool, String?) -> Void) {
        guard let apiUrl = URL(string: "\(baseUrl)/transcribe-audio/") else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(url.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)

        do {
            let videoData = try Data(contentsOf: url)
            print("Appending video data to request body.")
            body.append(videoData)
        } catch {
            print("Error reading video file data: \(error.localizedDescription)")
            completion(false, "Error reading video file data: \(error.localizedDescription)")
            return
        }

        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(false, "Error: \(String(describing: error))")
                return
            }

            guard let data = data else {
                print("No data received.")
                completion(false, "No data received")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let text = json["text"] as? String {
                    print("Received transcription: \(text)")
                    completion(true, text)
                } else {
                    let responseString = String(data: data, encoding: .utf8)
                    print("Unable to parse response. Response: \(String(describing: responseString))")
                    completion(false, "Error: Unable to parse response. Response: \(String(describing: responseString))")
                }
            } catch {
                print("Error parsing JSON: \(error)")
                completion(false, "Error parsing JSON: \(error)")
            }
        }

        print("Starting transcription request to backend.")
        task.resume()
    }

    func summarizeVideo(from url: URL, completion: @escaping (Bool, String?) -> Void) {
        guard let apiUrl = URL(string: "\(baseUrl)/summarize-video/") else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(url.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)

        do {
            let videoData = try Data(contentsOf: url)
            print("Appending video data to request body.")
            body.append(videoData)
        } catch {
            print("Error reading video file data: \(error.localizedDescription)")
            completion(false, "Error reading video file data: \(error.localizedDescription)")
            return
        }

        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(false, "Error: \(String(describing: error))")
                return
            }

            guard let data = data else {
                print("No data received.")
                completion(false, "No data received")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let text = json["text"] as? String {
                    print("Received transcription: \(text)")
                    completion(true, text)
                } else {
                    let responseString = String(data: data, encoding: .utf8)
                    print("Unable to parse response. Response: \(String(describing: responseString))")
                    completion(false, "Error: Unable to parse response. Response: \(String(describing: responseString))")
                }
            } catch {
                print("Error parsing JSON: \(error)")
                completion(false, "Error parsing JSON: \(error)")
            }
        }

        print("Starting transcription request to backend.")
        task.resume()
    }
    
    // func sendTokenToBackend(idToken: String, completion: @escaping (Bool, String?, String?, String?, String?, String?, String?, String?, String?, Bool?, Int?, Int?, Bool) -> Void) {
    //     guard let url = URL(string: "\(baseUrl)/google-login/") else {
    //         completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
    //         return
    //     }

    //     let body: [String: Any] = ["token": idToken]
    //     var request = URLRequest(url: url)
    //     request.httpMethod = "POST"
    //     request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    //     request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    //     URLSession.shared.dataTask(with: request) { data, response, error in
    //         if let error = error {
    //             DispatchQueue.main.async {
    //                 completion(false, "Request failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
    //             }
    //             return
    //         }

    //         guard let data = data else {
    //             DispatchQueue.main.async {
    //                 completion(false, "No data from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
    //             }
    //             return
    //         }

    //         do {
    //             if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
    //                 let email = json["email"] as? String
    //                 let username = json["username"] as? String
    //                 let profileInitial = json["profileInitial"] as? String
    //                 let profileColor = json["profileColor"] as? String
    //                 let subscriptionStatus = json["subscriptionStatus"] as? String
    //                 let subscriptionPlan = json["subscriptionPlan"] as? String
    //                 let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
    //                 let subscriptionRenews = json["subscriptionRenews"] as? Bool ?? false
    //                 let subscriptionSeats = (json["subscriptionSeats"] as? NSNumber)?.intValue
    //                 let userId = (json["userId"] as? NSNumber)?.intValue
    //                 let isNewUser = json["isNewUser"] as? Bool ?? false

    //                 DispatchQueue.main.async {
    //                     completion(true, nil, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, isNewUser)
    //                 }
    //             }
    //         } catch {
    //             DispatchQueue.main.async {
    //                 completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
    //             }
    //         }
    //     }.resume()
    // }

    // func sendAppleTokenToBackend(idToken: String, nonce: String, completion: @escaping (Bool, String?, String?, String?, String?, String?, String?, String?, String?, Bool?, Int?, Int?, Bool) -> Void) {
    //     guard let url = URL(string: "\(baseUrl)/apple-login/") else {
    //         completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
    //         return
    //     }

    //     let body: [String: Any] = [
    //         "token": idToken,
    //         "nonce": nonce
    //     ]
    //     var request = URLRequest(url: url)
    //     request.httpMethod = "POST"
    //     request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    //     request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    //     URLSession.shared.dataTask(with: request) { data, response, error in
    //         if let error = error {
    //             DispatchQueue.main.async {
    //                 completion(false, "Request failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
    //             }
    //             return
    //         }

    //         guard let data = data else {
    //             DispatchQueue.main.async {
    //                 completion(false, "No data from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
    //             }
    //             return
    //         }

    //         do {
    //             if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
    //                 let email = json["email"] as? String
    //                 let username = json["username"] as? String
    //                 let profileInitial = json["profileInitial"] as? String
    //                 let profileColor = json["profileColor"] as? String
    //                 let subscriptionStatus = json["subscriptionStatus"] as? String
    //                 let subscriptionPlan = json["subscriptionPlan"] as? String
    //                 let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
    //                 let subscriptionRenews = json["subscriptionRenews"] as? Bool ?? false
    //                 let subscriptionSeats = (json["subscriptionSeats"] as? NSNumber)?.intValue
    //                 let userId = (json["userId"] as? NSNumber)?.intValue
    //                 let isNewUser = json["isNewUser"] as? Bool ?? false

    //                 DispatchQueue.main.async {
    //                     completion(true, nil, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, isNewUser)
    //                 }
    //             }
    //         } catch {
    //             DispatchQueue.main.async {
    //                 completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
    //             }
    //         }
    //     }.resume()
    // }

    func sendTokenToBackend(idToken: String, completion: @escaping (Bool, String?, String?, String?, String?, String?, String?, String?, String?, Bool?, Int?, Int?, Bool, Bool) -> Void) {
    guard let url = URL(string: "\(baseUrl)/google-login/") else {
        completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
        return
    }

    let body: [String: Any] = ["token": idToken]
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            DispatchQueue.main.async {
                completion(false, "Request failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
            return
        }

        guard let data = data else {
            DispatchQueue.main.async {
                completion(false, "No data from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
            return
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                let email = json["email"] as? String
                let username = json["username"] as? String
                let profileInitial = json["profileInitial"] as? String
                let profileColor = json["profileColor"] as? String
                let subscriptionStatus = json["subscriptionStatus"] as? String
                let subscriptionPlan = json["subscriptionPlan"] as? String
                let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
                let subscriptionRenews = json["subscriptionRenews"] as? Bool ?? false
                let subscriptionSeats = (json["subscriptionSeats"] as? NSNumber)?.intValue
                let userId = (json["userId"] as? NSNumber)?.intValue
                let onboardingCompleted = json["onboarding_completed"] as? Bool ?? false
                let isNewUser = json["isNewUser"] as? Bool ?? false
                
                print("📱 Google login - isNewUser: \(isNewUser), onboarding_completed: \(onboardingCompleted)")

                DispatchQueue.main.async {
                    completion(true, nil, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser)
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
        }
    }.resume()
}

func sendAppleTokenToBackend(idToken: String, nonce: String, completion: @escaping (Bool, String?, String?, String?, String?, String?, String?, String?, String?, Bool?, Int?, Int?, Bool, Bool) -> Void) {
    guard let url = URL(string: "\(baseUrl)/apple-login/") else {
        completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
        return
    }

    let body: [String: Any] = [
        "token": idToken,
        "nonce": nonce
    ]
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            DispatchQueue.main.async {
                completion(false, "Request failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
            return
        }

        guard let data = data else {
            DispatchQueue.main.async {
                completion(false, "No data from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
            return
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                let email = json["email"] as? String
                let username = json["username"] as? String
                let profileInitial = json["profileInitial"] as? String
                let profileColor = json["profileColor"] as? String
                let subscriptionStatus = json["subscriptionStatus"] as? String
                let subscriptionPlan = json["subscriptionPlan"] as? String
                let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
                let subscriptionRenews = json["subscriptionRenews"] as? Bool ?? false
                let subscriptionSeats = (json["subscriptionSeats"] as? NSNumber)?.intValue
                let userId = (json["userId"] as? NSNumber)?.intValue
                let onboardingCompleted = json["onboarding_completed"] as? Bool ?? false
                let isNewUser = json["isNewUser"] as? Bool ?? false
                
                print("📱 Apple login - isNewUser: \(isNewUser), onboarding_completed: \(onboardingCompleted)")

                DispatchQueue.main.async {
                    completion(true, nil, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser)
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
        }
    }.resume()
}

func completeGoogleSignup(idToken: String,
                          onboarding: [String: Any]?,
                          name: String?,
                          completion: @escaping (Bool, String?, String?, String?, String?, String?, String?, String?, String?, Bool?, Int?, Int?, Bool, Bool) -> Void) {
    guard let url = URL(string: "\(baseUrl)/google-signup/") else {
        completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
        return
    }

    var body: [String: Any] = ["token": idToken]
    if let onboarding = onboarding {
        body["onboarding"] = onboarding
    }
    let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedName.isEmpty {
        body["name"] = trimmedName
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            DispatchQueue.main.async {
                completion(false, "Request failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
            return
        }

        guard let data = data else {
            DispatchQueue.main.async {
                completion(false, "No data from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
            return
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(false, errorMessage, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
                    }
                    return
                }

                let email = json["email"] as? String
                let username = json["username"] as? String
                let profileInitial = json["profileInitial"] as? String
                let profileColor = json["profileColor"] as? String
                let subscriptionStatus = json["subscriptionStatus"] as? String
                let subscriptionPlan = json["subscriptionPlan"] as? String
                let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
                let subscriptionRenews = json["subscriptionRenews"] as? Bool ?? false
                let subscriptionSeats = (json["subscriptionSeats"] as? NSNumber)?.intValue
                let userId = (json["userId"] as? NSNumber)?.intValue
                let onboardingCompleted = json["onboarding_completed"] as? Bool ?? false
                let isNewUser = json["isNewUser"] as? Bool ?? false

                DispatchQueue.main.async {
                    completion(true, nil, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser)
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
        }
    }.resume()
}

func completeAppleSignup(idToken: String,
                         nonce: String,
                         onboarding: [String: Any]?,
                         name: String?,
                         completion: @escaping (Bool, String?, String?, String?, String?, String?, String?, String?, String?, Bool?, Int?, Int?, Bool, Bool) -> Void) {
    guard let url = URL(string: "\(baseUrl)/apple-signup/") else {
        completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
        return
    }

    var body: [String: Any] = [
        "token": idToken,
        "nonce": nonce
    ]

    if let onboarding = onboarding {
        body["onboarding"] = onboarding
    }
    let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedName.isEmpty {
        body["name"] = trimmedName
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            DispatchQueue.main.async {
                completion(false, "Request failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
            return
        }

        guard let data = data else {
            DispatchQueue.main.async {
                completion(false, "No data from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
            return
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(false, errorMessage, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
                    }
                    return
                }

                let email = json["email"] as? String
                let username = json["username"] as? String
                let profileInitial = json["profileInitial"] as? String
                let profileColor = json["profileColor"] as? String
                let subscriptionStatus = json["subscriptionStatus"] as? String
                let subscriptionPlan = json["subscriptionPlan"] as? String
                let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
                let subscriptionRenews = json["subscriptionRenews"] as? Bool ?? false
                let subscriptionSeats = (json["subscriptionSeats"] as? NSNumber)?.intValue
                let userId = (json["userId"] as? NSNumber)?.intValue
                let onboardingCompleted = json["onboarding_completed"] as? Bool ?? false
                let isNewUser = json["isNewUser"] as? Bool ?? false

                DispatchQueue.main.async {
                    completion(true, nil, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser)
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false, false)
            }
        }
    }.resume()
}



    func addNewItem(podId: Int, itemType: String, videoURL: URL?, image: UIImage?, label: String, thumbnail: UIImage?, notes: String, email: String, completion: @escaping (Bool, String?) -> Void) {
        let dispatchGroup = DispatchGroup()
        var uploadErrors = [String]()

        guard let containerName = ConfigurationManager.shared.getValue(forKey: "BLOB_CONTAINER") as? String else {
            print("Missing configuration values for container")
            completion(false, "No container name found.")
            return
        }

        var uploadedVideoURL: String?
        var uploadedImageURL: String?
        var uploadedThumbnailURL: String?

        if let videoURL = videoURL {
            let videoBlobName = UUID().uuidString + ".mp4"
            do {
                let videoData = try Data(contentsOf: videoURL)
                dispatchGroup.enter()
                uploadFileToAzureBlob(containerName: containerName, blobName: videoBlobName, fileData: videoData, contentType: "video/mp4") { success, videoUrlString in
                    if success, let videoUrl = videoUrlString {
                        uploadedVideoURL = videoUrl
                    } else {
                        uploadErrors.append("Failed to upload video")
                    }
                    dispatchGroup.leave()
                }
            } catch {
                uploadErrors.append("Failed to load video data for URL: \(videoURL)")
            }
        }

        if let image = image {
            let imageBlobName = UUID().uuidString + ".jpg"
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                dispatchGroup.enter()
                uploadFileToAzureBlob(containerName: containerName, blobName: imageBlobName, fileData: imageData, contentType: "image/jpeg") { success, imageUrlString in
                    if success, let imageUrl = imageUrlString {
                        uploadedImageURL = imageUrl
                    } else {
                        uploadErrors.append("Failed to upload image")
                    }
                    dispatchGroup.leave()
                }
            } else {
                uploadErrors.append("Failed to convert image to data")
            }
        }

        if let thumbnail = thumbnail, let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
            let thumbnailBlobName = UUID().uuidString + ".jpg"
            dispatchGroup.enter()
            uploadFileToAzureBlob(containerName: containerName, blobName: thumbnailBlobName, fileData: thumbnailData, contentType: "image/jpeg") { success, thumbnailUrlString in
                if success, let thumbnailUrl = thumbnailUrlString {
                    uploadedThumbnailURL = thumbnailUrl
                } else {
                    uploadErrors.append("Failed to upload thumbnail")
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            if !uploadErrors.isEmpty {
                completion(false, "Failed to upload one or more items: \(uploadErrors.joined(separator: ", "))")
                return
            }

            self.sendAddItemRequest(podId: podId, itemType: itemType, videoURL: uploadedVideoURL, imageURL: uploadedImageURL, label: label, thumbnail: uploadedThumbnailURL, notes: notes, email: email, completion: completion)
        }
    }
    
    private func sendAddItemRequest(podId: Int, itemType: String, videoURL: String?, imageURL: String?, label: String, thumbnail: String?, notes: String, email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/add-pod-item/") else {
            completion(false, "Invalid URL")
            return
        }

        let body: [String: Any] = [
            "pod_id": podId,
            "itemType": itemType,
            "videoURL": videoURL ?? "",
            "imageURL": imageURL ?? "",
            "label": label,
            "thumbnail": thumbnail ?? "",
            "notes": notes,
            "email": email
        ]

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, "Network error: \(error.localizedDescription)")
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        completion(false, "No response from server")
                    }
                    return
                }

                if httpResponse.statusCode == 201 {
                    DispatchQueue.main.async {
                        completion(true, "Item added to pod successfully.")
                    }
                } else {
                    var errorMessage = "Server returned status code: \(httpResponse.statusCode)"
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        errorMessage += ", Response: \(responseString)"
                    }
                    DispatchQueue.main.async {
                        completion(false, errorMessage)
                    }
                }
            }.resume()
        } catch {
            completion(false, "Failed to encode request body")
        }
    }


    
    func fetchItemsForPod(podId: Int, completion: @escaping ([PodItem]?, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/fetch-items/\(podId)/") else {
            completion(nil, "Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, "Network error: \(error.localizedDescription)")
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, "No data received")
                }
                return
            }

            do {
                let responseJSON = try JSONDecoder().decode([String: [PodItemJSON]].self, from: data)
                if let itemsJSON = responseJSON["items"] {
                    let podItems = itemsJSON.map { PodItem(from: $0) }
                    DispatchQueue.main.async {
                        completion(podItems, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, "Invalid data format")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, "Failed to decode items: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    func updatePodItemLabel(itemId: Int, newLabel: String, completion: @escaping (Bool, String?) -> Void) {
           guard let url = URL(string: "\(baseUrl)/update-pod-item-label/\(itemId)/") else {
               completion(false, "Invalid URL")
               return
           }
           
           var request = URLRequest(url: url)
           request.httpMethod = "PUT"
           request.addValue("application/json", forHTTPHeaderField: "Content-Type")
           
           let body: [String: Any] = ["label": newLabel]
           
           do {
               request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
           } catch {
               completion(false, "Failed to encode request body")
               return
           }
           
           URLSession.shared.dataTask(with: request) { data, response, error in
               if let error = error {
                   completion(false, "Network request failed: \(error.localizedDescription)")
                   return
               }
               
               if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                   completion(true, nil)
               } else {
                   completion(false, "Failed to update pod item label")
               }
           }.resume()
       }
    
    func updatePodItemLabelAndNotes(itemId: Int, newLabel: String?, newNotes: String?, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/update-pod-item-label-and-notes/\(itemId)/") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if let newLabel = newLabel {
            body["label"] = newLabel
        }
        if let newNotes = newNotes {
            body["notes"] = newNotes
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            print("Request URL: \(url)")
            print("Request Body: \(body)")
        } catch {
            completion(false, "Failed to encode request body")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network request failed: \(error.localizedDescription)")
                completion(false, "Network request failed: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Response Status Code: \(httpResponse.statusCode)")
            }
            
            if let data = data, let responseData = String(data: data, encoding: .utf8) {
                print("Response Data: \(responseData)")
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true, nil)
            } else {
                completion(false, "Failed to update pod item label and notes")
            }
        }.resume()
    }



    
    func deleteAllPods(email: String, completion: @escaping (Bool, String?) -> Void) {
            guard let url = URL(string: "\(baseUrl)/delete-all-pods/") else {
                completion(false, "Invalid URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = ["email": email]
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                completion(false, "Failed to encode request body")
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, "Network error: \(error.localizedDescription)")
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        completion(false, "No response from server")
                    }
                    return
                }

                if httpResponse.statusCode == 200 {
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        let errorMessage = "Server returned status code: \(httpResponse.statusCode)"
                        completion(false, errorMessage)
                    }
                }
            }.resume()
        }

        func deleteUserAndData(email: String, completion: @escaping (Bool, String?) -> Void) {
            guard let url = URL(string: "\(baseUrl)/delete-user-and-data/") else {
                completion(false, "Invalid URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = ["email": email]
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                completion(false, "Failed to encode request body")
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, "Network error: \(error.localizedDescription)")
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        completion(false, "No response from server")
                    }
                    return
                }

                if httpResponse.statusCode == 200 {
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        let errorMessage = "Server returned status code: \(httpResponse.statusCode)"
                        completion(false, errorMessage)
                    }
                }
            }.resume()
        }
    
    func requestPasswordReset(email: String, completion: @escaping (Bool, String?) -> Void) {
          guard let url = URL(string: "\(baseUrl)/request-password-reset/") else {
              completion(false, "Invalid URL")
              return
          }

          let body: [String: String] = ["email": email]
          let finalBody = try? JSONSerialization.data(withJSONObject: body)

          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.addValue("application/json", forHTTPHeaderField: "Content-Type")
          request.httpBody = finalBody

          URLSession.shared.dataTask(with: request) { data, response, error in
              if let error = error {
                  DispatchQueue.main.async {
                      completion(false, "Request failed: \(error.localizedDescription)")
                  }
                  return
              }

              guard let httpResponse = response as? HTTPURLResponse else {
                  DispatchQueue.main.async {
                      completion(false, "No response from server")
                  }
                  return
              }

              if httpResponse.statusCode == 200 {
                  DispatchQueue.main.async {
                      completion(true, nil)
                  }
              } else if let data = data,
                        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let errorMessage = json["error"] as? String {
                  DispatchQueue.main.async {
                      completion(false, errorMessage)
                  }
              } else {
                  DispatchQueue.main.async {
                      completion(false, "Request failed with status code: \(httpResponse.statusCode)")
                  }
              }
          }.resume()
      }
    
    func resetPassword(email: String, code: String, newPassword: String, completion: @escaping (Bool, String?) -> Void) {
            guard let url = URL(string: "\(baseUrl)/reset-password/") else {
                completion(false, "Invalid URL")
                return
            }

            let body: [String: String] = ["email": email, "code": code, "new_password": newPassword]
            let finalBody = try? JSONSerialization.data(withJSONObject: body)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = finalBody

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, "Request failed: \(error.localizedDescription)")
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        completion(false, "No response from server")
                    }
                    return
                }

                if httpResponse.statusCode == 200 {
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else if let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(false, errorMessage)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, "Request failed with status code: \(httpResponse.statusCode)")
                    }
                }
            }.resume()
        }
    

    
    func createQuickPod(
        podTitle: String,
        podType: String,
        privacy: String,
        email: String,
        completion: @escaping (Result<Pod, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/create-quick-pod/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let body: [String: Any] = [
            "title": podTitle,
            "pod_type": podType.lowercased(),  // Make sure it matches backend expectations
            "privacy": privacy,
            "email": email
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }

            do {
                let response = try JSONDecoder().decode(CreatePodResponse.self, from: data)
                // When creating a workout pod, we know it will have specific columns
                let columns: [PodColumn] = podType.lowercased() == "workout" ? [
                    PodColumn(id: 0, name: "Sets", type: "number", groupingType: "grouped"),
                    PodColumn(id: 1, name: "Weight", type: "number", groupingType: "grouped"),
                    PodColumn(id: 2, name: "Reps", type: "number", groupingType: "grouped")
                ] : []
                
                let pod = Pod(
                    id: response.pod,
                    title: podTitle,
                    columns: columns,
                    privacy: privacy, pod_type: podType
                  
                )
                completion(.success(pod))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func toggleFavorite(podId: Int, isFavorite: Bool, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/toggle-favorite/\(podId)/") else {
            completion(false, "Invalid URL")
            return
        }

        let body: [String: Any] = ["is_favorite": isFavorite]
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Network error: \(error.localizedDescription)")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, "No response from server")
                }
                return
            }

            if httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } else {
                var errorMessage = "Server returned status code: \(httpResponse.statusCode)"
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    errorMessage += ", Response: \(responseString)"
                }
                DispatchQueue.main.async {
                    completion(false, errorMessage)
                }
            }
        }.resume()
    }

    func updatePodLastVisited(podId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
         guard let url = URL(string: "\(baseUrl)/update-pod-last-visited/\(podId)/") else {
             completion(.failure(NetworkError.invalidURL))
             return
         }

         var request = URLRequest(url: url)
         request.httpMethod = "POST"

         URLSession.shared.dataTask(with: request) { data, response, error in
             if let error = error {
                 completion(.failure(error))
                 return
             }

             guard let httpResponse = response as? HTTPURLResponse else {
                 completion(.failure(NetworkError.invalidResponse))
                 return
             }

             switch httpResponse.statusCode {
             case 200...299:
                 completion(.success(()))
             case 404:
                 completion(.failure(NetworkError.serverError("Pod not found")))
             default:
                 completion(.failure(NetworkError.serverError("Unexpected server response: \(httpResponse.statusCode)")))
             }
         }.resume()
     }
    
    func switchActiveTeam(email: String, teamId: Int, completion: @escaping (Bool, Int?, String?, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/switch-active-team/") else {
            completion(false, nil, nil, "Invalid URL")
            return
        }
        
        let body: [String: Any] = ["email": email, "teamId": teamId]
        let finalBody = try? JSONSerialization.data(withJSONObject: body)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = finalBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, nil, nil, "Switch team failed: \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                DispatchQueue.main.async {
                    completion(false, nil, nil, "No response from server")
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let activeTeamId = json["activeTeamId"] as? Int,
                       let activeTeamName = json["activeTeamName"] as? String {
                        DispatchQueue.main.async {
                            completion(true, activeTeamId, activeTeamName, nil)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(false, nil, nil, "Invalid response format")
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(false, nil, nil, "Failed to parse response")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, nil, nil, "Switch team failed with statusCode: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }

    func updatePodItemColumnValue(
        itemId: Int,
        columnName: String,
        value: ColumnValue,
        userEmail: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/update-column-value/\(itemId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let jsonValue: Any
        switch value {
        case .string(let stringValue):
            jsonValue = stringValue
        case .number(let numberValue):
            jsonValue = "\(numberValue)" // Convert Double to String
        case .time(let timeValue):
            jsonValue = timeValue.toString
        case .array(let arrayValue):
            // Convert array to a JSON-compatible format (array of strings)
            jsonValue = arrayValue.map { element in
                switch element {
                case .string(let str):
                    return str
                case .number(let num):
                    return "\(num)" // Convert Double to String
                case .time(let timeValue):
                    return timeValue.toString
                case .null:
                    return "" // Represent null values as empty strings
                case .array:
                    return "" // Nested arrays are not supported in this example
                }
            }
        case .null:
            jsonValue = NSNull()
        }

        let body: [String: Any] = [
            "column_name": columnName,
            "value": jsonValue,
            "user_email": userEmail
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(NetworkError.encodingError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            switch httpResponse.statusCode {
            case 200:
                completion(.success(()))
            default:
                if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                    completion(.failure(NetworkError.serverError(errorMessage)))
                } else {
                    completion(.failure(NetworkError.unknownError))
                }
            }
        }.resume()
    }

    
    func createPodItem(
        podId: Int,
        label: String,
        itemType: String?,
        notes: String,
        columnValues: [String: ColumnValue],
        completion: @escaping (Result<PodItem, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/create-pod-item/\(podId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        // Map ColumnValue to a JSON-compatible structure
        let body: [String: Any] = [
            "label": label,
            "notes": notes,
            "itemType": itemType ?? "",
            "columnValues": columnValues.mapValues { mapColumnValueToJSON($0) }
        ]

        print("Request body: \(body)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                print("No data received")
                completion(.failure(NetworkError.noData))
                return
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw response: \(responseString)")
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("Parsed JSON: \(json)")
                    
                    if let error = json["error"] as? String {
                        print("Server error: \(error)")
                        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: error])))
                        return
                    }
                    
                    if let itemData = json["item"] as? [String: Any] {
                        let id = itemData["id"] as? Int ?? 0
                        let label = itemData["label"] as? String ?? ""
                        let itemType = itemData["itemType"] as? String
                        let notes = itemData["notes"] as? String ?? ""
                        let columnValues = (itemData["columnValues"] as? [String: Any])?.compactMapValues { value -> ColumnValue? in
                            if let stringValue = value as? String {
                                if let timeValue = TimeValue.fromString(stringValue) {
                                    return .time(timeValue)
                                }
                                return .string(stringValue)
                            } else if let doubleValue = value as? Double {
                                return .number(doubleValue)
                            } else if let intValue = value as? Int {
                                return .number(Double(intValue))
                            } else if let arrayValue = value as? [Any] {
                                return .array(arrayValue.compactMap { self.mapJSONToColumnValue($0) })
                            } else if value is NSNull {
                                return .null
                            }
                            return nil
                        } ?? [:]
                        
                        let newItem = PodItem(
                            id: id,
                            metadata: label,
                            itemType: itemType,
                            notes: notes,
                            columnValues: columnValues
                        )
                        completion(.success(newItem))
                    } else {
                        print("Failed to parse item data")
                        completion(.failure(NetworkError.decodingError))
                    }
                } else {
                    print("Failed to parse JSON")
                    completion(.failure(NetworkError.decodingError))
                }
            } catch {
                print("JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    // Helper function to map ColumnValue to a JSON-compatible format
    private func mapColumnValueToJSON(_ value: ColumnValue) -> Any {
        switch value {
        case .number(let num):
            return num
        case .string(let str):
            return str
        case .time(let timeValue):
            return timeValue.toString
        case .array(let array):
            return array.map { mapColumnValueToJSON($0) }
        case .null:
            return NSNull()
        }
    }

    // Helper function to map JSON back to ColumnValue
    private func mapJSONToColumnValue(_ value: Any) -> ColumnValue? {
        if let stringValue = value as? String {
            if let timeValue = TimeValue.fromString(stringValue) {
                return .time(timeValue)
            }
            return .string(stringValue)
        } else if let doubleValue = value as? Double {
            return .number(doubleValue)
        } else if let intValue = value as? Int {
            return .number(Double(intValue))  // Convert Int to Double
        } else if let arrayValue = value as? [Any] {
            return .array(arrayValue.compactMap { mapJSONToColumnValue($0) })
        } else if value is NSNull {
            return .null
        }
        return nil
    }

    func updatePodItem(itemId: Int, newLabel: String, newNotes: String, newColumnValues: [String: ColumnValue], userEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/update-pod-item/\(itemId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let columnValuesJson = newColumnValues.mapValues { value -> Any in
            switch value {
            case .string(let str):
                return str
            case .number(let num):
                return num
            case .time(let timeValue):
                return timeValue.toString
            case .array(let array):
                return array.map { $0.description } // Convert array elements to strings
            case .null:
                return NSNull()
            }
        }

        let body: [String: Any] = [
            "label": newLabel,
            "notes": newNotes,
            "columnValues": columnValuesJson,
            "user_email": userEmail
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(NetworkError.encodingError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            switch httpResponse.statusCode {
            case 200:
                completion(.success(()))
            default:
                if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                    completion(.failure(NetworkError.serverError(errorMessage)))
                } else {
                    completion(.failure(NetworkError.unknownError))
                }
            }
        }.resume()
    }

    
    func addColumnToPod(podId: Int, columnName: String, columnType: String, completion: @escaping (Result<PodColumn, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/add-column-to-pod/\(podId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let body: [String: Any] = [
            "name": columnName,
            "type": columnType
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(NetworkError.encodingError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let columnData = json["column"] as? [String: Any] {
                    let columnJson = try JSONSerialization.data(withJSONObject: columnData)
                    let column = try JSONDecoder().decode(PodColumn.self, from: columnJson)
                    completion(.success(column))
                } else {
                    completion(.failure(NetworkError.decodingError))
                }
            } catch {
                completion(.failure(NetworkError.decodingError))
            }
        }.resume()
    }

    
    func deleteColumnFromPod(podId: Int, columnName: String, completion: @escaping (Result<Void, Error>) -> Void) {
           guard let url = URL(string: "\(baseUrl)/delete-column-from-pod/\(podId)/") else {
               completion(.failure(NetworkError.invalidURL))
               return
           }

           let body: [String: Any] = [
               "name": columnName
           ]

           var request = URLRequest(url: url)
           request.httpMethod = "POST"
           request.setValue("application/json", forHTTPHeaderField: "Content-Type")

           do {
               request.httpBody = try JSONSerialization.data(withJSONObject: body)
           } catch {
               completion(.failure(NetworkError.encodingError))
               return
           }

           URLSession.shared.dataTask(with: request) { data, response, error in
               if let error = error {
                   completion(.failure(error))
                   return
               }

               guard let httpResponse = response as? HTTPURLResponse else {
                   completion(.failure(NetworkError.invalidResponse))
                   return
               }

               switch httpResponse.statusCode {
               case 200:
                   completion(.success(()))
               default:
                   if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                       completion(.failure(NetworkError.serverError(errorMessage)))
                   } else {
                       completion(.failure(NetworkError.unknownError))
                   }
               }
           }.resume()
       }
    
    func updateColumnGrouping(podId: Int, columnName: String, groupingType: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/update-column-grouping/\(podId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let body: [String: Any] = [
            "name": columnName,
            "grouping_type": groupingType
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(NetworkError.encodingError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            switch httpResponse.statusCode {
            case 200:
                completion(.success(()))
            default:
                if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                    completion(.failure(NetworkError.serverError(errorMessage)))
                } else {
                    completion(.failure(NetworkError.unknownError))
                }
            }
        }.resume()
    }

    
 
        func updateVisibleColumns(podId: Int, columns: [String], completion: @escaping (Result<Void, Error>) -> Void) {
            guard let url = URL(string: "\(baseUrl)/update-visible-columns/\(podId)/") else {
                completion(.failure(NetworkError.invalidURL))
                return
            }

            let body: [String: Any] = [
                "visible_columns": columns
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(NetworkError.encodingError))
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }

                switch httpResponse.statusCode {
                case 200:
                    completion(.success(()))
                default:
                    if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                        completion(.failure(NetworkError.serverError(errorMessage)))
                    } else {
                        completion(.failure(NetworkError.unknownError))
                    }
                }
            }.resume()
        }
    
    func moveItemToPod(itemId: Int, fromPodId: Int, toPodId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
         guard let url = URL(string: "\(baseUrl)/move-item-to-pod/") else {
             completion(.failure(NetworkError.invalidURL))
             return
         }

         let body: [String: Any] = [
             "item_id": itemId,
             "from_pod_id": fromPodId,
             "to_pod_id": toPodId
         ]

         var request = URLRequest(url: url)
         request.httpMethod = "POST"
         request.setValue("application/json", forHTTPHeaderField: "Content-Type")

         do {
             request.httpBody = try JSONSerialization.data(withJSONObject: body)
         } catch {
             completion(.failure(NetworkError.encodingError))
             return
         }

         URLSession.shared.dataTask(with: request) { data, response, error in
             if let error = error {
                 completion(.failure(error))
                 return
             }

             guard let httpResponse = response as? HTTPURLResponse else {
                 completion(.failure(NetworkError.invalidResponse))
                 return
             }

             switch httpResponse.statusCode {
             case 200...299:
                 completion(.success(()))
             default:
                 if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                     completion(.failure(NetworkError.serverError(errorMessage)))
                 } else {
                     completion(.failure(NetworkError.unknownError))
                 }
             }
         }.resume()
     }
    

    func sharePod(podId: Int, userEmail: String, completion: @escaping (Result<PodInvitation, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/share-pod/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let body: [String: Any] = [
            "pod_id": podId,
            "user_email": userEmail
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(NetworkError.encodingError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.decodingError))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let shareUrl = json["shareUrl"] as? String,
                   let podId = json["podId"] as? Int,
                   let userName = json["userName"] as? String,
                   let userEmail = json["userEmail"] as? String,
                   let invitationType = json["invitationType"] as? String,
                   let podName = json["podName"] as? String {
                    let invitation = PodInvitation(id: 0, podId: podId, token: shareUrl, userName: userName, userEmail: userEmail, podName: podName, invitationType: invitationType)
                    completion(.success(invitation))
                } else {
                    completion(.failure(NetworkError.decodingError))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    

    func acceptPodInvitation(podId: Int, token: String, userEmail: String, invitationType: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/accept-pod-invitation/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let body: [String: Any] = [
            "pod_id": podId,
            "token": token,
            "user_email": userEmail,
            "invitation_type": invitationType
        ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(NetworkError.encodingError))
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }

                switch httpResponse.statusCode {
                case 200...299:
                    completion(.success(()))
                default:
                    if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                        completion(.failure(NetworkError.serverError(errorMessage)))
                    } else {
                        completion(.failure(NetworkError.unknownError))
                    }
                }
            }.resume()
        }
    
    func fetchInvitationDetails(token: String, completion: @escaping (Result<PodInvitation, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/get-invitation-details/\(token)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.decodingError))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let podId = json["podId"] as? Int,
                   let podName = json["podName"] as? String,
                   let inviterName = json["inviterName"] as? String,
                    let invitationType = json["invitationType"] as? String,
                   let inviterEmail = json["inviterEmail"] as? String {
                    let invitation = PodInvitation(id: 0, podId: podId, token: token, userName: inviterName, userEmail: inviterEmail, podName: podName, invitationType: invitationType)
                    completion(.success(invitation))
                } else {
                    completion(.failure(NetworkError.decodingError))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchTeamInvitationDetails(token: String, completion: @escaping (Result<TeamInvitation, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/get-team-invitation-details/\(token)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let teamId = json["teamId"] as? Int,
                   let teamName = json["teamName"] as? String,
                   let inviterName = json["inviterName"] as? String,
                   let invitationType = json["invitationType"] as? String,
                   let inviterEmail = json["inviterEmail"] as? String {
                    let invitation = TeamInvitation(
                        id: 0,
                        teamId: teamId,
                        token: token,
                        userName: inviterName,
                        userEmail: inviterEmail,
                        teamName: teamName,
                        invitationType: invitationType
                    )
                    completion(.success(invitation))
                } else {
                    completion(.failure(NetworkError.decodingError))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    
    func acceptTeamInvitation(token: String, userEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/accept-team-invitation/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let body: [String: Any] = [
            "token": token,
            "user_email": userEmail
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(NetworkError.encodingError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            switch httpResponse.statusCode {
            case 200:
                completion(.success(()))
            case 404:
                completion(.failure(NetworkError.noData))
            default:
                completion(.failure(NetworkError.unknownError))
            }
        }.resume()
    }
    
    
    func fetchPodDetails(podId: Int, completion: @escaping (Result<PodDetails, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/get-pod-details/\(podId)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let podDetails = try JSONDecoder().decode(PodDetails.self, from: data)
                completion(.success(podDetails))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    
    


    func updatePodDetails(
        podId: Int,
        title: String,
        description: String,
        instructions: String,
        type: String,
        privacy: String,
        completion: @escaping (Result<(String, String, String, String, String), Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/update-pod-details/\(podId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "title": title,
            "description": description,
            "instructions": instructions,
            "type": type,
            "privacy": privacy
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                if let json = json,
                   let podData = json["pod"] as? [String: Any],
                   let updatedTitle = podData["title"] as? String {
                    // Use nil coalescing to provide default empty strings
                    let updatedDescription = (podData["description"] as? String) ?? ""
                    let updatedInstructions = (podData["instructions"] as? String) ?? ""
                    let updatedType = (podData["type"] as? String) ?? "custom"
                    let updatedPrivacy = (podData["privacy"] as? String) ?? "private"
                    
                    completion(.success((
                        updatedTitle,
                        updatedDescription,
                        updatedInstructions,
                        updatedType,
                        updatedPrivacy
                    )))
                } else {
                    // Add more detailed error logging
                    print("Failed to decode response. Pod data received: \(String(describing: json?["pod"]))")
                    completion(.failure(NetworkError.decodingError))
                }
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchTeamDetails(teamId: Int, userEmail: String, completion: @escaping (Result<TeamDetails, Error>) -> Void) {
        guard var urlComponents = URLComponents(string: "\(baseUrl)/get-team-details/\(teamId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "email", value: userEmail)]
        
        guard let url = urlComponents.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            do {
                let teamDetails = try JSONDecoder().decode(TeamDetails.self, from: data)
                completion(.success(teamDetails))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func updateTeamDetails(teamId: Int, name: String, description: String, completion: @escaping (Result<(String, String), Error>) -> Void) {
        let url = URL(string: "\(baseUrl)/update-team-details/\(teamId)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "description": description
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            do {
                let response = try JSONDecoder().decode(TeamUpdateResponse.self, from: data)
                completion(.success((response.team.name, response.team.description)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchPodMembers(podId: Int, userEmail: String, completion: @escaping (Result<([PodMember], String, String), Error>) -> Void) {
        let urlString = "\(baseUrl)/get-pod-members/\(podId)/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["userEmail": userEmail]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let membersData = json["members"] as? [[String: Any]],
                   let userRole = json["userRole"] as? String,
                   let podType = json["podType"] as? String {
                    
                    let members = membersData.compactMap { memberDict -> PodMember? in
                        guard let id = memberDict["id"] as? Int,
                              let name = memberDict["name"] as? String,
                              let email = memberDict["email"] as? String,
                              let profileInitial = memberDict["profileInitial"] as? String,
                              let profileColor = memberDict["profileColor"] as? String,
                              let role = memberDict["role"] as? String else {
                            return nil
                        }
                        return PodMember(id: id, name: name, email: email, profileInitial: profileInitial, profileColor: profileColor, role: role)
                    }
                    
                    completion(.success((members, userRole, podType)))
                } else {
                    completion(.failure(NetworkError.decodingError))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
        
    }
    
    func updatePodMembership(podId: Int, memberId: Int, newRole: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/update-pod-membership/\(podId)/\(memberId)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["role": newRole]
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            completion(.success(()))
        }.resume()
    }
    
    func removePodMember(podId: Int, memberId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
          guard let url = URL(string: "\(baseUrl)/remove-pod-member/\(podId)/\(memberId)") else {
              completion(.failure(NetworkError.invalidURL))
              return
          }

          var request = URLRequest(url: url)
          request.httpMethod = "DELETE"

          URLSession.shared.dataTask(with: request) { data, response, error in
              if let error = error {
                  completion(.failure(error))
                  return
              }

              guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode) else {
                  completion(.failure(NetworkError.invalidResponse))
                  return
              }

              completion(.success(()))
          }.resume()
      }
    
    
    func fetchTeamMembers(teamId: Int, completion: @escaping (Result<[TeamMember], Error>) -> Void) {
          guard let url = URL(string: "\(baseUrl)/get-team-members/\(teamId)/") else {
              completion(.failure(NetworkError.invalidURL))
              return
          }

          let task = URLSession.shared.dataTask(with: url) { data, response, error in
              if let error = error {
                  completion(.failure(error))
                  return
              }

              guard let data = data else {
                  completion(.failure(NetworkError.noData))
                  return
              }

              do {
                  let teamMembers = try JSONDecoder().decode(TeamMembersResponse.self, from: data)
                  completion(.success(teamMembers.members))
              } catch {
                  completion(.failure(error))
              }
          }

          task.resume()
      }
    
    func updateActiveTeam(email: String, teamId: Int, completion: @escaping (Result<Int, Error>) -> Void) {
           guard let url = URL(string: "\(baseUrl)/update-active-team/") else {
               completion(.failure(NetworkError.invalidURL))
               return
           }

           let body: [String: Any] = ["email": email, "teamId": teamId]
           var request = URLRequest(url: url)
           request.httpMethod = "POST"
           request.setValue("application/json", forHTTPHeaderField: "Content-Type")
           request.httpBody = try? JSONSerialization.data(withJSONObject: body)

           URLSession.shared.dataTask(with: request) { data, response, error in
               if let error = error {
                   completion(.failure(error))
                   return
               }

               guard let data = data else {
                   completion(.failure(NetworkError.noData))
                   return
               }

               do {
                   if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let activeTeamId = json["activeTeamId"] as? Int {
                       completion(.success(activeTeamId))
                   } else {
                       completion(.failure(NetworkError.decodingError))
                   }
               } catch {
                   completion(.failure(error))
               }
           }.resume()
       }
    
    func invitePodMember(podId: Int, inviterEmail: String, inviteeEmail: String, role: String, completion: @escaping (Result<Void, Error>) -> Void) {
           guard let url = URL(string: "\(baseUrl)/invite-pod-member/") else {
               completion(.failure(NetworkError.invalidURL))
               return
           }

           let body: [String: Any] = [
               "pod_id": podId,
               "inviter_email": inviterEmail,
               "invitee_email": inviteeEmail,
               "role": role
           ]

          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")

          do {
              request.httpBody = try JSONSerialization.data(withJSONObject: body)
          } catch {
              completion(.failure(NetworkError.encodingError))
              return
          }

          URLSession.shared.dataTask(with: request) { data, response, error in
              if let error = error {
                  completion(.failure(error))
                  return
              }

              guard let httpResponse = response as? HTTPURLResponse else {
                  completion(.failure(NetworkError.invalidResponse))
                  return
              }

              if (200...299).contains(httpResponse.statusCode) {
                  completion(.success(()))
              } else {
                  completion(.failure(NetworkError.decodingError))
              }
          }.resume()
      }


    func createActivityLog(
           itemId: Int,
           podId: Int,
           userEmail: String,
           columnValues: [String: ColumnValue],
           podColumns: [PodColumn],
           notes: String,
           loggedAt: Date,
           completion: @escaping (Result<PodItemActivityLog, Error>) -> Void
       ) {
           guard let url = URL(string: "\(baseUrl)/create-activity-log/") else {
               completion(.failure(NetworkError.invalidURL))
               return
           }

           // Convert ColumnValue to serializable dictionary
           let columnValuesJson = columnValues.mapValues { value -> Any in
               switch value {
               case .string(let str):
                   return str
               case .number(let num):
                   return num
               case .time(let timeValue):
                   return timeValue.toString
               case .array(let array):
                   // Handle array elements consistently
                   return array.map { element -> Any in
                       switch element {
                       case .string(let str):
                           return str
                       case .number(let num):
                           return num
                       case .time(let timeValue):
                           return timeValue.toString
                       case .array:
                           return NSNull() // Nested arrays not supported
                       case .null:
                           return NSNull()
                       }
                   }
               case .null:
                   return NSNull()
               }
           }

           let body: [String: Any] = [
               "itemId": itemId,
               "podId": podId,
               "userEmail": userEmail,
               "columnValues": columnValuesJson,
               "notes": notes,
               "loggedAt": loggedAt.ISO8601Format()
           ]

           print("Request body: \(body)")

           var request = URLRequest(url: url)
           request.httpMethod = "POST"
           request.setValue("application/json", forHTTPHeaderField: "Content-Type")

           do {
               request.httpBody = try JSONSerialization.data(withJSONObject: body)
           } catch {
               print("Serialization error:", error)
               completion(.failure(NetworkError.encodingError))
               return
           }

           URLSession.shared.dataTask(with: request) { data, response, error in
               if let error = error {
                   print("Network error: \(error.localizedDescription)")
                   completion(.failure(error))
                   return
               }

               guard let httpResponse = response as? HTTPURLResponse else {
                   completion(.failure(NetworkError.invalidResponse))
                   return
               }

               guard let data = data else {
                   print("No data received from server")
                   completion(.failure(NetworkError.noData))
                   return
               }

               switch httpResponse.statusCode {
               case 200, 201:
                   do {
                       let decoder = JSONDecoder()
                       let logJSON = try decoder.decode(PodItemActivityLogJSON.self, from: data)
                       let activityLog = try PodItemActivityLog(from: logJSON)
                       completion(.success(activityLog))
                   } catch {
                       print("JSON parsing error: \(error.localizedDescription)")
                       if let dataString = String(data: data, encoding: .utf8) {
                           print("Received data:", dataString)
                       }
                       completion(.failure(error))
                   }
               default:
                   if let errorMessage = String(data: data, encoding: .utf8) {
                       completion(.failure(NetworkError.serverError(errorMessage)))
                   } else {
                       completion(.failure(NetworkError.unknownError))
                   }
               }
           }.resume()
       }
    

    
    func createActivity(
        podId: Int,
        userEmail: String,
        duration: Int,
        notes: String?,
        items: [(id: Int, notes: String?, columnValues: [String: Any])],
        isSingleItem: Bool = false,  // Add isSingleItem parameter with default value
        completion: @escaping (Result<Activity, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/create-activity/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let itemsData = items.map { item in
            [
                "itemId": item.id,
                "notes": item.notes ?? "",
                "columnValues": item.columnValues
            ]
        }
        
        let parameters: [String: Any] = [
            "podId": podId,
            "userEmail": userEmail,
            "duration": duration,
            "notes": notes ?? "",
            "loggedAt": ISO8601DateFormatter().string(from: Date()),
            "items": itemsData,
            "is_single_item": isSingleItem  // Add is_single_item to parameters
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let activity = try decoder.decode(Activity.self, from: data)
                completion(.success(activity))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateActivity(
        activityId: Int,
        userEmail: String,
        notes: String?,
        items: [(id: Int, notes: String?, columnValues: [String: Any])],
        completion: @escaping (Result<Activity, Error>) -> Void
    ) {
        // 1) Construct the URL for your "update-activity/<id>/" endpoint
        let urlString = "\(baseUrl)/update-activity/\(activityId)/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // 2) Build the items data array
        let itemsData = items.map { item in
            [
                "itemId": item.id,
                "notes": item.notes ?? "",
                "columnValues": item.columnValues
            ]
        }
        
        // 3) Create the request body
        let parameters: [String: Any] = [
            "userEmail": userEmail,
            "notes": notes ?? "",
            "items": itemsData
        ]
        
        // 4) Set up the URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"  // or PATCH, depending on your backend
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        // 5) Make the network call
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle client-side errors
            if let error = error {
                print("Network error in updateActivity: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("No data received in updateActivity")
                completion(.failure(NetworkError.noData))
                return
            }
            
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw response from updateActivity: \(responseString)")
            }
            
            // 6) Decode the updated Activity
            do {
                let decoder = JSONDecoder()
                let updatedActivity = try decoder.decode(Activity.self, from: data)
                print("Successfully decoded updated activity: \(updatedActivity.id)")
                
                // Debug column values for each item
                for item in updatedActivity.items {
                    print("NetworkManager - Item \(item.id) column values from JSON: \(item.columnValues.keys)")
                }
                
                completion(.success(updatedActivity))
            } catch {
                print("Decoding error in updateActivity: \(error)")
                print("Decoding error details: \(error.localizedDescription)")
                
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Missing key: \(key.stringValue) in \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch: expected \(type) in \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("Value not found: expected \(type) in \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context)")
                    @unknown default:
                        print("Unknown decoding error: \(decodingError)")
                    }
                }
                
                completion(.failure(error))
            }
        }.resume()
    }

    
    //new
    func fetchUserActivities(podId: Int, userEmail: String, page: Int = 1, completion: @escaping (Result<(activities: [Activity], hasMore: Bool), Error>) -> Void) {
            let encodedEmail = userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "\(baseUrl)/get-user-activities/\(podId)/\(encodedEmail)/?page=\(page)"
            
            guard let url = URL(string: urlString) else {
                completion(.failure(NetworkError.invalidURL))
                return
            }
            
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(ActivityResponse.self, from: data)
                    completion(.success((activities: response.activities, hasMore: response.hasMore)))
                } catch {
                    completion(.failure(error))
                }
            }
            task.resume()
        }
        
        // Fetch a single activity by ID
        func fetchActivity(id: Int, podId: Int, userEmail: String, completion: @escaping (Result<Activity, Error>) -> Void) {
            let encodedEmail = userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "\(baseUrl)/get-activity/\(podId)/\(id)/\(encodedEmail)/"
            
            print("Fetching activity with URL: \(urlString)")
            
            guard let url = URL(string: urlString) else {
                completion(.failure(NetworkError.invalidURL))
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                // Log the raw response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON from get_activity: \(jsonString)")
                }
                
                do {
                    let decoder = JSONDecoder()
                    let activity = try decoder.decode(Activity.self, from: data)
                    print("Successfully decoded activity from server: \(activity.id)")
                    completion(.success(activity))
                } catch let decodingError {
                    print("Failed to decode activity: \(decodingError)")
                    completion(.failure(decodingError))
                }
            }.resume()
        }
        
        func fetchUserActivityItems(podId: Int, userEmail: String, page: Int = 1, completion: @escaping (Result<(items: [ActivityItem], hasMore: Bool), Error>) -> Void) {
            let encodedEmail = userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "\(baseUrl)/get-user-activity-items/\(podId)/\(encodedEmail)/?page=\(page)"
            
            guard let url = URL(string: urlString) else {
                completion(.failure(NetworkError.invalidURL))
                return
            }
            
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(ActivityItemsResponse.self, from: data)
                    completion(.success((items: response.items, hasMore: response.hasMore)))
                } catch {
                    completion(.failure(error))
                }
            }
            task.resume()
        }
        
        func deleteActivity(activityId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
            let urlString = "\(baseUrl)/delete-activity/\(activityId)/"
            guard let url = URL(string: urlString) else {
                completion(.failure(NetworkError.invalidURL))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    completion(.success(()))
                } else {
                    completion(.failure(NetworkError.decodingError))
                }
            }
            task.resume()
        }
        
        func createSingleItemActivity(podId: Int,
                                    userEmail: String,
                                    itemId: Int,
                                    notes: String?,
                                    columnValues: [String: ColumnValue],
                                    completion: @escaping (Result<Activity, Error>) -> Void) {
            let urlString = "\(baseUrl)/create-single-item-activity/"
            guard let url = URL(string: urlString) else {
                completion(.failure(NetworkError.invalidURL))
                return
            }
            
            let parameters: [String: Any] = [
                "podId": podId,
                "userEmail": userEmail,
                "itemId": itemId,
                "notes": notes ?? "",
                "columnValues": columnValues
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            } catch {
                completion(.failure(error))
                return
            }
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let activity = try decoder.decode(Activity.self, from: data)
                    completion(.success(activity))
                } catch {
                    completion(.failure(error))
                }
            }
            task.resume()
        }

    
    func addMediaToItem(podId: Int, itemId: Int, mediaType: String, mediaURL: URL? = nil, image: UIImage? = nil, completion: @escaping (Bool, Error?) -> Void) {
        guard let containerName = ConfigurationManager.shared.getValue(forKey: "BLOB_CONTAINER") as? String else {
            completion(false, NSError(domain: "ConfigurationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No container name found."]))
            return
        }

        let blobName = UUID().uuidString + (mediaType == "video" ? ".mp4" : ".jpg")
        let contentType = mediaType == "video" ? "video/mp4" : "image/jpeg"

        var fileData: Data?
        if let mediaURL = mediaURL, mediaType == "video" {
            do {
                fileData = try Data(contentsOf: mediaURL)
            } catch {
                completion(false, error)
                return
            }
        } else if let image = image, mediaType == "image" {
            fileData = image.jpegData(compressionQuality: 0.8)
        }

        guard let data = fileData else {
            completion(false, NSError(domain: "DataError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare file data."]))
            return
        }

        uploadFileToAzureBlob(containerName: containerName, blobName: blobName, fileData: data, contentType: contentType) { success, blobUrl in
            if success, let url = blobUrl {
                self.updateItemWithMediaUrl(podId: podId, itemId: itemId, mediaType: mediaType, mediaUrl: url, completion: completion)
            } else {
                completion(false, NSError(domain: "UploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to upload media to Azure Blob."]))
            }
        }
    }

        private func updateItemWithMediaUrl(podId: Int, itemId: Int, mediaType: String, mediaUrl: String, completion: @escaping (Bool, Error?) -> Void) {
            let urlString = "\(baseUrl)/add-media-to-item/\(podId)/\(itemId)/"
            guard let url = URL(string: urlString) else {
                completion(false, NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "mediaType": mediaType,
                "mediaUrl": mediaUrl
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(false, error)
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(false, error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    completion(false, NSError(domain: "ServerError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server returned an error"]))
                    return
                }

                completion(true, nil)
            }.resume()
        }
  

    
    func fetchPodItem(podId: Int, itemId: Int, userEmail: String, completion: @escaping (Result<PodItem, Error>) -> Void) {
        let urlString = "\(baseUrl)/fetch-pod-item/\(podId)/\(itemId)/?user_email=\(userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let podItemJSON = try decoder.decode(PodItemJSON.self, from: data)
                let podItem = PodItem(from: podItemJSON)
                completion(.success(podItem))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    
    func fetchSubscriptionInfo(for email: String, completion: @escaping (Result<SubscriptionInfo, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/fetch-subscription-info/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }

            do {
                let subscriptionInfo = try JSONDecoder().decode(SubscriptionInfo.self, from: data)
                completion(.success(subscriptionInfo))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
 
        func createWorkspace(name: String, description: String, isPrivate: Bool, teamId: Int, email: String, completion: @escaping (Result<Workspace, Error>) -> Void) {
            guard let url = URL(string: "\(baseUrl)/create-workspace/") else {
                completion(.failure(NetworkError.invalidURL))
                return
            }

            let body: [String: Any] = [
                "name": name,
                "description": description,
                "is_private": isPrivate,
                "team_id": teamId,
                "email": email
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }

                do {
                    let workspace = try JSONDecoder().decode(Workspace.self, from: data)
                    completion(.success(workspace))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }

    func createTeam(name: String, email: String, completion: @escaping (Result<Team, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/create-team/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let body = ["name": name, "email": email]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }

            do {
                if let httpResponse = response as? HTTPURLResponse,
                   (400...499).contains(httpResponse.statusCode),
                   let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)["error"] {
                    completion(.failure(NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                } else {
                    let team = try JSONDecoder().decode(Team.self, from: data)
                    completion(.success(team))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func shareTeam(teamId: Int, userEmail: String, completion: @escaping (Result<TeamInvitation, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/share-team/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let body: [String: Any] = [
            "team_id": teamId,
            "user_email": userEmail
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(NetworkError.encodingError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.decodingError))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let shareUrl = json["shareUrl"] as? String,
                   let teamId = json["teamId"] as? Int,
                   let userName = json["userName"] as? String,
                   let userEmail = json["userEmail"] as? String,
                   let invitationType = json["invitationType"] as? String,
                   let teamName = json["teamName"] as? String {
                    let invitation = TeamInvitation(id: 0, teamId: teamId, token: shareUrl, userName: userName, userEmail: userEmail, teamName: teamName, invitationType: invitationType)
                    completion(.success(invitation))
                } else {
                    completion(.failure(NetworkError.decodingError))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func removeTeamMember(teamId: Int, memberId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
            let url = URL(string: "\(baseUrl)/remove-team-member/\(teamId)/\(memberId)/")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    completion(.success(()))
                } else {
                    completion(.failure(NetworkError.unknownError))
                }
            }.resume()
        }
    
    func updateTeamMembership(teamId: Int, memberId: Int, newRole: String, completion: @escaping (Result<Void, Error>) -> Void) {
            let url = URL(string: "\(baseUrl)/update-team-membership/\(teamId)/\(memberId)/")!
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = ["role": newRole]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    completion(.success(()))
                } else {
                    completion(.failure(NetworkError.unknownError))
                }
            }.resume()
        }
    
    func inviteTeamMember(teamId: Int, inviterEmail: String, inviteeEmail: String, role: String, completion: @escaping (Result<Void, Error>) -> Void) {
          let url = URL(string: "\(baseUrl)/invite-team-member/")!
          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")

          let body: [String: Any] = [
              "team_id": teamId,
              "inviter_email": inviterEmail,
              "invitee_email": inviteeEmail,
              "role": role
          ]

          request.httpBody = try? JSONSerialization.data(withJSONObject: body)

          URLSession.shared.dataTask(with: request) { data, response, error in
              if let error = error {
                  completion(.failure(error))
                  return
              }
              if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                  completion(.success(()))
              } else {
                  completion(.failure(NetworkError.unknownError))
              }
          }.resume()
      }
    

    func purchaseSubscription(userEmail: String, productId: String, transactionId: String) async throws -> [String: Any] {
           guard let url = URL(string: "\(baseUrl)/purchase-subscription/") else {
               throw NetworkError.invalidURL
           }

           let body: [String: Any] = [
               "user_email": userEmail,
               "product_id": productId,
               "transaction_id": transactionId
           ]
           
           var request = URLRequest(url: url)
           request.httpMethod = "POST"
           request.addValue("application/json", forHTTPHeaderField: "Content-Type")
           request.httpBody = try JSONSerialization.data(withJSONObject: body)

           let (data, response) = try await URLSession.shared.data(for: request)

           guard let httpResponse = response as? HTTPURLResponse else {
               throw NetworkError.invalidResponse
           }

           if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
               guard let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                   throw NetworkError.decodingError
               }
               return jsonResult
           } else {
               throw NetworkError.serverError("Status code: \(httpResponse.statusCode)")
           }
       }
   

    func updateSubscription(userEmail: String, productId: String, transactionId: String) async throws -> [String: Any] {
           guard let url = URL(string: "\(baseUrl)/update-subscription/") else {
               throw NetworkError.invalidURL
           }

           let body: [String: Any] = [
               "user_email": userEmail,
               "product_id": productId,
               "transaction_id": transactionId
           ]

           var request = URLRequest(url: url)
           request.httpMethod = "POST"
           request.addValue("application/json", forHTTPHeaderField: "Content-Type")
           request.httpBody = try JSONSerialization.data(withJSONObject: body)

           let (data, response) = try await URLSession.shared.data(for: request)

           guard let httpResponse = response as? HTTPURLResponse else {
               throw NetworkError.invalidResponse
           }

           if httpResponse.statusCode == 200 {
               return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
           } else {
               throw NetworkError.serverError("Status code: \(httpResponse.statusCode)")
           }
       }

    func cancelSubscription(userEmail: String) async throws -> [String: Any] {
            guard let url = URL(string: "\(baseUrl)/cancel-subscription/") else {
                throw NetworkError.invalidURL
            }

            let body: [String: Any] = [
                "user_email": userEmail
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                guard let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw NetworkError.decodingError
                }
                return jsonResult
            } else {
                throw NetworkError.serverError("Status code: \(httpResponse.statusCode)")
            }
        }

    
    func renewSubscription(userEmail: String) async throws -> [String: Any] {
            guard let url = URL(string: "\(baseUrl)/renew-subscription/") else {
                throw NetworkError.invalidURL
            }

            let body: [String: Any] = [
                "user_email": userEmail
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                guard let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw NetworkError.decodingError
                }
                return jsonResult
            } else {
                throw NetworkError.serverError("Status code: \(httpResponse.statusCode)")
            }
        }
    
    func deleteActivityLog(logId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/delete-activity-log/\(logId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            if httpResponse.statusCode == 200 {
                completion(.success(()))
            } else {
                completion(.failure(NetworkError.invalidResponse))
            }
        }.resume()
    }
 

    func updateSubscriptionStatus(userEmail: String, productId: String, status: String, willRenew: Bool, expirationDate: String?) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseUrl)/update-subscription-status/") else {
            throw NetworkError.invalidURL
        }

        let body: [String: Any] = [
            "user_email": userEmail,
            "product_id": productId,
            "status": status,
            "will_renew": willRenew,
            "expiration_date": expirationDate ?? NSNull()
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            guard let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NetworkError.decodingError
            }
            return jsonResult
        } else {
            throw NetworkError.serverError("Status code: \(httpResponse.statusCode)")
        }
        
     
    }
    

    
    func sendMessageToGracie(
        message: String,
        activityLogs: [PodItemActivityLog],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/gracie-chat/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Convert activity logs to a serializable format
        let logsData = activityLogs.map { log -> [String: Any] in
            let serializedColumnValues = log.columnValues.mapValues { columnValue -> Any in
                switch columnValue {
                case .string(let str):
                    return str
                case .number(let num):
                    return num // Keep numbers as `Double` for JSON compatibility
                case .time(let timeValue):
                    return timeValue.toString
                case .array(let array):
                    // Map array elements to their serializable values
                    return array.map { columnValue -> Any in
                        switch columnValue {
                        case .string(let str):
                            return str
                        case .number(let num):
                            return num.description  // Convert to string since we're dealing with strings
                        case .time(let timeValue):
                            return timeValue.toString
                        case .array(_):  // Handle nested arrays (though we shouldn't have any)
                            return "Nested Array"
                        case .null:
                            return ""
                        }
                    }
                case .null:
                    return "" // Treat null values as empty strings for JSON compatibility
                }
            }
            
            return [
                "id": log.id,
                "itemId": log.itemId,
                "itemLabel": log.itemLabel,
                "userEmail": log.userEmail,
                "userName": log.userName,
                "loggedAt": ISO8601DateFormatter().string(from: log.loggedAt),
                "columnValues": serializedColumnValues,
                "notes": log.notes
            ]
        }
        
        let payload: [String: Any] = [
            "message": message,
            "activity_logs": logsData
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = jsonData
        } catch {
            print("JSON serialization error: \(error)")
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(GracieResponse.self, from: data)
                completion(.success(response.response))
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }


    func updateColumnOrder(podId: Int, columnOrder: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/update-column-order/\(podId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        guard !columnOrder.isEmpty else {
            completion(.failure(NetworkError.invalidResponse))
            return
        }

        let body: [String: Any] = [
            "columns": columnOrder
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(NetworkError.encodingError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            switch httpResponse.statusCode {
            case 200:
                completion(.success(()))
            default:
                if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                    completion(.failure(NetworkError.serverError(errorMessage)))
                } else {
                    completion(.failure(NetworkError.unknownError))
                }
            }
        }.resume()
    }

    func updatePodColumns(podId: Int, columns: [PodColumn], visibleColumns: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/update-pod-columns/\(podId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Complete payload including names, order, and visibility
        let body: [String: Any] = [
            "columns": columns.map { [
                "id": $0.id, 
                "name": $0.name,
                "type": $0.type,
                "grouping_type": $0.groupingType ?? "singular"
            ]},
            "visible_columns": visibleColumns
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(NetworkError.encodingError))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                completion(.success(()))
            default:
                if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                    completion(.failure(NetworkError.serverError(errorMessage)))
                } else {
                    completion(.failure(NetworkError.unknownError))
                }
            }
        }.resume()
    }
    
    func updateActivityLog(
        logId: Int,
        columnValues: [String: ColumnValue],
        notes: String,
        completion: @escaping (Result<PodItemActivityLog, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/update-activity-log/\(logId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let columnValuesJson = columnValues.mapValues { value -> Any in
            switch value {
                         case .string(let str):
                             return str
                         case .number(let num):
                             return num
                         case .time(let timeValue):
                             return timeValue.toString
                         case .array(let array):
                             // Handle array elements consistently
                             return array.map { element -> Any in
                                 switch element {
                                 case .string(let str):
                                     return str
                                 case .number(let num):
                                     return num
                                 case .time(let timeValue):
                                     return timeValue.toString
                                 case .array:
                                     return NSNull() // Nested arrays not supported
                                 case .null:
                                     return NSNull()
                                 }
                             }
                         case .null:
                             return NSNull()
                         }
        }

        let body: [String: Any] = [
            "columnValues": columnValuesJson,
            "notes": notes
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Serialization error:", error)  // Add this print statement
            completion(.failure(NetworkError.encodingError))
            return
        }

        // Mirror exactly how createActivityLog handles the URLSession
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            guard let data = data else {
                print("No data received from server")
                completion(.failure(NetworkError.noData))
                return
            }

            switch httpResponse.statusCode {
            case 200:
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
//                    // Try to decode the activity log directly
//                    let activityLog = try decoder.decode(PodItemActivityLog.self, from: data)
//                    completion(.success(activityLog))
                } catch {
                    print("Decoding error: \(error)")
                    if let dataString = String(data: data, encoding: .utf8) {
                        print("Received data:", dataString)
                    }
                    completion(.failure(error))
                }
            default:
                if let errorMessage = String(data: data, encoding: .utf8) {
                    completion(.failure(NetworkError.serverError(errorMessage)))
                } else {
                    completion(.failure(NetworkError.unknownError))
                }
            }
        }
        task.resume()
    }

    private func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = self.iso8601FractionalFormatter.date(from: value) {
                return date
            }
            if let date = self.iso8601Formatter.date(from: value) {
                return date
            }
            if let date = self.dateOnlyFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Invalid ISO8601 date string: \(value)")
        }
        return decoder
    }
    
    func updatePodVisited(podId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
       guard let url = URL(string: "\(baseUrl)/update-pod-visited/\(podId)/") else {
           completion(.failure(NetworkError.invalidURL))
           return
       }
       
       var request = URLRequest(url: url)
       request.httpMethod = "POST"
       request.addValue("application/json", forHTTPHeaderField: "Content-Type")
       
       URLSession.shared.dataTask(with: request) { data, response, error in
           if let error = error {
               completion(.failure(error))
               return
           }
           
           guard let httpResponse = response as? HTTPURLResponse else {
               completion(.failure(NetworkError.invalidResponse))
               return
           }
           
           if httpResponse.statusCode == 200 {
               completion(.success(()))
           } else {
               completion(.failure(NetworkError.unknownError))
           }
       }.resume()
    }
    
    func updatePodsOrder(podIds: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/update-pods-order/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let body = ["pod_ids": podIds]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            if httpResponse.statusCode == 200 {
                completion(.success(()))
            } else {
                completion(.failure(NetworkError.unknownError))
            }
        }.resume()
    }


        func updateFoodLog(userEmail: String, logId: Int, servings: Double? = nil, date: Date? = nil, mealType: String? = nil, notes: String? = nil, completion: @escaping (Result<UpdatedFoodLog, Error>) -> Void) {
            let urlString = "\(baseUrl)/update-food-log/\(logId)/"
            
            guard let url = URL(string: urlString) else {
                completion(.failure(NetworkError.invalidURL))
                return
            }
            
            var parameters: [String: Any] = [
                "user_email": userEmail
            ]
            
            // Add optional parameters
            if let servings = servings {
                parameters["servings"] = servings
            }
            
            if let date = date {
                parameters["date"] = ISO8601DateFormatter().string(from: date)
            }
            
            if let mealType = mealType {
                parameters["meal_type"] = mealType
            }
            
            if let notes = notes {
                parameters["notes"] = notes
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            } catch {
                completion(.failure(error))
                return
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                do {
                    let updateResponse = try JSONDecoder().decode(UpdateFoodLogResponse.self, from: data)
                    completion(.success(updateResponse.food_log))
                } catch {
                    print("Failed to decode update food log response: \(error)")
                    completion(.failure(error))
                }
            }.resume()
        }

        func logFood(userEmail: String, food: Food, mealType: String, servings: Double, date: Date, notes: String? = nil, completion: @escaping (Result<LoggedFood, Error>) -> Void) {
    let urlString = "\(baseUrl)/log-food/"
    
    guard let url = URL(string: urlString) else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    // Get the calories value directly
    let calories = food.calories ?? 0.0
    
    // Format nutrients using camelCase as expected by the backend
    let nutrients = food.foodNutrients.map { nutrient -> [String: Any] in
        [
            "nutrientName": nutrient.nutrientName, 
            "value": nutrient.value ?? 0,
            "unitName": nutrient.unitName
        ]
    }
    
    // DEBUG - Print what we're sending to the server
    print("⬆️ SENDING TO SERVER - logFood:")
    print("- userEmail: \(userEmail)")
    print("- food ID: \(food.fdcId)")
    print("- name: \(food.displayName)")
    print("- mealType: \(mealType)")
    print("- servings: \(servings)")
    print("- calories: \(calories)")
    print("- date: \(ISO8601DateFormatter().string(from: date))")
    
    // Don't send calories directly since the backend calculates it from food.calories * servings
    let parameters: [String: Any] = [
        "user_email": userEmail,
        "food": [
            "fdcId": food.fdcId,
            "description": food.displayName,
            "brandOwner": food.brandText ?? "",
            "servingSize": food.servingSize ?? 0,
            "servingSizeUnit": food.servingSizeUnit ?? "",
            "householdServingFullText": food.servingSizeText,
            "foodNutrients": nutrients
        ],
        "meal_type": mealType,
        "servings": servings,
        "date": ISO8601DateFormatter().string(from: date),
        "notes": notes ?? ""
    ]
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
    } catch {
        completion(.failure(error))
        return
    }
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }
        
        // Check for server error responses
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            // If we get an error response but still have data, try to extract the error message
            if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(errorMessage)))
                }
                return
            }
            
            // Fallback error if we couldn't parse the response
            DispatchQueue.main.async {
                completion(.failure(NetworkError.serverError("Server returned error \(httpResponse.statusCode)")))
            }
            return
        }
        
        guard let data = data else {
            DispatchQueue.main.async {
                completion(.failure(NetworkError.noData))
            }
            return
        }
        
        // Print response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("⬇️ SERVER RESPONSE - logFood: \(responseString)")
        }
        
        do {
            // Try to decode as normal LoggedFood (struct now supports both snake_case and camelCase)
            let decoder = JSONDecoder()
            let loggedFood = try decoder.decode(LoggedFood.self, from: data)
            DispatchQueue.main.async { completion(.success(loggedFood)) }
        } catch {
            print("Decoding failed: \(error)")
            
            // If the standard decoding fails, try to create a LoggedFood object manually
            if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Try to extract data from the response
                let status = "success" // Default to success since we got a response
                let foodLogId = (jsonObj["foodLogId"] as? Int) ?? (jsonObj["food_log_id"] as? Int) ?? 0
                
                // Calculate calories from food.calories * servings
                let calculatedCalories = calories * Double(servings)
                
                let message = jsonObj["message"] as? String ?? "Food logged successfully"
                
                // Extract food data (fallback to original food if not available)
                let foodData = jsonObj["food"] as? [String: Any] ?? [:]
                let fdcId = foodData["fdcId"] as? Int ?? food.fdcId
                let displayName = (foodData["displayName"] as? String) ?? (foodData["display_name"] as? String) ?? food.displayName
                let servingSizeText = food.servingSizeText
                let brandText = food.brandText
                let protein = food.protein
                let carbs = food.carbs
                let fat = food.fat
                
                // Create LoggedFoodItem with proper calories
                let loggedFoodItem = LoggedFoodItem(
                    foodLogId: nil,
                    fdcId: fdcId,
                    displayName: displayName,
                    calories: calculatedCalories / Double(servings), // Per serving
                    servingSizeText: servingSizeText,
                    numberOfServings: Double(servings),
                    brandText: brandText,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    healthAnalysis: nil,
                    foodNutrients: nil
                )
                
                // Create LoggedFood with default status if missing
                let loggedFood = LoggedFood(
                        status: status,
                    foodLogId: foodLogId,
                    calories: calculatedCalories, // Total calories
                    message: message,
                    food: loggedFoodItem,
                    mealType: mealType
                )
                
                DispatchQueue.main.async {
                    completion(.success(loggedFood))
                }
                } else {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }.resume()
}



    func getFoodLogs(userEmail: String, page: Int = 1, completion: @escaping (Result<FoodLogsResponse, Error>) -> Void) {
    guard var urlComponents = URLComponents(string: "\(baseUrl)/get-food-logs/") else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    urlComponents.queryItems = [
        URLQueryItem(name: "user_email", value: userEmail),
        URLQueryItem(name: "page", value: String(page))
    ]
    
    guard let url = urlComponents.url else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            completion(.failure(NetworkError.noData))
            return
        }
        
        do {
            let decoder = JSONDecoder()
            // Remove snake case conversion since backend now sends camelCase directly
            // decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode(FoodLogsResponse.self, from: data)
            completion(.success(response))
            } catch {
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Received JSON:", jsonString)
            }
                completion(.failure(error))
            }
        }.resume()
    }
    
func getCombinedLogs(userEmail: String, page: Int, completion: @escaping (Result<CombinedLogsResponse, Error>) -> Void) {
    guard var urlComponents = URLComponents(string: "\(baseUrl)/get-combined-logs/") else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    urlComponents.queryItems = [
        URLQueryItem(name: "user_email", value: userEmail),
        URLQueryItem(name: "page", value: String(page))
    ]
    
    guard let url = urlComponents.url else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            completion(.failure(NetworkError.noData))
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            
            let response = try decoder.decode(CombinedLogsResponse.self, from: data)
            completion(.success(response))
        } catch {
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Received JSON:", jsonString)
            }
            completion(.failure(error))
        }
    }.resume()
}

func checkAppVersion() async throws -> AppVersionResponse {
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    
    guard let url = URL(string: "\(baseUrl)/check-app-version?version=\(currentVersion)&platform=ios") else {
        throw NetworkError.invalidURL
    }
    
    let (data, response) = try await URLSession.shared.data(from: url)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw NetworkError.invalidResponse
    }
    
    return try JSONDecoder().decode(AppVersionResponse.self, from: data)
}

func createMeal(
    userEmail: String,
    title: String,
    description: String?,
    directions: String?,
    privacy: String,
    servings: Int,
    foods: [Food],
    image: String? = nil,
    totalCalories: Double? = nil,
    totalProtein: Double? = nil,
    totalCarbs: Double? = nil,
    totalFat: Double? = nil,
    completion: @escaping (Result<Meal, Error>) -> Void
) {
    let urlString = "\(baseUrl)/create-meal/"
    guard let url = URL(string: urlString) else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    // Convert each food to a complete representation with all nutrients
    let foodData = foods.map { food -> [String: Any] in
        let nutrients = food.foodNutrients.map { [
            "nutrient_name": $0.nutrientName,
            "value": $0.value,
            "unit_name": $0.unitName
        ] }
        
        // Calculate macros for this particular food
        let servings = food.numberOfServings ?? 1
        let calories = (food.calories ?? 0) * servings
        
        // Extract macros
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        
        for nutrient in food.foodNutrients {
            let value = nutrient.safeValue * servings
            if nutrient.nutrientName == "Protein" {
                protein = value
            } else if nutrient.nutrientName.lowercased().contains("carbohydrate") {
                carbs = value
            } else if nutrient.nutrientName.lowercased().contains("fat") || 
                      nutrient.nutrientName.lowercased().contains("lipid") {
                fat = value
            }
        }
        
        print("🍽️ Food item: \(food.displayName), calories: \(calories), servings: \(servings)")
        
        return [
            "external_id": food.id,
            "name": food.displayName,
            "brand": food.brandText ?? "",
            "serving_size": food.servingSize ?? 0,
            "serving_unit": food.servingSizeUnit ?? "",
            "serving_text": food.servingSizeText ?? "",
            "number_of_servings": servings,
            "nutrients": nutrients,
            "calories": calories,
            "protein": protein,
            "carbs": carbs,
            "fat": fat
        ]
    }
    
    // Create base parameters
    var parameters: [String: Any] = [
        "user_email": userEmail,
        "title": title,
        "description": description ?? "",
        "directions": directions ?? "",
        "privacy": privacy,
        "servings": servings,
        "food_items": foodData  // Send complete food data
    ]
    
    // Add image parameter if exists
    if let image = image {
        parameters["image"] = image
    }
    
    // Add macro parameters if provided
    if let totalCalories = totalCalories {
        parameters["total_calories"] = totalCalories
    }
    
    if let totalProtein = totalProtein {
        parameters["total_protein"] = totalProtein
    }
    
    if let totalCarbs = totalCarbs {
        parameters["total_carbs"] = totalCarbs
    }
    
    if let totalFat = totalFat {
        parameters["total_fat"] = totalFat
    }
    
    // Print the parameters we're sending
    print("📤 Creating meal with parameters: \(parameters)")
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        // Print formatted JSON for better debugging
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            print("📤 CREATE MEAL REQUEST JSON:")
            print(jsonString)
        }
    } catch {
        print("JSON Serialization Error: \(error)")
        completion(.failure(NetworkError.encodingError))
        return
    }
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Network Error: \(error)")
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            completion(.failure(NetworkError.noData))
            return
        }
        
        // Print raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            // print("Create Meal Response: \(responseString)")
        }
        
        // Print raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {

            print(responseString)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Use custom date decoding strategy instead of simple ISO8601
            decoder.dateDecodingStrategy = .custom { decoder -> Date in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Debug the date string we're trying to parse
            
                
                // Handle empty strings
                if dateString.isEmpty {

                    return Date()
                }
                
                // Try ISO8601 with various options
                let iso8601 = ISO8601DateFormatter()
                
                // Standard ISO8601
                if let date = iso8601.date(from: dateString) {
     
                    return date
                }
                
                // With fractional seconds
                iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso8601.date(from: dateString) {

                    return date
                }
                
                // Fall back to DateFormatter
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                
                // Try multiple formats
                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",  // With 6 fractional digits and timezone
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",       // With 6 fractional digits
                    "yyyy-MM-dd'T'HH:mm:ss.SSS",          // With 3 fractional digits
                    "yyyy-MM-dd'T'HH:mm:ss",              // No fractional digits
                    "yyyy-MM-dd"                          // Just date
                ]
                
                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        print("✅ Successfully decoded with format '\(format)': '\(dateString)'")
                        return date
                    }
                }
                
                // Last resort, return current date rather than crashing
                print("⚠️ Failed to parse date: '\(dateString)' at path: \(decoder.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("⚠️ Tried formats: \(formats)")
                return Date()
            }
            
            // Add debug print to see the JSON response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("JSON response: \(jsonString)")
            }
            
            let meal = try decoder.decode(Meal.self, from: data)
            completion(.success(meal))
        } catch {
            print("Decoding error: \(error)")
            completion(.failure(error))
        }
    }.resume()
}
func getMeals(userEmail: String, page: Int = 1, completion: @escaping (Result<MealsResponse, Error>) -> Void) {
    guard var urlComponents = URLComponents(string: "\(baseUrl)/get-meals/") else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    urlComponents.queryItems = [
        URLQueryItem(name: "user_email", value: userEmail),
        URLQueryItem(name: "page", value: String(page))
    ]
    
    guard let url = urlComponents.url else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    print("🔍 Requesting meals from: \(url)")
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("❌ Network error when fetching meals: \(error)")
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            print("❌ No data received when fetching meals")
            completion(.failure(NetworkError.noData))
            return
        }
        
        // Log raw response for deeper analysis
        if let responseString = String(data: data, encoding: .utf8) {
          
        }
        
        do {
            // First, parse as dictionary to inspect structure
            if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let meals = jsonObj["meals"] as? [[String: Any]] {
                
    
                
                // Analyze the first few meals to see structure
                for (index, meal) in meals.prefix(2).enumerated() {
              
                    
                    // Check for meal items
                    if let mealItems = meal["meal_items"] as? [[String: Any]] {
                        print("  - contains \(mealItems.count) meal items")
                        if let firstItem = mealItems.first {
                            print("    - first item: \(firstItem["name"] ?? "unknown"), calories: \(firstItem["calories"] ?? "unknown")")
                        }
                    } else if let mealItems = meal["mealItems"] as? [[String: Any]] {
                        print("  - contains \(mealItems.count) meal items (camelCase key)")
                    } else {
                        print("  - no meal items found, keys present: \(meal.keys.joined(separator: ", "))")
                    }
                }
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            
            let mealsResponse = try decoder.decode(MealsResponse.self, from: data)
            
       
            for (index, meal) in mealsResponse.meals.prefix(2).enumerated() {
                // print("📊 Decoded Meal #\(index): \(meal.title)")
                // print("  - calories: \(meal.calories) (from totalCalories: \(String(describing: meal.totalCalories)))")
                // print("  - meal items: \(meal.mealItems.count)")
            }
            
            completion(.success(mealsResponse))
        } catch {
            print("❌ Decoding error when fetching meals: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("  Missing key: \(key.stringValue), path: \(context.codingPath.map { $0.stringValue })") 
                case .typeMismatch(let type, let context):
                    print("  Type mismatch: expected \(type), path: \(context.codingPath.map { $0.stringValue })")
                case .valueNotFound(let type, let context):
                    print("  Value missing: expected \(type), path: \(context.codingPath.map { $0.stringValue })")
                case .dataCorrupted(let context):
                    print("  Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("  Unknown decoding error")
                }
            }
            completion(.failure(error))
        }
    }.resume()
}
   
func logMeal(
    userEmail: String,
    mealId: Int,
    mealTime: String,
    date: Date,
    notes: String?,
    calories: Double,
    completion: @escaping (Result<LoggedMeal, Error>) -> Void
) {
    let dateFormatter = ISO8601DateFormatter()
    let dateString = dateFormatter.string(from: date)
    
    // DEBUG - Print what we're sending to the server
    print("⬆️ SENDING TO SERVER - logMeal:")
    print("- userEmail: \(userEmail)")
    print("- mealId: \(mealId)")
    print("- mealTime: \(mealTime)")
    print("- date: \(dateString)")
    print("- notes: \(notes ?? "none")")
    
    var parameters: [String: Any] = [
        "user_email": userEmail,
        "meal_id": mealId,
        "meal_time": mealTime,
        "date": dateString,
        "calories": calories
    ]
    
    if let notes = notes {
        parameters["notes"] = notes
    }
    
    // Print what we're about to send as JSON
    if let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted),
       let jsonStr = String(data: jsonData, encoding: .utf8) {
        print("📤 Request JSON: \(jsonStr)")
    }
    
    let url = URL(string: "\(baseUrl)/log-meal/")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
    } catch {
        completion(.failure(error))
        return
    }
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            completion(.failure(NetworkError.noData))
            return
        }
        
        // DEBUG - Print raw response JSON
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Response JSON for logMeal: \(jsonString)")
            
            // Check if response contains "status" key
            if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
               
                for (key, value) in jsonObj {
                   
                }
                
                if jsonObj["status"] != nil {
                    print("✅ Found 'status' key in response")
                } else {
                    print("❌ 'status' key is MISSING in response!")
                }
            }
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let loggedMeal = try decoder.decode(LoggedMeal.self, from: data)
            print("✅ Successfully decoded LoggedMeal with ID: \(loggedMeal.mealLogId)")
            completion(.success(loggedMeal))
        } catch let decodingError {
            print("❌ Decoding error: \(decodingError)")
            
            // More detailed error analysis
            if let decodingError = decodingError as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ Key '\(key.stringValue)' not found: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("❌ Value of type \(type) not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("❌ Type mismatch for type \(type): \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("❌ Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("❌ Unknown decoding error")
                }
            }
            
            print("JSON data: \(String(data: data, encoding: .utf8) ?? "invalid UTF-8")")
            completion(.failure(NetworkError.decodingFailed(decodingError)))
        }
    }.resume()
}

func updateMeal(
    userEmail: String,
    mealId: Int,
    title: String,
    description: String,
    directions: String?,
    privacy: String,
    servings: Double,
    image: String?,
    totalCalories: Double,
    totalProtein: Double,
    totalCarbs: Double,
    totalFat: Double,
    scheduledAt: Date?,
    completion: @escaping (Result<Meal, Error>) -> Void
) {
    guard let url = URL(string: "\(baseUrl)/update-meal/") else {
        completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
        return
    }
    
    // Convert the scheduledAt to ISO string if present
    let dateFormatter = ISO8601DateFormatter()
    let scheduledAtString = scheduledAt != nil ? dateFormatter.string(from: scheduledAt!) : nil
    
    var parameters: [String: Any] = [
        "user_email": userEmail,
        "meal_id": mealId,
        "title": title,
        "description": description,
        "privacy": privacy,
        "servings": servings,
        "total_calories": totalCalories,
        "total_protein": totalProtein,
        "total_carbs": totalCarbs,
        "total_fat": totalFat
    ]
    
    if let directions = directions {
        parameters["directions"] = directions
    }
    
    if let image = image {
        parameters["image"] = image
    }
    
    if let scheduledAtString = scheduledAtString {
        parameters["scheduled_at"] = scheduledAtString
    }
    
    // DEBUG - Print what we're sending to the server
    print("⬆️ SENDING TO SERVER - updateMeal:")
    print("- userEmail: \(userEmail)")
    print("- mealId: \(mealId)")
    print("- title: \(title)")
    print("- description: \(description)")
    print("- directions: \(directions ?? "none")")
    print("- privacy: \(privacy)")
    print("- servings: \(servings)")
    print("- image: \(image ?? "none")")
    print("- totalCalories: \(totalCalories)")
    print("- totalProtein: \(totalProtein)")
    print("- totalCarbs: \(totalCarbs)")
    print("- totalFat: \(totalFat)")
    print("- scheduledAt: \(scheduledAtString ?? "none")")
    
    let jsonData = try! JSONSerialization.data(withJSONObject: parameters, options: [])
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data returned"])))
            return
        }
        
        // Print response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("⬇️ RECEIVED FROM SERVER - updateMeal response:")
            print(responseString)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Try to decode the meal directly
            if let meal = try? decoder.decode(Meal.self, from: data) {
                completion(.success(meal))
                return
            }
            
            // If the above fails, try to parse any error message
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                completion(.failure(NSError(domain: "ServerError", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            // Fallback error
            completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response"])))
        } catch {
            completion(.failure(error))
        }
    }
    
    task.resume()
}

func updateMealWithFoods(
    userEmail: String,
    mealId: Int,
    title: String,
    description: String,
    directions: String?,
    privacy: String,
    servings: Double,
    foods: [Food],
    image: String?,
    totalCalories: Double,
    totalProtein: Double,
    totalCarbs: Double,
    totalFat: Double,
    scheduledAt: Date?,
    completion: @escaping (Result<Meal, Error>) -> Void
) {
    guard let url = URL(string: "\(baseUrl)/update-meal/") else {
        completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
        return
    }
    
    // Convert each food to a complete representation with all nutrients (like in createMeal)
    let foodData = foods.map { food -> [String: Any] in
        let nutrients = food.foodNutrients.map { [
            "nutrient_name": $0.nutrientName,
            "value": $0.value,
            "unit_name": $0.unitName
        ] }
        
        // Calculate macros for this particular food
        let servings = food.numberOfServings ?? 1
        let calories = (food.calories ?? 0) * servings
        
        // Extract macros
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        
        for nutrient in food.foodNutrients {
            let value = nutrient.safeValue * servings
            if nutrient.nutrientName == "Protein" {
                protein = value
            } else if nutrient.nutrientName.lowercased().contains("carbohydrate") {
                carbs = value
            } else if nutrient.nutrientName.lowercased().contains("fat") || 
                      nutrient.nutrientName.lowercased().contains("lipid") {
                fat = value
            }
        }
        
        return [
            "external_id": food.id,
            "name": food.displayName,
            "brand": food.brandText ?? "",
            "serving_size": food.servingSize ?? 0,
            "serving_unit": food.servingSizeUnit ?? "",
            "serving_text": food.servingSizeText ?? "",
            "number_of_servings": servings,
            "nutrients": nutrients,
            "calories": calories,
            "protein": protein,
            "carbs": carbs,
            "fat": fat
        ]
    }
    
    // Convert the scheduledAt to ISO string if present
    let dateFormatter = ISO8601DateFormatter()
    let scheduledAtString = scheduledAt != nil ? dateFormatter.string(from: scheduledAt!) : nil
    
    // Create base parameters
    var parameters: [String: Any] = [
        "user_email": userEmail,
        "meal_id": mealId,
        "title": title,
        "description": description,
        "privacy": privacy,
        "servings": servings,
        "total_calories": totalCalories,
        "total_protein": totalProtein,
        "total_carbs": totalCarbs,
        "total_fat": totalFat,
        "food_items": foodData  // Send complete food data
    ]
    
    // Add optional parameters
    if let directions = directions {
        parameters["directions"] = directions
    }
    
    if let image = image {
        parameters["image"] = image
    }
    
    if let scheduledAtString = scheduledAtString {
        parameters["scheduled_at"] = scheduledAtString
    }
    
    // DEBUG - Print what we're sending to the server
    print("⬆️ SENDING TO SERVER - updateMealWithFoods:")
    print("- userEmail: \(userEmail)")
    print("- mealId: \(mealId)")
    print("- title: \(title)")
    print("- description: \(description)")
    print("- directions: \(directions ?? "none")")
    print("- privacy: \(privacy)")
    print("- servings: \(servings)")
    print("- image: \(image ?? "none")")
    print("- totalCalories: \(totalCalories)")
    print("- totalProtein: \(totalProtein)")
    print("- totalCarbs: \(totalCarbs)")
    print("- totalFat: \(totalFat)")
    print("- scheduledAt: \(scheduledAtString ?? "none")")
    print("- food_items: \(foodData.count) items")
    
    // Create the actual request body
    let jsonData: Data
    do {
        jsonData = try JSONSerialization.data(withJSONObject: parameters)
    } catch {
        print("JSON Serialization Error: \(error)")
        completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request data"])))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("❌ Network error: \(error)")
            completion(.failure(error))
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP Response Status Code: \(httpResponse.statusCode)")
            
            // Print headers for debugging
            print("📋 Response Headers:")
            httpResponse.allHeaderFields.forEach { key, value in
                print("   \(key): \(value)")
            }
        }
        
        guard let data = data else {
            print("❌ No data received in updateMealWithFoods")
            completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            return
        }
        
        // Log the raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Received raw response in updateMealWithFoods: \(jsonString)")
        }
        
        // Try to parse as JSON for better viewing
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            print("📥 Parsed JSON response: \(jsonObject)")
        } catch {
            print("⚠️ Could not parse response as JSON: \(error)")
        }
        
        // Try to decode as error response first
        if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
           let errorMessage = errorResponse["error"] {
            print("❌ Server error message: \(errorMessage)")
            
            // Special handling for the cache error
            if errorMessage.contains("LocMemCache") && errorMessage.contains("keys") {
                print("ℹ️ Detected Django cache error - attempting workaround...")
                // Create a fallback error with a more helpful message
                let helpfulError = NSError(
                    domain: "NetworkManager",
                    code: 0,
                    userInfo: [
                        NSLocalizedDescriptionKey: "The server couldn't update the meal due to a cache issue. This is likely a temporary server problem - please try again in a few minutes."
                    ]
                )
                completion(.failure(helpfulError))
            } else {
                // Standard error handling
                completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            }
            return
        }
        
        // Then try to decode as successful meal response
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            print("🔄 Attempting to decode response as Meal")
            // Attempt to decode as Meal
            let meal = try decoder.decode(Meal.self, from: data)
      
            completion(.success(meal))
        } catch {
            print("❌ Detailed decoding error in updateMealWithFoods:")
            print("   - Error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   - Missing key: \(key.stringValue)")
                    print("   - Context: \(context.debugDescription)")
                    print("   - Coding path: \(context.codingPath.map { $0.stringValue })")
                case .valueNotFound(let type, let context):
                    print("   - Nil value found for type: \(type)")
                    print("   - Context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("   - Type mismatch: expected \(type)")
                    print("   - Context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("   - Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("   - Unknown decoding error")
                }
            }
            
            // Fallback - try to decode as a basic JSON and extract meal ID
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Check for either snake_case or camelCase keys for meal ID
                if let mealId = json["id"] as? Int ?? json["meal_id"] as? Int {
                    print("⚠️ Falling back to partial meal reconstruction with ID: \(mealId)")
                    
                    // Try to extract as many fields as possible from the response, checking both naming conventions
                    let title = json["title"] as? String ?? "Unknown Meal"
                    let description = json["description"] as? String ?? ""
                    let servings = json["servings"] as? Double ?? 1.0
                    let privacy = json["privacy"] as? String ?? "private"
                    let directions = json["directions"] as? String
                    let image = json["image"] as? String
                    
                    // Check both camelCase and snake_case for each property
                    let totalCalories = json["totalCalories"] as? Double ?? json["total_calories"] as? Double ?? 0
                    let totalProtein = json["totalProtein"] as? Double ?? json["total_protein"] as? Double ?? 0
                    let totalCarbs = json["totalCarbs"] as? Double ?? json["total_carbs"] as? Double ?? 0
                    let totalFat = json["totalFat"] as? Double ?? json["total_fat"] as? Double ?? 0
                    let userId = json["userId"] as? Int ?? json["user_id"] as? Int ?? 0
                    
                    // Parse date fields if available
                    var scheduledAt: Date? = nil
                    if let scheduledAtString = json["scheduledAt"] as? String ?? json["scheduled_at"] as? String {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                        scheduledAt = dateFormatter.date(from: scheduledAtString)
                    }
                    
                    // Check if there's a meal_items or mealItems array
                    var mealItems: [MealFoodItem] = []
                    if let items = json["mealItems"] as? [[String: Any]] ?? json["meal_items"] as? [[String: Any]] {
                        print("   - Found \(items.count) meal items in JSON")
                        // Process if needed
                    }
                    
                    // Construct a minimal meal with available data
                    let reconstructedMeal = Meal(
                        id: mealId,
                        title: title,
                        description: description,
                        directions: directions,
                        privacy: privacy,
                        servings: servings,
                        mealItems: mealItems,
                        image: image,
                        totalCalories: totalCalories,
                        totalProtein: totalProtein,
                        totalCarbs: totalCarbs,
                        totalFat: totalFat,
                        scheduledAt: scheduledAt
                    )
                    
                    print("✅ Successfully created fallback meal object: \(reconstructedMeal.title) (ID: \(reconstructedMeal.id))")
                    completion(.success(reconstructedMeal))
                    return
                } else {
                    print("❌ Could not find meal ID in response JSON")
                    print("   Available keys: \(json.keys.joined(separator: ", "))")
                }
            }
            
            // If all else fails, return the original error
            completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"])))
        }
    }.resume()
}

// MARK: - Recipe API Methods

func getRecipes(userEmail: String, page: Int = 1, completion: @escaping (Result<RecipesResponse, Error>) -> Void) {
    guard var urlComponents = URLComponents(string: "\(baseUrl)/get-recipes/") else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    urlComponents.queryItems = [
        URLQueryItem(name: "user_email", value: userEmail),
        URLQueryItem(name: "page", value: String(page))
    ]
    
    guard let url = urlComponents.url else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    print("🔍 Requesting recipes from: \(url)")
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("❌ Network error when fetching recipes: \(error)")
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            print("❌ No data received when fetching recipes")
            completion(.failure(NetworkError.noData))
            return
        }
        
        // Log raw response for deeper analysis
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Raw recipes response (first 200 chars): \(String(responseString.prefix(200)))...")
        }
        
        do {
            // First, manually decode the JSON to get control over the date fields
            guard let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  var recipesArray = jsonDict["recipes"] as? [[String: Any]] else {
                throw NetworkError.invalidData
            }
            
            print("🔍 Found \(recipesArray.count) recipes in response")
            
            // Process each recipe to handle date fields
            for i in 0..<recipesArray.count {
                var recipe = recipesArray[i]
                
                // Check and convert date fields
                let dateFields = ["created_at", "updated_at", "scheduled_at"]
                
                for field in dateFields {
                    // Handle numeric timestamp values
                    if let timestamp = recipe[field] as? Double {
                        // Convert timestamp to ISO string
                        let date = Date(timeIntervalSince1970: timestamp)
                        let iso8601Formatter = ISO8601DateFormatter()
                        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let isoString = iso8601Formatter.string(from: date)
                        
                        print("🔄 Converting numeric timestamp for \(field): \(timestamp) -> \(isoString)")
                        recipe[field] = isoString
                    }
                    // Handle existing string dates - ensure they have timezone info
                    else if let dateString = recipe[field] as? String, !dateString.isEmpty {
                        // If it's already in correct format with Z or timezone info, leave it alone
                        if !dateString.hasSuffix("Z") && !dateString.contains("+") && !dateString.contains("-0") && dateString.contains("T") {
                            // Add Z to indicate UTC if it has a T but no timezone
                            let fixedDateString = dateString + "Z"
                            print("🔄 Fixed date string for \(field): \(dateString) -> \(fixedDateString)")
                            recipe[field] = fixedDateString
                        }
                    }
                }
                
                recipesArray[i] = recipe
            }
            
            // Reconstruct the JSON with fixed dates
            var fixedJsonDict = jsonDict
            fixedJsonDict["recipes"] = recipesArray
            
            // Convert back to data
            let fixedData = try JSONSerialization.data(withJSONObject: fixedJsonDict)
            
            // Now use JSONDecoder with the fixed data
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Use custom date decoding strategy that can handle both formats
            decoder.dateDecodingStrategy = .custom { decoder -> Date in
                let container = try decoder.singleValueContainer()
                
                // Try to decode as a string first
                do {
                    let dateString = try container.decode(String.self)
                    
                    // Handle empty strings
                    if dateString.isEmpty {
                        return Date()
                    }
                    
                    // Try ISO8601 with various options
                    let iso8601 = ISO8601DateFormatter()
                    
                    // Standard ISO8601
                    if let date = iso8601.date(from: dateString) {
                        return date
                    }
                    
                    // With fractional seconds
                    iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = iso8601.date(from: dateString) {
                        return date
                    }
                    
                    // Try with DateFormatter and multiple formats
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            return date
                        }
                    }
                    
                    // Fall back to current date
                    print("⚠️ Could not parse date string: \(dateString)")
                    return Date()
                } 
                catch {
                    // If string fails, try to decode as a timestamp (number)
                    do {
                        let timestamp = try container.decode(Double.self)
                        return Date(timeIntervalSince1970: timestamp)
                    } catch {
                        // Last resort
                        print("⚠️ Failed to decode date as string or number")
                        return Date()
                    }
                }
            }
            
            let recipesResponse = try decoder.decode(RecipesResponse.self, from: fixedData)
            

            completion(.success(recipesResponse))
        } catch {
            print("❌ Decoding error when fetching recipes: \(error)")
            
            // Extra debugging for decoding errors
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("  Missing key: \(key.stringValue), path: \(context.codingPath.map { $0.stringValue })") 
                case .typeMismatch(let type, let context):
                    print("  Type mismatch: expected \(type), path: \(context.codingPath.map { $0.stringValue })")
                case .valueNotFound(let type, let context):
                    print("  Value missing: expected \(type), path: \(context.codingPath.map { $0.stringValue })")
                case .dataCorrupted(let context):
                    print("  Data corrupted: \(context.debugDescription)")
                    print("  Coding path: \(context.codingPath.map { $0.stringValue })")
                @unknown default:
                    print("  Unknown decoding error")
                }
            }
            
            // Try to extract the raw recipe data for inspection
            if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let recipes = jsonObj["recipes"] as? [[String: Any]],
               let firstRecipe = recipes.first {
                print("⚙️ Raw structure of first recipe:")
                for (key, value) in firstRecipe {
                    let valueType = type(of: value)
                    print("  - \(key): \(value) (Type: \(valueType))")
                }
            }
            
            completion(.failure(error))
        }
    }.resume()
}

func createRecipe(
    userEmail: String,
    title: String,
    description: String?,
    instructions: String?,
    privacy: String,
    servings: Int,
    foods: [Food],
    image: String?,
    prepTime: Int?,
    cookTime: Int?,
    totalCalories: Double,
    totalProtein: Double,
    totalCarbs: Double,
    totalFat: Double,
    completion: @escaping (Result<Recipe, Error>) -> Void
) {
    let urlString = "\(baseUrl)/create-recipe/"
    guard let url = URL(string: urlString) else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    // Convert Food to the expected format for the API
    let foodItems = foods.map { food -> [String: Any] in
        var item: [String: Any] = [
            "external_id": "\(food.fdcId)",
            "name": food.displayName,
            "number_of_servings": food.numberOfServings ?? 1
        ]
        
        if let brandText = food.brandText {
            item["brand"] = brandText
        }
        
        if let servingSize = food.servingSize {
            item["serving_size"] = servingSize
        }
        
        if let servingSizeUnit = food.servingSizeUnit {
            item["serving_unit"] = servingSizeUnit
        }
        
        item["serving_text"] = food.servingSizeText
        item["calories"] = food.calories ?? 0
        item["protein"] = food.protein ?? 0
        item["carbs"] = food.carbs ?? 0
        item["fat"] = food.fat ?? 0
        
        return item
    }
    
    // Create the request body
    var parameters: [String: Any] = [
        "user_email": userEmail,
        "title": title,
        "privacy": privacy,
        "servings": servings,
        "food_items": foodItems,
        "total_calories": totalCalories,
        "total_protein": totalProtein,
        "total_carbs": totalCarbs,
        "total_fat": totalFat
    ]
    
    if let description = description {
        parameters["description"] = description
    }
    
    if let instructions = instructions {
        parameters["instructions"] = instructions
    }
    
    if let image = image {
        parameters["image"] = image
    }
    
    if let prepTime = prepTime {
        parameters["prep_time"] = prepTime
    }
    
    if let cookTime = cookTime {
        parameters["cook_time"] = cookTime
    }
    
    // Print the parameters we're sending
    print("📤 Creating recipe with parameters:")
    print("- title: \(title)")
    print("- description: \(description ?? "none")")
    print("- instructions: \(instructions ?? "none")")
    print("- servings: \(servings)")
    print("- total items: \(foods.count)")
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        // Print formatted JSON for better debugging
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            print("📤 CREATE RECIPE REQUEST JSON:")
            print(jsonString)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error when creating recipe: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ No data received when creating recipe")
                completion(.failure(NetworkError.noData))
                return
            }
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 CREATE RECIPE RESPONSE:")
                print(responseString)
            }
            
            do {
                // Manual JSON decoding to fix date fields
                guard let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw NetworkError.invalidData
                }
                
                // Make a mutable copy of the dictionary
                var mutableDict = jsonDict
                
                // Fix date fields
                for (key, value) in jsonDict {
                    if let dateString = value as? String, 
                       (key.contains("created_at") || key.contains("updated_at")) {
                        // Debug the date string
                        print("🔎 Found date field \(key): \(dateString)")
                        
                        // Handle empty strings
                        if dateString.isEmpty {
                            mutableDict[key] = nil
                            continue
                        }
                        
                        // If missing timezone, add Z
                        if !dateString.hasSuffix("Z") && !dateString.contains("+") {
                            let fixedDateString = dateString + "Z"
                            print("📅 Fixed date string: \(dateString) -> \(fixedDateString)")
                            mutableDict[key] = fixedDateString
                        }
                    }
                }
                
                // Convert back to data for decoding
                let fixedData = try JSONSerialization.data(withJSONObject: mutableDict)
                
                // Use the modified data with JSONDecoder
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                // Use custom date decoding strategy instead of simple ISO8601
                decoder.dateDecodingStrategy = .custom { decoder -> Date in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // Debug the date string we're trying to parse
                    print("🔎 Attempting to decode date string: '\(dateString)'")
                    
                    // Handle empty strings
                    if dateString.isEmpty {
                        print("⚠️ Empty date string found, using current date")
                        return Date()
                    }
                    
                    // Try ISO8601 with various options
                    let iso8601 = ISO8601DateFormatter()
                    
                    // Standard ISO8601
                    if let date = iso8601.date(from: dateString) {

                        return date
                    }
                    
                    // With fractional seconds
                    iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = iso8601.date(from: dateString) {

                        return date
                    }
                    
                    // Fall back to DateFormatter
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    // Try multiple formats
                    let formats = [
                        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",  // With 6 fractional digits and timezone
                        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",       // With 6 fractional digits
                        "yyyy-MM-dd'T'HH:mm:ss.SSS",          // With 3 fractional digits
                        "yyyy-MM-dd'T'HH:mm:ss",              // No fractional digits
                        "yyyy-MM-dd"                          // Just date
                    ]
                    
                    for format in formats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {

                            return date
                        }
                    }
                    
                    // Last resort, return current date rather than crashing
                    print("⚠️ Failed to parse date: '\(dateString)' at path: \(decoder.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("⚠️ Tried formats: \(formats)")
                    return Date()
                }
                
                let recipe = try decoder.decode(Recipe.self, from: fixedData)
                print("✅ Successfully created recipe: \(recipe.title) (ID: \(recipe.id))")
                completion(.success(recipe))
            } catch {
                print("❌ Decoding error when creating recipe: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Missing key: \(key.stringValue) in \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch: expected \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .valueNotFound(let type, let context):
                        print("Value not found: expected \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                print("JSON data: \(String(data: data, encoding: .utf8) ?? "invalid UTF-8")")
                completion(.failure(NetworkError.decodingFailed(error)))
            }
        }.resume()
    } catch {
        print("❌ JSON serialization error: \(error)")
        completion(.failure(NetworkError.jsonEncodingFailed))
    }
}


func logRecipe(
    userEmail: String,
    recipeId: Int,
    mealTime: String,
    date: Date,
    notes: String? = nil,
    calories: Double,
    completion: @escaping (Result<LoggedRecipe, Error>) -> Void
) {
    let dateFormatter = ISO8601DateFormatter()
    let dateString = dateFormatter.string(from: date)
    
    // DEBUG - Print what we're sending to the server
    print("⬆️ SENDING TO SERVER - logRecipe:")
    print("- userEmail: \(userEmail)")
    print("- recipeId: \(recipeId)")
    print("- mealTime: \(mealTime)")
    print("- date: \(dateString)")
    print("- notes: \(notes ?? "none")")
    
    var parameters: [String: Any] = [
        "user_email": userEmail,
        "recipe_id": recipeId,
        "meal_time": mealTime,
        "date": dateString,
        "calories": calories
    ]
    
    if let notes = notes {
        parameters["notes"] = notes
    }
    
    // Print what we're about to send as JSON
    if let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted),
       let jsonStr = String(data: jsonData, encoding: .utf8) {
        print("📤 Request JSON: \(jsonStr)")
    }
    
    let url = URL(string: "\(baseUrl)/log-recipe/")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
    } catch {
        completion(.failure(error))
        return
    }
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            completion(.failure(NetworkError.noData))
            return
        }
        
        // DEBUG - Print raw response JSON
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Response JSON for logRecipe: \(jsonString)")
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let loggedRecipe = try decoder.decode(LoggedRecipe.self, from: data)

            completion(.success(loggedRecipe))
        } catch let decodingError {
            print("❌ Decoding error: \(decodingError)")
            
            // More detailed error analysis
            if let decodingError = decodingError as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ Key '\(key.stringValue)' not found: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("❌ Value of type \(type) not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("❌ Type mismatch for type \(type): \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("❌ Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("❌ Unknown decoding error")
                }
            }
            
            print("JSON data: \(String(data: data, encoding: .utf8) ?? "invalid UTF-8")")
            completion(.failure(NetworkError.decodingFailed(decodingError)))
        }
    }.resume()
}


func updateRecipe(
    userEmail: String,
    recipeId: Int,
    title: String,
    description: String,
    instructions: String,
    privacy: String,
    servings: Int,
    image: String?,
    prepTime: Int?,
    cookTime: Int?,
    totalCalories: Double,
    totalProtein: Double,
    totalCarbs: Double,
    totalFat: Double,
    completion: @escaping (Result<Recipe, Error>) -> Void
) {
    guard let url = URL(string: "\(baseUrl)/update-recipe/") else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    // Create the request body
    var parameters: [String: Any] = [
        "user_email": userEmail,
        "recipe_id": recipeId,
        "title": title,
        "description": description,
        "instructions": instructions,
        "privacy": privacy,
        "servings": servings,
        "total_calories": totalCalories,
        "total_protein": totalProtein,
        "total_carbs": totalCarbs,
        "total_fat": totalFat
    ]
    
    if let image = image {
        parameters["image"] = image
    }
    
    if let prepTime = prepTime {
        parameters["prep_time"] = prepTime
    }
    
    if let cookTime = cookTime {
        parameters["cook_time"] = cookTime
    }
    
    // DEBUG - Print what we're sending to the server
    print("⬆️ SENDING TO SERVER - updateRecipe:")
    print("- userEmail: \(userEmail)")
    print("- recipeId: \(recipeId)")
    print("- title: \(title)")
    print("- description: \(description)")
    print("- instructions: \(instructions)")
    print("- privacy: \(privacy)")
    print("- servings: \(servings)")
    print("- totalCalories: \(totalCalories)")
    print("- totalProtein: \(totalProtein)")
    print("- totalCarbs: \(totalCarbs)")
    print("- totalFat: \(totalFat)")
    print("- prepTime: \(prepTime ?? 0)")
    print("- cookTime: \(cookTime ?? 0)")
    print("- image: \(image ?? "none")")
    
    let jsonData: Data
    do {
        jsonData = try JSONSerialization.data(withJSONObject: parameters)
    } catch {
        print("JSON Serialization Error: \(error)")
        completion(.failure(NetworkError.jsonEncodingFailed))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            completion(.failure(NetworkError.noData))
            return
        }
        
        // Print response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("⬇️ RECEIVED FROM SERVER - updateRecipe response:")
            print(responseString)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            
            let recipe = try decoder.decode(Recipe.self, from: data)
            print("✅ Successfully updated recipe: \(recipe.title) (ID: \(recipe.id))")
            completion(.success(recipe))
        } catch {
            print("❌ Decoding error when updating recipe: \(error)")
            
            // More detailed error analysis
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ Key '\(key.stringValue)' not found: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("❌ Value of type \(type) not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("❌ Type mismatch for type \(type): \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("❌ Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("❌ Unknown decoding error")
                }
            }
            
            print("JSON data: \(String(data: data, encoding: .utf8) ?? "invalid UTF-8")")
            completion(.failure(NetworkError.decodingFailed(error)))
        }
    }.resume()
}

func updateRecipeWithFoods(
    userEmail: String,
    recipeId: Int,
    title: String,
    description: String,
    instructions: String,
    privacy: String,
    servings: Int,
    foods: [Food],
    image: String?,
    prepTime: Int?,
    cookTime: Int?,
    totalCalories: Double,
    totalProtein: Double,
    totalCarbs: Double,
    totalFat: Double,
    completion: @escaping (Result<Recipe, Error>) -> Void
) {
    guard let url = URL(string: "\(baseUrl)/update-recipe/") else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    // Convert each Food to a dictionary expected by the API.
    let foodItems = foods.map { food -> [String: Any] in
        var item: [String: Any] = [
            "external_id": "\(food.fdcId)",
            "name": food.displayName,
            "number_of_servings": food.numberOfServings ?? 1
        ]
        
        if let brandText = food.brandText {
            item["brand"] = brandText
        }
        if let servingSize = food.servingSize {
            item["serving_size"] = servingSize
        }
        if let servingSizeUnit = food.servingSizeUnit {
            item["serving_unit"] = servingSizeUnit
        }
        
        item["serving_text"] = food.servingSizeText
        item["calories"] = food.calories ?? 0
        item["protein"] = food.protein ?? 0
        item["carbs"] = food.carbs ?? 0
        item["fat"] = food.fat ?? 0
        
        return item
    }
    
    // Build the request parameters.
    var parameters: [String: Any] = [
        "user_email": userEmail,
        "recipe_id": recipeId,
        "title": title,
        "description": description,
        "instructions": instructions,
        "privacy": privacy,
        "servings": servings,
        "food_items": foodItems,
        "total_calories": totalCalories,
        "total_protein": totalProtein,
        "total_carbs": totalCarbs,
        "total_fat": totalFat
    ]
    
    if let image = image {
        parameters["image"] = image
    }
    if let prepTime = prepTime {
        parameters["prep_time"] = prepTime
    }
    if let cookTime = cookTime {
        parameters["cook_time"] = cookTime
    }
    
    // DEBUG: print parameters
    print("⬆️ SENDING TO SERVER - updateRecipeWithFoods:")
    print("- userEmail: \(userEmail)")
    print("- recipeId: \(recipeId)")
    print("- title: \(title)")
    print("- description: \(description)")
    print("- instructions: \(instructions)")
    print("- privacy: \(privacy)")
    print("- servings: \(servings)")
    print("- image: \(image ?? "none")")
    print("- prepTime: \(prepTime ?? 0)")
    print("- cookTime: \(cookTime ?? 0)")
    print("- totalCalories: \(totalCalories)")
    print("- totalProtein: \(totalProtein)")
    print("- totalCarbs: \(totalCarbs)")
    print("- totalFat: \(totalFat)")
    print("- food_items: \(foodItems.count) items")
    
    // Serialize parameters to JSON.
    let jsonData: Data
    do {
        jsonData = try JSONSerialization.data(withJSONObject: parameters)
    } catch {
        print("JSON Serialization Error: \(error)")
        completion(.failure(NetworkError.jsonEncodingFailed))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            completion(.failure(NetworkError.noData))
            return
        }
        
        // DEBUG: print server response
        if let responseString = String(data: data, encoding: .utf8) {
            print("⬇️ RECEIVED FROM SERVER - updateRecipeWithFoods response:")
            print(responseString)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Use a custom date decoding strategy so that dates with fractional seconds are handled.
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected ISO8601 date with fractional seconds, got \(dateString)"
                )
            }
            
            let recipe = try decoder.decode(Recipe.self, from: data)
            print("✅ Successfully updated recipe with foods: \(recipe.title) (ID: \(recipe.id))")
            completion(.success(recipe))
        } catch {
            print("❌ Decoding error when updating recipe with foods: \(error)")
            print("JSON data: \(String(data: data, encoding: .utf8) ?? "invalid UTF-8")")
            completion(.failure(NetworkError.decodingFailed(error)))
        }
    }.resume()
}

    func generateMacrosWithAI(foodDescription: String, mealType: String, completion: @escaping (Result<LoggedFood, Error>) -> Void) {
        let parameters: [String: Any] = [
            "user_email": UserDefaults.standard.string(forKey: "userEmail") ?? "",
            "food_description": foodDescription,
            "meal_type": mealType
        ]
        
        let urlString = "\(baseUrl)/generate-ai-macros/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Create and configure request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        // DEBUG - Print what we're sending to the server
        print("⬆️ SENDING TO SERVER - generateMacrosWithAI:")
        print("- food description: \(foodDescription)")
        print("- meal type: \(mealType)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // Check for server error responses
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(errorMessage)))
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError("Server returned error \(httpResponse.statusCode)")))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.noData))
                }
                return
            }
            
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("⬇️ SERVER RESPONSE - generateMacrosWithAI: \(responseString)")
            }
            
            do {
                let decoder = JSONDecoder()
                // Remove snake case conversion since backend now sends camelCase directly
                // decoder.keyDecodingStrategy = .convertFromSnakeCase
                let loggedFood = try decoder.decode(LoggedFood.self, from: data)
                
                DispatchQueue.main.async {
                    completion(.success(loggedFood))
                }
            } catch {
                print("Decoding error: \(error)")
                // If standard decoding fails, see if there's an error message
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = json["error"] as? String {
                        DispatchQueue.main.async {
                            completion(.failure(NetworkError.serverError(errorMessage)))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(NetworkError.decodingError))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.decodingError))
                    }
                }
            }
        }.resume()
    }

    func generateMealWithAI(mealDescription: String, mealType: String, completion: @escaping (Result<Meal, Error>) -> Void) {
        let parameters: [String: Any] = [
            "user_email": UserDefaults.standard.string(forKey: "userEmail") ?? "",
            "meal_description": mealDescription,
            "meal_type": mealType
        ]
        
        let urlString = "\(baseUrl)/generate-ai-meal/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Create and configure request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        // DEBUG - Print what we're sending to the server
        print("⬆️ SENDING TO SERVER - generateMealWithAI:")
        print("- meal description: \(mealDescription)")
        print("- meal type: \(mealType)")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
            
            // DEBUG - Print response from server
            if let jsonString = String(data: data, encoding: .utf8) {
                print("⬇️ SERVER RESPONSE - generateMealWithAI:")
                print(jsonString.prefix(300)) // First 300 chars
            }
            
            do {
                // Check if there's an error message from server
                if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorResponse["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(errorMessage)))
                    }
                    return
                }
                
                // Create a decoder with snake_case to camelCase conversion
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                // Parse the meal response
                let meal = try decoder.decode(Meal.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(meal))
                }
            } catch {
                print("⚠️ Error parsing meal data: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }

    func generateFoodWithAI(
        foodDescription: String,
        completion: @escaping (Result<Food, Error>) -> Void
    ) {
        let parameters: [String: Any] = [
            "user_email": UserDefaults.standard.string(forKey: "userEmail") ?? "",
            "food_description": foodDescription
        ]
        
        let urlString = "\(baseUrl)/generate-ai-food/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            
            // Print formatted JSON for better debugging
            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                print("📤 GENERATE FOOD REQUEST JSON:")
                print(jsonString)
            }
        } catch {
            print("JSON Serialization Error: \(error)")
            completion(.failure(NetworkError.encodingError))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // Check for server error responses
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(errorMessage)))
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError("Server returned error \(httpResponse.statusCode)")))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.noData))
                }
                return
            }
            
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("⬇️ SERVER RESPONSE - generateFoodWithAI: \(responseString)")
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let food = try decoder.decode(Food.self, from: data)
                
                DispatchQueue.main.async {
                    completion(.success(food))
                }
            } catch {
                print("Decoding Error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // Add the createManualFood function to the NetworkManager class
    // This should be added with the other food-related API functions

    func createManualFood(userEmail: String, food: Food, completion: @escaping (Result<Food, Error>) -> Void) {
        let urlString = "\(baseUrl)/create-food/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Extract nutrients from the food object
        var nutrientsArray: [[String: Any]] = []
        for nutrient in food.foodNutrients {
            nutrientsArray.append([
                "nutrient_name": nutrient.nutrientName,
                "value": nutrient.value,
                "unit_name": nutrient.unitName
            ])
        }
        
        // Create measures array
        var measuresArray: [[String: Any]] = []
        for measure in food.foodMeasures {
            measuresArray.append([
                "dissemination_text": measure.disseminationText,
                "gram_weight": measure.gramWeight,
                "id": measure.id,
                "modifier": measure.modifier ?? "",
                "measure_unit_name": measure.measureUnitName,
                "rank": measure.rank
            ])
        }
        
        // Format the request body
        var body: [String: Any] = [
            "user_email": userEmail,
            "name": food.description,
            "serving_size": food.servingSize ?? 1.0,
            "serving_unit": food.servingSizeUnit ?? "serving",
            "serving_text": food.servingSizeText,
            "calories": food.calories ?? 0,
            "protein": food.protein ?? 0,
            "carbs": food.carbs ?? 0,
            "fat": food.fat ?? 0,
            "number_of_servings": food.numberOfServings ?? 1.0,
            "nutrients": nutrientsArray,
            "measures": measuresArray
        ]
        
        // Only add brand if it's explicitly set and meaningful
        if let brandText = food.brandText, !brandText.isEmpty, 
           brandText != "Custom" && brandText != "Generic" {
            body["brand"] = brandText
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
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
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                // Check if there's an error response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(errorMessage)))
                    }
                    return
                }
                
                // Try to parse the food response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Food creation JSON response: \(json)")
                }
                
                let createdFood = try decoder.decode(Food.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(createdFood))
                }
            } catch {
                print("Decoding error in createManualFood: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }
    
    // MARK: - Get User Foods
    func getUserFoods(userEmail: String, page: Int = 1, completion: @escaping (Result<FoodResponse, Error>) -> Void) {
        guard var urlComponents = URLComponents(string: "\(baseUrl)/get-user-foods/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        guard let url = urlComponents.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                // Check if there's an error response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(errorMessage)))
                    }
                    return
                }
                
                let foodResponse = try decoder.decode(FoodResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(foodResponse))
                }
            } catch {
                print("Decoding error in getUserFoods: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    // Add these functions to the NetworkManager class to handle deletion

    // Delete food log
    func deleteFoodLog(logId: Int, userEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let parameters: [String: Any] = [
            "user_email": userEmail
        ]
        
        let urlString = "\(baseUrl)/delete-food-log/\(logId)/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                } else {
                    var errorMessage = "Server error with status code: \(httpResponse.statusCode)"
                    
                    if let data = data, let serverError = try? JSONSerialization.jsonObject(with: data) as? [String: Any], 
                       let message = serverError["error"] as? String {
                        errorMessage = message
                    }
                    
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(errorMessage)))
                    }
                }
            }
        }
        
        task.resume()
    }
    
    // Delete meal
    func deleteMeal(mealId: Int, userEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let parameters: [String: Any] = [
            "user_email": userEmail
        ]
        
        let urlString = "\(baseUrl)/delete-meal/\(mealId)/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                } else {
                    if let data = data,
                       let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorResponse["error"] as? String {
                        DispatchQueue.main.async {
                            completion(.failure(NetworkError.serverError(errorMessage)))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(NetworkError.serverError("Failed with status code: \(httpResponse.statusCode)")))
                        }
                    }
                }
            }
        }
        
        task.resume()
    }
    
    // Delete food
    func deleteFood(foodId: Int, userEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let parameters: [String: Any] = [
            "user_email": userEmail
        ]
        
        let urlString = "\(baseUrl)/delete-food/\(foodId)/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                } else {
                    if let data = data,
                       let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorResponse["error"] as? String {
                        DispatchQueue.main.async {
                            completion(.failure(NetworkError.serverError(errorMessage)))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(NetworkError.serverError("Failed with status code: \(httpResponse.statusCode)")))
                        }
                    }
                }
            }
        }
        
        task.resume()
    }

    // Delete meal log
    func deleteMealLog(logId: Int, userEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let parameters: [String: Any] = [
            "user_email": userEmail
        ]
        
        let urlString = "\(baseUrl)/delete-meal-log/\(logId)/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                } else {
                    var errorMessage = "Server error with status code: \(httpResponse.statusCode)"
                    
                    if let data = data, let serverError = try? JSONSerialization.jsonObject(with: data) as? [String: Any], 
                       let message = serverError["error"] as? String {
                        errorMessage = message
                    }
                    
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(errorMessage)))
                    }
                }
            }
        }
        
        task.resume()
    }

    // Function to analyze food image
func analyzeFoodImage(image: UIImage, userEmail: String, mealType: String = "Lunch", shouldLog: Bool = true, logDate: String? = nil, completion: @escaping (Bool, [String: Any]?, String?) -> Void) {
    // Configure the URL
    guard let url = URL(string: "\(baseUrl)/analyze_food_image/") else {
        completion(false, nil, "Invalid URL")
        return
    }
    
    // Compress the image to reduce upload size (quality: 0.7 is a good balance)
    guard let imageData = image.jpegData(compressionQuality: 0.7) else {
        completion(false, nil, "Failed to compress image")
        return
    }
    
    // Convert image data to Base64 string
    let base64Image = imageData.base64EncodedString()
    
    // Create request body
    let tzOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
    var parameters: [String: Any] = [
        "user_email": userEmail,
        "image_data": base64Image,
        "meal_type": mealType,
        "should_log": shouldLog,
        "timezone_offset_minutes": tzOffsetMinutes
    ]
    if let logDate = logDate { parameters["date"] = logDate }
    
    print("🔍 DEBUG NetworkManager.analyzeFoodImage: Sending should_log = \(shouldLog)")
    
    // Configure the request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
    } catch {
        completion(false, nil, "Failed to serialize request: \(error.localizedDescription)")
        return
    }
    
    // Create and start the data task
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        // Handle network error
        if let error = error {
            completion(false, nil, "Network error: \(error.localizedDescription)")
            return
        }
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(false, nil, "Invalid response")
            return
        }
        
        // Check status code
        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            completion(false, nil, "Server error: HTTP \(httpResponse.statusCode)")
            return
        }
        
        // Parse response data
        guard let data = data else {
            completion(false, nil, "No data received")
            return
        }
        
        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Check for error in response
                if let errorMessage = jsonResponse["error"] as? String {
                    completion(false, nil, errorMessage)
                    return
                }
                
                // Handle successful response
                completion(true, jsonResponse, nil)
            } else {
                completion(false, nil, "Invalid response format")
            }
        } catch {
            completion(false, nil, "Failed to parse response: \(error.localizedDescription)")
        }
    }
    
    // Start the request
    task.resume()
} 

// Function to analyze nutrition label
func analyzeNutritionLabel(image: UIImage, userEmail: String, mealType: String = "Lunch", shouldLog: Bool = true, logDate: String? = nil, completion: @escaping (Bool, [String: Any]?, String?) -> Void) {
    // Configure the URL
    guard let url = URL(string: "\(baseUrl)/analyze_nutrition_label/") else {
        completion(false, nil, "Invalid URL")
        return
    }
    
    // Compress the image to reduce upload size (quality: 0.8 for better text clarity)
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        completion(false, nil, "Failed to compress image")
        return
    }
    
    // Convert image data to Base64 string
    let base64Image = imageData.base64EncodedString()
    
    // Create request body
    let tzOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
    var parameters: [String: Any] = [
        "user_email": userEmail,
        "image_data": base64Image,
        "meal_type": mealType,
        "should_log": shouldLog,
        "timezone_offset_minutes": tzOffsetMinutes
    ]
    if let logDate = logDate { parameters["date"] = logDate }
    
    print("🌐 [DEBUG] ====== NetworkManager.analyzeNutritionLabel START ======")
    print("🌐 [DEBUG] shouldLog parameter: \(shouldLog)")
    print("🌐 [DEBUG] Parameters being sent to backend:")
    print("🌐 [DEBUG]   - user_email: \(userEmail)")
    print("🌐 [DEBUG]   - meal_type: \(mealType)")
    print("🌐 [DEBUG]   - should_log: \(shouldLog)")
    print("🌐 [DEBUG]   - image_data: [Base64 string, \(base64Image.count) chars]")
    print("🌐 [DEBUG] Sending POST request to: \(url.absoluteString)")
    
    // Configure the request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
    } catch {
        completion(false, nil, "Failed to serialize request: \(error.localizedDescription)")
        return
    }
    
    // Create and start the data task
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        // Handle network error
        if let error = error {
            completion(false, nil, "Network error: \(error.localizedDescription)")
            return
        }
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(false, nil, "Invalid response")
            return
        }
        
        // Check status code
        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            completion(false, nil, "Server error: HTTP \(httpResponse.statusCode)")
            return
        }
        
        // Parse response data
        guard let data = data else {
            completion(false, nil, "No data received")
            return
        }
        
        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Check for error in response
                if let errorMessage = jsonResponse["error"] as? String {
                    completion(false, nil, errorMessage)
                    return
                }
                
                // Handle successful response
                completion(true, jsonResponse, nil)
            } else {
                completion(false, nil, "Invalid response format")
            }
        } catch {
            completion(false, nil, "Failed to parse response: \(error.localizedDescription)")
        }
    }
    
    // Start the request
    task.resume()
} 

// MARK: - Pro Feature APIs

func checkFeatureAccess(featureKey: String,
                        increment: Bool,
                        userEmail: String,
                        completion: @escaping (Result<FeatureAccessResponse, Error>) -> Void) {
    guard let url = URL(string: "\(baseUrl)/pro/check-feature-access/") else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let tzOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
    let payload: [String: Any] = [
        "feature_key": featureKey,
        "increment": increment,
        "user_email": userEmail,
        "timezone_offset_minutes": tzOffsetMinutes
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
    } catch {
        completion(.failure(error))
        return
    }
    
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
        
        do {
            let decoder = self.makeJSONDecoder()
            let access = try decoder.decode(FeatureAccessResponse.self, from: data)
            DispatchQueue.main.async {
                completion(.success(access))
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }.resume()
}

func fetchUsageSummary(userEmail: String,
                       completion: @escaping (Result<UsageSummary, Error>) -> Void) {
    guard var components = URLComponents(string: "\(baseUrl)/pro/usage-summary/") else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    let tzOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
    components.queryItems = [
        URLQueryItem(name: "user_email", value: userEmail),
        URLQueryItem(name: "timezone_offset_minutes", value: String(tzOffsetMinutes))
    ]
    
    guard let url = components.url else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
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
        do {
            let decoder = self.makeJSONDecoder()
            let summary = try decoder.decode(UsageSummary.self, from: data)
            DispatchQueue.main.async {
                completion(.success(summary))
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }.resume()
}

func searchFoodPro(query: String,
                   userEmail: String,
                   completion: @escaping (Result<ProFoodSearchResult, Error>) -> Void) {
    guard let url = URL(string: "\(baseUrl)/pro/search-food/") else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let payload: [String: Any] = [
        "query": query,
        "user_email": userEmail
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
    } catch {
        completion(.failure(error))
        return
    }
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            DispatchQueue.main.async {
                completion(.failure(NetworkError.invalidResponse))
            }
            return
        }
        
        guard let data = data else {
            DispatchQueue.main.async {
                completion(.failure(NetworkError.noData))
            }
            return
        }
        
        if httpResponse.statusCode == 403 {
            DispatchQueue.main.async {
                completion(.failure(NetworkError.serverError("Humuli Pro subscription required")))
            }
            return
        }
        
        do {
            let decoder = self.makeJSONDecoder()
            let result = try decoder.decode(ProFoodSearchResult.self, from: data)
            DispatchQueue.main.async {
                completion(.success(result))
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }.resume()
}

func scheduleMealLog(logId: Int,
                     logType: String,
                     scheduleType: String,
                     targetDate: Date,
                     mealType: String?,
                     userEmail: String,
                     completion: @escaping (Result<ScheduleMealResponse, Error>) -> Void) {
    guard let url = URL(string: "\(baseUrl)/schedule-meal-log/") else {
        completion(.failure(NetworkError.invalidURL))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .gregorian)
    dateFormatter.timeZone = TimeZone.current
    dateFormatter.dateFormat = "yyyy-MM-dd"

    var payload: [String: Any] = [
        "user_email": userEmail,
        "log_id": logId,
        "log_type": logType,
        "schedule_type": scheduleType,
        "target_date": dateFormatter.string(from: targetDate)
    ]
    if let mealType = mealType {
        payload["meal_type"] = mealType
    }
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
    } catch {
        completion(.failure(error))
        return
    }
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            DispatchQueue.main.async {
                completion(.failure(NetworkError.invalidResponse))
            }
            return
        }
        
        guard let data = data else {
            DispatchQueue.main.async {
                completion(.failure(NetworkError.noData))
            }
            return
        }
        
        if httpResponse.statusCode == 403 {
            DispatchQueue.main.async {
                completion(.failure(NetworkError.serverError("Humuli Pro subscription required")))
            }
            return
        }
        
        do {
            let decoder = self.makeJSONDecoder()
            let response = try decoder.decode(ScheduleMealResponse.self, from: data)
            DispatchQueue.main.async {
                completion(.success(response))
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }.resume()
}


}
