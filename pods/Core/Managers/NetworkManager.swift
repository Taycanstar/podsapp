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
}


class NetworkManager {
 
//    let baseUrl = "https://humuli-2b3070583cda.herokuapp.com"
    let baseUrl = "http://192.168.1.79:8000"
//    let baseUrl = "http://172.20.10.3:8000"

    

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
                        RegionManager.shared.region = "centralus" // Default region
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

//    func login(identifier: String, password: String, completion: @escaping (Bool, String?, String?, String?, Int?, Int?, String?, String?, String?, String?, String?, Bool?, Int?, Bool?) -> Void) {
//        guard let url = URL(string: "\(baseUrl)/login/") else {
//            print("Invalid URL for login endpoint")
//            completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
//            return
//        }
//
//        let body: [String: Any] = ["username": identifier, "password": password]
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
//        
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                print("Login request failed: \(error.localizedDescription)")
//                DispatchQueue.main.async {
//                    completion(false, "Login failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
//                }
//                return
//            }
//            
//            guard let httpResponse = response as? HTTPURLResponse, let responseData = data else {
//                print("No response or data received from login request")
//                DispatchQueue.main.async {
//                    completion(false, "No response from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
//                }
//                return
//            }
//            
//            print("Received HTTP response status code: \(httpResponse.statusCode)")
//            let responseString = String(data: responseData, encoding: .utf8)
//            print("Response data string: \(String(describing: responseString))")
//            
//            if httpResponse.statusCode == 200 {
//                do {
//                    if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
//                        let token = json["token"] as? String
//                        let email = json["email"] as? String
//                        let username = json["username"] as? String
//                        let activeTeamId = json["activeTeamId"] as? Int
//                        let activeWorkspaceId = json["activeWorkspaceId"] as? Int
//                        let profileInitial = json["profileInitial"] as? String
//                        let profileColor = json["profileColor"] as? String
//                        let subscriptionStatus = json["subscriptionStatus"] as? String
//                        let subscriptionPlan = json["subscriptionPlan"] as? String
//                        let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
//                        let subscriptionRenews = json["subscriptionRenews"] as? Bool
//                        let subscriptionSeats = json["subscriptionSeats"] as? Int
//                                            let canCreateNewTeam = json["canCreateNewTeam"] as? Bool
//                        DispatchQueue.main.async {
//                            completion(true, nil, email, username, activeTeamId, activeWorkspaceId, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, canCreateNewTeam)
//                        }
//                    } else {
//                        DispatchQueue.main.async {
//                            completion(false, "Invalid response format", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
//                        }
//                    }
//                } catch {
//                    DispatchQueue.main.async {
//                        completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
//                    }
//                }
//            } else {
//                DispatchQueue.main.async {
//                    completion(false, responseString ?? "Login failed with status code: \(httpResponse.statusCode)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
//                }
//            }
//        }.resume()
//    }
    func login(identifier: String, password: String, completion: @escaping (Bool, String?, String?, String?, Int?, Int?, String?, String?, String?, String?, String?, Bool?, Int?, Bool?, Int?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/login/") else {
            print("Invalid URL for login endpoint")
            completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
            return
        }

        let body: [String: Any] = ["username": identifier, "password": password]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Login request failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, "Login failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let responseData = data else {
                print("No response or data received from login request")
                DispatchQueue.main.async {
                    completion(false, "No response from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                }
                return
            }
            
            print("Received HTTP response status code: \(httpResponse.statusCode)")
            let responseString = String(data: responseData, encoding: .utf8)
            print("Response data string: \(String(describing: responseString))")
            
            if httpResponse.statusCode == 200 {
                do {
                    if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
                        let userId = json["userId"] as? Int  // Get userId as integer
                        let token = json["token"] as? String
                        let email = json["email"] as? String
                        let username = json["username"] as? String
                        let activeTeamId = json["activeTeamId"] as? Int
                        let activeWorkspaceId = json["activeWorkspaceId"] as? Int
                        let profileInitial = json["profileInitial"] as? String
                        let profileColor = json["profileColor"] as? String
                        let subscriptionStatus = json["subscriptionStatus"] as? String
                        let subscriptionPlan = json["subscriptionPlan"] as? String
                        let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
                        let subscriptionRenews = json["subscriptionRenews"] as? Bool
                        let subscriptionSeats = json["subscriptionSeats"] as? Int
                        let canCreateNewTeam = json["canCreateNewTeam"] as? Bool
                        
                        DispatchQueue.main.async {
                            completion(true, nil, email, username, activeTeamId, activeWorkspaceId, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, canCreateNewTeam, userId)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(false, "Invalid response format", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, responseString ?? "Login failed with status code: \(httpResponse.statusCode)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                }
            }
        }.resume()
    }

    func updateUserInformation(email: String, name: String, username: String, birthday: String, completion: @escaping (Bool, String) -> Void) {
         let url = URL(string: "\(baseUrl)/add-info/")! // Adjust the URL
         var request = URLRequest(url: url)
         request.httpMethod = "PUT"
         request.addValue("application/json", forHTTPHeaderField: "Content-Type")

         let parameters: [String: Any] = [
             "email": email,
             "name": name,
             "username": username,
             "birthday": birthday, // ISO 8601 format
            
         ]

         request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

         URLSession.shared.dataTask(with: request) { data, response, error in
             guard let data = data, error == nil else {
                 completion(false, "Network request failed")
                 return
             }

             // Decode or handle the response accordingly
             // For simplicity, we'll assume a successful response includes a 'message' key
             do {
                 if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let message = jsonResponse["message"] as? String {
                     completion(true, message)
                 } else {
                     completion(false, "Invalid response from server")
                 }
             } catch {
                 completion(false, "Failed to decode response")
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

          print("Attempting to upload to: \(url)")
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
    
//    func fetchPodsForUser2(email: String, completion: @escaping ([Pod]?, Error?) -> Void) {
//        let urlString = "\(baseUrl)/get-user-pods2/\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
//        
//        guard let url = URL(string: urlString) else {
//            completion(nil, NetworkError.invalidURL)
//            return
//        }
//        
//        URLSession.shared.dataTask(with: url) { data, response, error in
//            if let error = error {
//                completion(nil, error)
//                return
//            }
//            
//            guard let data = data else {
//                completion(nil, NetworkError.noData)
//                return
//            }
//            
//            do {
//                let response = try JSONDecoder().decode(PodResponse.self, from: data)
//                let pods = response.pods.map { Pod(from: $0) }
//                completion(pods, nil)
//            } catch {
//                completion(nil, error)
//            }
//        }.resume()
//    }
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


//    func fetchFullPodDetails(email: String, podId: Int, completion: @escaping (Result<Pod, Error>) -> Void) {
//         let urlString = "\(baseUrl)/get-full-pod-details/\(email)/\(podId)"
//         
//         guard let url = URL(string: urlString) else {
//             completion(.failure(NetworkError.invalidURL))
//             return
//         }
//         
//         var request = URLRequest(url: url)
//         request.httpMethod = "GET"
//         
//         URLSession.shared.dataTask(with: request) { data, response, error in
//             if let error = error {
//                 completion(.failure(error))
//                 return
//             }
//             
//             guard let data = data else {
//                 completion(.failure(NetworkError.noData))
//                 return
//             }
//         
//               
//             do {
//                 let decoder = JSONDecoder()
//                 
//                 // Create a date formatter for the 'created_at' field
//                 let createdAtFormatter = DateFormatter()
//                 createdAtFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//                 
//                 // Create an ISO8601DateFormatter for the 'lastVisited' field
//                 let iso8601Formatter = ISO8601DateFormatter()
//                 iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
//                 
//                 decoder.dateDecodingStrategy = .custom { decoder in
//                     let container = try decoder.singleValueContainer()
//                     let dateString = try container.decode(String.self)
//                     
//                     // Try parsing with 'created_at' format first
//                     if let date = createdAtFormatter.date(from: dateString) {
//                         return date
//                     }
//                     
//                     // If that fails, try ISO8601 format (for 'lastVisited')
//                     if let date = iso8601Formatter.date(from: dateString) {
//                         return date
//                     }
//                     
//                     // If both fail, throw an error
//                     throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
//                 }
//                 
//                 let podJSON = try decoder.decode(PodJSON.self, from: data)
//                 let pod = Pod(from: podJSON)
//    
//                 completion(.success(pod))
//             } catch {
//                 print("Decoding error: \(error)")
//                 if let dataString = String(data: data, encoding: .utf8) {
//                     print("Received data: \(dataString)")
//                 }
//                 completion(.failure(error))
//             }
//         }.resume()
//     }
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
                print("Raw JSON response:\n\(rawResponse)")
            }
            
            do {
                let decoder = JSONDecoder()
                
                // Date decoding: assume 'created_at' uses "yyyy-MM-dd HH:mm:ss"
                // and 'lastVisited' uses ISO8601 with fractional seconds.
                let createdAtFormatter = DateFormatter()
                createdAtFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    if let date = createdAtFormatter.date(from: dateString) {
                        return date
                    }
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                }
                
                // Decode the JSON into your temporary PodJSON model.
                let podJSON = try decoder.decode(PodJSON.self, from: data)
                // Convert the PodJSON into your Pod model.
                let pod = Pod(from: podJSON)
                
                // Debug: Print the count of decoded pod items.
                print("Decoded pod items count: \(pod.items.count)")
                
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
                print("Decoding error: \(error)")
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
    func sendTokenToBackend(idToken: String, completion: @escaping (Bool, String?, String?, String?, Int?, Int?, String?, String?, String?, String?, String?, Bool?, Int?, Bool?, Int?, Bool) -> Void) {
        guard let url = URL(string: "\(baseUrl)/google-login/") else {
            completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
            return
        }

        let body: [String: Any] = ["token": idToken]
        let finalBody = try? JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = finalBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, "Request failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
                }
                return
            }

            guard let data = data else {
                print("No data received from server")
                DispatchQueue.main.async {
                    completion(false, "No data from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    let token = json["token"] as? String
                    let email = json["email"] as? String
                    let username = json["username"] as? String
                    let activeTeamId = (json["activeTeamId"] as? NSNumber)?.intValue
                    let activeWorkspaceId = (json["activeWorkspaceId"] as? NSNumber)?.intValue
                    let profileInitial = json["profileInitial"] as? String
                    let profileColor = json["profileColor"] as? String
                    let subscriptionStatus = json["subscriptionStatus"] as? String
                    let subscriptionPlan = json["subscriptionPlan"] as? String
                    let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
                    let subscriptionRenews = json["subscriptionRenews"] as? Bool ?? false
                    let subscriptionSeats = (json["subscriptionSeats"] as? NSNumber)?.intValue
                    let canCreateNewTeam = json["canCreateNewTeam"] as? Bool ?? false
                    let userId = (json["userId"] as? NSNumber)?.intValue
                    let isNewUser = json["isNewUser"] as? Bool ?? false

                    print("Debug - Server Response: \(json)")

                    DispatchQueue.main.async {
                        completion(
                            token != nil,
                            nil,
                            email,
                            username,
                            activeTeamId,
                            activeWorkspaceId,
                            profileInitial,
                            profileColor,
                            subscriptionStatus,
                            subscriptionPlan,
                            subscriptionExpiresAt,
                            subscriptionRenews,
                            subscriptionSeats,
                            canCreateNewTeam,
                            userId,
                            isNewUser
                        )
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, "Invalid data from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to parse response: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
                }
            }
        }.resume()
    }

    func sendAppleTokenToBackend(idToken: String, nonce: String, completion: @escaping (Bool, String?, String?, String?, Int?, Int?, String?, String?, String?, String?, String?, Bool?, Int?, Bool?, Int?, Bool) -> Void) {
        guard let url = URL(string: "\(baseUrl)/apple-login/") else {
            completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
            return
        }

        let body: [String: Any] = [
            "token": idToken,
            "nonce": nonce
        ]
        let finalBody = try? JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = finalBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, "Request failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
                }
                return
            }

            guard let data = data else {
                print("No data received from server")
                DispatchQueue.main.async {
                    completion(false, "No data from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    let token = json["token"] as? String
                    let email = json["email"] as? String
                    let username = json["username"] as? String
                    let activeTeamId = (json["activeTeamId"] as? NSNumber)?.intValue
                    let activeWorkspaceId = (json["activeWorkspaceId"] as? NSNumber)?.intValue
                    let profileInitial = json["profileInitial"] as? String
                    let profileColor = json["profileColor"] as? String
                    let subscriptionStatus = json["subscriptionStatus"] as? String
                    let subscriptionPlan = json["subscriptionPlan"] as? String
                    let subscriptionExpiresAt = json["subscriptionExpiresAt"] as? String
                    let subscriptionRenews = json["subscriptionRenews"] as? Bool ?? false
                    let subscriptionSeats = (json["subscriptionSeats"] as? NSNumber)?.intValue
                    let canCreateNewTeam = json["canCreateNewTeam"] as? Bool ?? false
                    let userId = (json["userId"] as? NSNumber)?.intValue
                    let isNewUser = json["isNewUser"] as? Bool ?? false

                    print("Debug - Server Response: \(json)")
                 
                    print("Debug - Raw isNewUser from backend: \(String(describing: json["isNewUser"]))")

                    DispatchQueue.main.async {
                        completion(
                            token != nil,
                            nil,
                            email,
                            username,
                            activeTeamId,
                            activeWorkspaceId,
                            profileInitial,
                            profileColor,
                            subscriptionStatus,
                            subscriptionPlan,
                            subscriptionExpiresAt,
                            subscriptionRenews,
                            subscriptionSeats,
                            canCreateNewTeam,
                            userId,
                            isNewUser
                        )
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, "Invalid data from server", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to parse response: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false)
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
    
//    func createQuickPod(podTitle: String, templateId: Int, email: String, workspaceId: Int?, completion: @escaping (Bool, String?) -> Void) {
//        guard let url = URL(string: "\(baseUrl)/create-quick-pod/") else {
//            completion(false, "Invalid URL")
//            return
//        }
//
//        var body: [String: Any] = [
//            "title": podTitle,
//            "templateId": templateId,
//            "email": email
//        ]
//
//        if let workspaceId = workspaceId {
//            body["workspace_id"] = workspaceId
//        }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//
//        do {
//            request.httpBody = try JSONSerialization.data(withJSONObject: body)
//        } catch {
//            completion(false, "Failed to encode request body")
//            return
//        }
//
//
//
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                DispatchQueue.main.async {
//                    completion(false, "Network error: \(error.localizedDescription)")
//                }
//                return
//            }
//
//            guard let httpResponse = response as? HTTPURLResponse else {
//                DispatchQueue.main.async {
//                    completion(false, "No response from server")
//                }
//                return
//            }
//
//            if httpResponse.statusCode == 201 {
//                if let data = data,
//                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//                   let podId = json["pod_id"] as? Int {
//                    DispatchQueue.main.async {
//                        completion(true, String(podId))
//                    }
//                } else {
//                    DispatchQueue.main.async {
//                        completion(false, "Pod created successfully, but couldn't retrieve pod ID")
//                    }
//                }
//            } else {
//                if let data = data,
//                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//                   let errorMessage = json["error"] as? String {
//                    DispatchQueue.main.async {
//                        completion(false, errorMessage)
//                    }
//                } else {
//                    DispatchQueue.main.async {
//                        completion(false, "Failed to create pod. Status code: \(httpResponse.statusCode)")
//                    }
//                }
//            }
//        }.resume()
//    }
    
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
    
    
    

    
//    func updatePodDetails(podId: Int, title: String, description: String, instructions: String, type: String, completion: @escaping (Result<(String, String, String, String), Error>) -> Void) {
//        guard let url = URL(string: "\(baseUrl)/update-pod-details/\(podId)/") else {
//            completion(.failure(NetworkError.invalidURL))
//            return
//        }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "PUT"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        
//        let body: [String: Any] = [
//            "title": title,
//            "description": description,
//            "instructions": instructions,
//            "type": type,
//            
//        ]
//        
//        do {
//            request.httpBody = try JSONSerialization.data(withJSONObject: body)
//        } catch {
//            completion(.failure(error))
//            return
//        }
//        
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                completion(.failure(error))
//                return
//            }
//            
//            guard let data = data else {
//                completion(.failure(NetworkError.noData))
//                return
//            }
//            
//            do {
//                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
//                   let podData = json["pod"] as? [String: Any],
//                   let updatedTitle = podData["title"] as? String,
//                   let updatedDescription = podData["description"] as? String,
//                   let updatedInstructions = podData["instructions"] as? String,
//                   let updatedType = podData["type"] as? String {
//                    completion(.success((updatedTitle, updatedDescription, updatedInstructions, updatedType)))
//                } else {
//                    completion(.failure(NetworkError.decodingError))
//                }
//            } catch {
//                completion(.failure(error))
//            }
//        }.resume()
//    }
    
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
                   let updatedTitle = podData["title"] as? String,
                   let updatedDescription = podData["description"] as? String,
                   let updatedInstructions = podData["instructions"] as? String,
                   let updatedType = podData["type"] as? String,
                   let updatedPrivacy = podData["privacy"] as? String {
                    completion(.success((
                        updatedTitle,
                        updatedDescription,
                        updatedInstructions,
                        updatedType,
                        updatedPrivacy
                    )))
                } else {
                    // Now json is accessible here
                    if let podData = json?["pod"] as? [String: Any] {
                        print("Pod data received: \(podData)")
                    }
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
    
//    func createActivity(podId: Int,
//                        userEmail: String,
//                        duration: Int,
//                        notes: String?,
//                        items: [(id: Int, notes: String?, columnValues: [String: Any])],
//                        completion: @escaping (Result<Activity, Error>) -> Void) {
//         
//         let urlString = "\(baseUrl)/create-activity/"
//         guard let url = URL(string: urlString) else {
//             completion(.failure(NetworkError.invalidURL))
//             return
//         }
//         
//         let itemsData = items.map { item in
//             [
//                 "itemId": item.id,
//                 "notes": item.notes ?? "",
//                 "columnValues": item.columnValues
//             ]
//         }
//         
//         let parameters: [String: Any] = [
//             "podId": podId,
//             "userEmail": userEmail,
//             "duration": duration,
//             "notes": notes ?? "",
//             "loggedAt": ISO8601DateFormatter().string(from: Date()),
//             "items": itemsData
//         ]
//         
//         var request = URLRequest(url: url)
//         request.httpMethod = "POST"
//         request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//         
//         do {
//             request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
//         } catch {
//             completion(.failure(error))
//             return
//         }
//         
//         URLSession.shared.dataTask(with: request) { data, response, error in
//             if let error = error {
//                 completion(.failure(error))
//                 return
//             }
//             
//             guard let data = data else {
//                 completion(.failure(NetworkError.noData))
//                 return
//             }
//             
//             do {
//                 let decoder = JSONDecoder()
//                 let activity = try decoder.decode(Activity.self, from: data)
//                 completion(.success(activity))
//             } catch {
//                 completion(.failure(error))
//             }
//         }.resume()
//     }
//
    
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
        // 1) Construct the URL for your “update-activity/<id>/” endpoint
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
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            
            // 6) Decode the updated Activity
            do {
                let decoder = JSONDecoder()
                let updatedActivity = try decoder.decode(Activity.self, from: data)
                completion(.success(updatedActivity))
            } catch {
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
        }
        task.resume()
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
}

