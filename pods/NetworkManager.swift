import Foundation
import SwiftUI


class NetworkManager {

  
//    let baseUrl = "https://humuli-2b3070583cda.herokuapp.com"
   
    let baseUrl = "http://192.168.1.67:8000"

//    let baseUrl = "http://172.20.10.2:8000"

    
    enum NetworkError: Error {
        case invalidURL
        case invalidResponse
        case decodingError
        case encodingError
        case serverError(String)
        case unknownError
        case noData
    }
    
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
//    func login(identifier: String, password: String, completion: @escaping (Bool, String?, String?, String?, Int?, Int?, String?, String?) -> Void) {
//        guard let url = URL(string: "\(baseUrl)/login/") else {
//            print("Invalid URL for login endpoint")
//            completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil)
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
//                    completion(false, "Login failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil)
//                }
//                return
//            }
//            
//            guard let httpResponse = response as? HTTPURLResponse, let responseData = data else {
//                print("No response or data received from login request")
//                DispatchQueue.main.async {
//                    completion(false, "No response from server", nil, nil, nil, nil, nil, nil)
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
//                        let email = json["email"] as? String
//                        let username = json["username"] as? String
//                        let activeTeamId = json["activeTeamId"] as? Int
//                        let activeWorkspaceId = json["activeWorkspaceId"] as? Int
//                        let profileColor = json["profileColor"] as? String
//                        let profileInitial = json["profileInitial"] as? String
//                        DispatchQueue.main.async {
//                            completion(true, nil, email, username, activeTeamId, activeWorkspaceId, profileInitial, profileColor)
//                        }
//                    } else {
//                        DispatchQueue.main.async {
//                            completion(false, "Invalid response format", nil, nil, nil, nil, nil, nil)
//                        }
//                    }
//                } catch {
//                    DispatchQueue.main.async {
//                        completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil)
//                    }
//                }
//            } else {
//                DispatchQueue.main.async {
//                    completion(false, responseString ?? "Login failed with status code: \(httpResponse.statusCode)", nil, nil, nil, nil, nil, nil)
//                }
//            }
//        }.resume()
//    }
    
    func login(identifier: String, password: String, completion: @escaping (Bool, String?, String?, String?, Int?, Int?, String?, String?, String?, String?, String?) -> Void) {
          guard let url = URL(string: "\(baseUrl)/login/") else {
              print("Invalid URL for login endpoint")
              completion(false, "Invalid URL", nil, nil, nil, nil, nil, nil, nil, nil, nil)
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
                      completion(false, "Login failed: \(error.localizedDescription)", nil, nil, nil, nil, nil, nil, nil, nil, nil)
                  }
                  return
              }
              
              guard let httpResponse = response as? HTTPURLResponse, let responseData = data else {
                  print("No response or data received from login request")
                  DispatchQueue.main.async {
                      completion(false, "No response from server", nil, nil, nil, nil, nil, nil, nil, nil, nil)
                  }
                  return
              }
              
              print("Received HTTP response status code: \(httpResponse.statusCode)")
              let responseString = String(data: responseData, encoding: .utf8)
              print("Response data string: \(String(describing: responseString))")
              
              if httpResponse.statusCode == 200 {
                  do {
                      if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
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
                          DispatchQueue.main.async {
                              completion(true, nil, email, username, activeTeamId, activeWorkspaceId, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt)
                          }
                      } else {
                          DispatchQueue.main.async {
                              completion(false, "Invalid response format", nil, nil, nil, nil, nil, nil, nil, nil, nil)
                          }
                      }
                  } catch {
                      DispatchQueue.main.async {
                          completion(false, "Failed to parse response", nil, nil, nil, nil, nil, nil, nil, nil, nil)
                      }
                  }
              } else {
                  DispatchQueue.main.async {
                      completion(false, responseString ?? "Login failed with status code: \(httpResponse.statusCode)", nil, nil, nil, nil, nil, nil, nil, nil, nil)
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

    //singleton fetchPodUser
//    func fetchPodsForUser(email: String, workspaceId: Int? = nil, showFavorites: Bool = false, showRecentlyVisited: Bool = false, completion: @escaping (Bool, [Pod]?, String?) -> Void) {
//        var urlString = "\(baseUrl)/get-user-pods/\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
//        
//        if let workspaceId = workspaceId {
//            urlString += "&workspaceId=\(workspaceId)"
//        }
//        if showFavorites {
//            urlString += "&favorites=true"
//        }
//        if showRecentlyVisited {
//            urlString += "&recentlyVisited=true"
//        }
//        
//        guard let url = URL(string: urlString) else {
//            completion(false, nil, "Invalid URL")
//            return
//        }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "GET"
//        
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            guard let data = data, error == nil else {
//                completion(false, nil, "Network request failed")
//                return
//            }
//            
//            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
//                do {
//                    let decoder = JSONDecoder()
//                    decoder.dateDecodingStrategy = .custom { decoder in
//                        let container = try decoder.singleValueContainer()
//                        let dateString = try container.decode(String.self)
//                        
//                        let formatterWithFractionalSeconds = ISO8601DateFormatter()
//                        formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
//                        
//                        let formatterWithoutFractionalSeconds = ISO8601DateFormatter()
//                        formatterWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]
//                        
//                        if let date = formatterWithFractionalSeconds.date(from: dateString) {
//                            return date
//                        } else if let date = formatterWithoutFractionalSeconds.date(from: dateString) {
//                            return date
//                        } else {
//                            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
//                        }
//                    }
//                    
//                    let podResponse = try decoder.decode(PodResponse.self, from: data)
//                    let pods = podResponse.pods.map { Pod(from: $0) }
//
//                    completion(true, pods, nil)
//                } catch {
//                    print("Decoding error: \(error)")
//                    completion(false, nil, "Failed to decode pods: \(error.localizedDescription)")
//                }
//            } else {
//                completion(false, nil, "Failed to fetch pods")
//            }
//        }.resume()
//    }
    func fetchPodsForUser(email: String, workspaceId: Int? = nil, showFavorites: Bool = false, showRecentlyVisited: Bool = false, completion: @escaping (Result<[Pod], Error>) -> Void) {
        var urlString = "\(baseUrl)/get-user-pods/\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
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
//    func sendTokenToBackend(idToken: String, completion: @escaping (Bool, String?, Bool, String?, String?) -> Void) {
//        guard let url = URL(string: "\(baseUrl)/google-login/") else {
//            completion(false, "Invalid URL", false, nil, nil)
//            return
//        }
//
//        let body: [String: Any] = ["token": idToken]
//        let finalBody = try? JSONSerialization.data(withJSONObject: body)
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = finalBody
//
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                DispatchQueue.main.async {
//                    completion(false, "Request failed: \(error.localizedDescription)", false, nil, nil)
//                }
//                return
//            }
//
//            guard let data = data else {
//                DispatchQueue.main.async {
//                    completion(false, "No data from server", false, nil, nil)
//                }
//                return
//            }
//
//            do {
//                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
//                   let token = json["token"] as? String,
//                   let isNewUser = json["is_new_user"] as? Bool,
//                   let email = json["email"] as? String,
//                   let username = json["username"] as? String {
//                    DispatchQueue.main.async {
//                        completion(true, nil, isNewUser, email, username)
//                    }
//                } else {
//                    DispatchQueue.main.async {
//                        completion(false, "Invalid data from server", false, nil, nil)
//                    }
//                }
//            } catch {
//                DispatchQueue.main.async {
//                    completion(false, "Failed to parse server response: \(error.localizedDescription)", false, nil, nil)
//                }
//            }
//        }.resume()
//    }
    func sendTokenToBackend(idToken: String, completion: @escaping (Bool, String?, Bool, String?, String?, Int?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/google-login/") else {
            completion(false, "Invalid URL", false, nil, nil, nil)
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
                DispatchQueue.main.async {
                    completion(false, "Request failed: \(error.localizedDescription)", false, nil, nil, nil)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(false, "No data from server", false, nil, nil, nil)
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let token = json["token"] as? String,
                   let isNewUser = json["is_new_user"] as? Bool,
                   let email = json["email"] as? String,
                   let username = json["username"] as? String,
                   let activeTeamId = json["activeTeamId"] as? Int {
                    DispatchQueue.main.async {
                        completion(true, nil, isNewUser, email, username, activeTeamId)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, "Invalid data from server", false, nil, nil, nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to parse server response: \(error.localizedDescription)", false, nil, nil, nil)
                }
            }
        }.resume()
    }

    
    func sendAppleTokenToBackend(idToken: String, completion: @escaping (Bool, String?, Bool) -> Void) {
        guard let url = URL(string: "\(baseUrl)/apple-login/") else {
            completion(false, "Invalid URL", false)
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
                DispatchQueue.main.async {
                    print("Request failed with error: \(error.localizedDescription)")
                    completion(false, "Request failed: \(error.localizedDescription)", false)
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    print("No response from server")
                    completion(false, "No response from server", false)
                }
                return
            }

            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                print("Response body: \(responseBody)")
            }

            if httpResponse.statusCode == 200 {
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["token"] as? String, let isNewUser = json["is_new_user"] as? Bool {
                    DispatchQueue.main.async {
                        print("Token sent successfully: \(token)")
                        completion(true, nil, isNewUser)
                    }
                } else {
                    DispatchQueue.main.async {
                        print("Invalid data from server")
                        completion(false, "Invalid data from server", false)
                    }
                }
            } else if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let errorMessage = json["error"] as? String, let errorDescription = json["description"] as? String {
                DispatchQueue.main.async {
                    print("Request failed with statusCode: \(httpResponse.statusCode), error: \(errorMessage), description: \(errorDescription)")
                    completion(false, "\(errorMessage): \(errorDescription)", false)
                }
            } else {
                DispatchQueue.main.async {
                    print("Request failed with statusCode: \(httpResponse.statusCode)")
                    completion(false, "Request failed with statusCode: \(httpResponse.statusCode)", false)
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
    
    func createQuickPod(podTitle: String, templateId: Int, email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/create-quick-pod/") else {
            completion(false, "Invalid URL")
            return
        }

        let body: [String: Any] = [
            "title": podTitle,
            "templateId": templateId,
            "email": email
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
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

            if httpResponse.statusCode == 201 {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let podId = json["pod_id"] as? Int {
                    DispatchQueue.main.async {
                        completion(true, String(podId))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, "Pod created successfully, but couldn't retrieve pod ID")
                    }
                }
            } else {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(false, errorMessage)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, "Failed to create pod. Status code: \(httpResponse.statusCode)")
                    }
                }
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
    
//singleton updatePodItemColumnVaue
//    func updatePodItemColumnValue(itemId: Int, columnName: String, value: ColumnValue, completion: @escaping (Result<Void, Error>) -> Void) {
//        guard let url = URL(string: "\(baseUrl)/update-column-value/\(itemId)/") else {
//            completion(.failure(NetworkError.invalidURL))
//            return
//        }
//
//        let jsonValue: Any
//        switch value {
//        case .string(let stringValue):
//            jsonValue = stringValue
//        case .number(let numberValue):
//            jsonValue = numberValue
//        case .null:
//            jsonValue = NSNull()
//        }
//
//        let body: [String: Any] = [
//            "column_name": columnName,
//            "value": jsonValue
//        ]
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//
//        do {
//            request.httpBody = try JSONSerialization.data(withJSONObject: body)
//        } catch {
//            completion(.failure(NetworkError.encodingError))
//            return
//        }
//
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                completion(.failure(error))
//                return
//            }
//
//            guard let httpResponse = response as? HTTPURLResponse else {
//                completion(.failure(NetworkError.invalidResponse))
//                return
//            }
//
//            switch httpResponse.statusCode {
//            case 200:
//                completion(.success(()))
//            default:
//                if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
//                    completion(.failure(NetworkError.serverError(errorMessage)))
//                } else {
//                    completion(.failure(NetworkError.unknownError))
//                }
//            }
//        }.resume()
//    }
    
    func updatePodItemColumnValue(itemId: Int, columnName: String, value: ColumnValue, userEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/update-column-value/\(itemId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let jsonValue: Any
        switch value {
        case .string(let stringValue):
            jsonValue = stringValue
        case .number(let numberValue):
            jsonValue = numberValue
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
   
  //singleton createPodItem
//        func createPodItem(podId: Int, label: String, itemType: String?, notes: String, columnValues: [String: ColumnValue], completion: @escaping (Result<PodItem, Error>) -> Void) {
//            guard let url = URL(string: "\(baseUrl)/create-pod-item/\(podId)/") else {
//                completion(.failure(NetworkError.invalidURL))
//                return
//            }
//
//            var body: [String: Any] = [
//                "label": label,
//                "notes": notes,
//                "columnValues": columnValues.mapValues { value -> Any in
//                    switch value {
//                    case .string(let str): return str
//                    case .number(let num): return num
//                    case .null: return NSNull()
//                    }
//                }
//            ]
//            
//            if let itemType = itemType {
//                body["itemType"] = itemType
//            }
//
//            var request = URLRequest(url: url)
//            request.httpMethod = "POST"
//            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//            do {
//                request.httpBody = try JSONSerialization.data(withJSONObject: body)
//            } catch {
//                completion(.failure(NetworkError.encodingError))
//                return
//            }
//
//            URLSession.shared.dataTask(with: request) { data, response, error in
//                if let error = error {
//                    completion(.failure(error))
//                    return
//                }
//
//                guard let data = data else {
//                    completion(.failure(NetworkError.decodingError
//                                       ))
//                    return
//                }
//                if let responseString = String(data: data, encoding: .utf8) {
//                          print("Raw response: \(responseString)")
//                      }
//
//                do {
//                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
//                  
//                       let itemData = json["item"] as? [String: Any] {
//                        print("Parsed JSON: \(json)")
//                        let id = itemData["id"] as? Int ?? 0
//                        let label = itemData["label"] as? String ?? ""
//                        let itemType = itemData["itemType"] as? String
//                        let notes = itemData["notes"] as? String ?? ""
//                        let columnValues = (itemData["columnValues"] as? [String: Any])?.compactMapValues { value -> ColumnValue? in
//                            if let stringValue = value as? String {
//                                return .string(stringValue)
//                            } else if let intValue = value as? Int {
//                                return .number(intValue)
//                            } else if value is NSNull {
//                                return .null
//                            }
//                            return nil
//                        } ?? [:]
//                        
////                        let newItem = PodItem(id: id, metadata: label, itemType: itemType, notes: notes, columnValues: columnValues)
//                        let newItem = PodItem(id: id, metadata: label, itemType: itemType, notes: notes)
//                        completion(.success(newItem))
//                    } else {
//                        print("Failed to parse JSON")
//                        completion(.failure(NetworkError.decodingError))
//                    }
//                } catch {
//                    print("JSON parsing error: \(error)")
//                    completion(.failure(NetworkError.decodingError))
//                }
//            }.resume()
//        }
    
    func createPodItem(podId: Int, label: String, itemType: String?, notes: String, defaultColumnValues: [String: ColumnValue], completion: @escaping (Result<PodItem, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/create-pod-item/\(podId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var body: [String: Any] = [
            "label": label,
            "notes": notes,
            "defaultColumnValues": defaultColumnValues.mapValues { value -> Any in
                switch value {
                case .string(let str): return str
                case .number(let num): return num
                case .null: return NSNull()
                }
            }
        ]
        
        if let itemType = itemType {
            body["itemType"] = itemType
        }

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
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw response: \(responseString)")
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let itemData = json["item"] as? [String: Any] {
                    print("Parsed JSON: \(json)")
                    let id = itemData["id"] as? Int ?? 0
                    let label = itemData["label"] as? String ?? ""
                    let itemType = itemData["itemType"] as? String
                    let notes = itemData["notes"] as? String ?? ""
                    let defaultColumnValues = (itemData["defaultColumnValues"] as? [String: Any])?.compactMapValues { value -> ColumnValue? in
                        if let stringValue = value as? String {
                            return .string(stringValue)
                        } else if let intValue = value as? Int {
                            return .number(intValue)
                        } else if value is NSNull {
                            return .null
                        }
                        return nil
                    } ?? [:]
                    
                    let newItem = PodItem(id: id, metadata: label, itemType: itemType, notes: notes, defaultColumnValues: defaultColumnValues, userColumnValues: nil)
                    completion(.success(newItem))
                } else {
                    print("Failed to parse JSON")
                    completion(.failure(NetworkError.decodingError))
                }
            } catch {
                print("JSON parsing error: \(error)")
                completion(.failure(NetworkError.decodingError))
            }
        }.resume()
    }
    
    
// singleton updatePodItem
//        func updatePodItem(itemId: Int, newLabel: String, newNotes: String, newColumnValues: [String: ColumnValue], completion: @escaping (Result<Void, Error>) -> Void) {
//            guard let url = URL(string: "\(baseUrl)/update-pod-item/\(itemId)/") else {
//                completion(.failure(NetworkError.invalidURL))
//                return
//            }
//
//            let columnValuesJson = newColumnValues.mapValues { value -> Any in
//                switch value {
//                case .string(let str): return str
//                case .number(let num): return num
//                case .null: return NSNull()
//                }
//            }
//
//            let body: [String: Any] = [
//                "label": newLabel,
//                "notes": newNotes,
//                "columnValues": columnValuesJson
//            ]
//
//            var request = URLRequest(url: url)
//            request.httpMethod = "PUT"
//            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//            do {
//                request.httpBody = try JSONSerialization.data(withJSONObject: body)
//            } catch {
//                completion(.failure(NetworkError.encodingError))
//                return
//            }
//
//            URLSession.shared.dataTask(with: request) { data, response, error in
//                if let error = error {
//                    completion(.failure(error))
//                    return
//                }
//
//                guard let httpResponse = response as? HTTPURLResponse else {
//                    completion(.failure(NetworkError.invalidResponse))
//                    return
//                }
//
//                switch httpResponse.statusCode {
//                case 200:
//                    completion(.success(()))
//                default:
//                    if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
//                        completion(.failure(NetworkError.serverError(errorMessage)))
//                    } else {
//                        completion(.failure(NetworkError.unknownError))
//                    }
//                }
//            }.resume()
//        }
    
    func updatePodItem(itemId: Int, newLabel: String, newNotes: String, newColumnValues: [String: ColumnValue], userEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/update-pod-item/\(itemId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let columnValuesJson = newColumnValues.mapValues { value -> Any in
            switch value {
            case .string(let str): return str
            case .number(let num): return num
            case .null: return NSNull()
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
    
    func addColumnToPod(podId: Int, columnName: String, columnType: String, completion: @escaping (Result<Void, Error>) -> Void) {
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
    

//    func acceptPodInvitation(podId: Int, token: String, userEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
//            guard let url = URL(string: "\(baseUrl)/accept-pod-invitation/") else {
//                completion(.failure(NetworkError.invalidURL))
//                return
//            }
//
//            let body: [String: Any] = [
//                "pod_id": podId,
//                "token": token,
//                "user_email": userEmail  // Assuming you have a userEmail property in NetworkManager
//            ]
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
    

    
    func updatePodDetails(podId: Int, title: String, description: String, type: String, completion: @escaping (Result<(String, String, String), Error>) -> Void) {
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
            "type": type
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
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let podData = json["pod"] as? [String: Any],
                   let updatedTitle = podData["title"] as? String,
                   let updatedDescription = podData["description"] as? String,
                   let updatedType = podData["type"] as? String {
                    completion(.success((updatedTitle, updatedDescription, updatedType)))
                } else {
                    completion(.failure(NetworkError.decodingError))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    

  
//        func fetchPodMembers(podId: Int, userEmail: String, completion: @escaping (Result<([PodMember], String), Error>) -> Void) {
//            let urlString = "\(baseUrl)/get-pod-members/\(podId)/"
//            
//            guard let url = URL(string: urlString) else {
//                completion(.failure(NetworkError.invalidURL))
//                return
//            }
//            
//            var request = URLRequest(url: url)
//            request.httpMethod = "POST"
//            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//            
//            let body: [String: Any] = ["userEmail": userEmail]
//            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
//            
//            URLSession.shared.dataTask(with: request) { data, response, error in
//                if let error = error {
//                    completion(.failure(error))
//                    return
//                }
//                
//                guard let data = data else {
//                    completion(.failure(NetworkError.noData))
//                    return
//                }
//                
//                do {
//                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
//                       let membersData = json["members"] as? [[String: Any]],
//                       let userRole = json["userRole"] as? String {
//                        
//                        let members = membersData.compactMap { memberDict -> PodMember? in
//                            guard let id = memberDict["id"] as? Int,
//                                  let name = memberDict["name"] as? String,
//                                  let email = memberDict["email"] as? String,
//                                  let profileInitial = memberDict["profileInitial"] as? String,
//                                  let profileColor = memberDict["profileColor"] as? String,
//                                  let role = memberDict["role"] as? String else {
//                                return nil
//                            }
//                            return PodMember(id: id, name: name, email: email, profileInitial: profileInitial, profileColor: profileColor, role: role)
//                        }
//                        
//                        completion(.success((members, userRole)))
//                    } else {
//                        completion(.failure(NetworkError.decodingError))
//                    }
//                } catch {
//                    completion(.failure(error))
//                }
//            }.resume()
//        }
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
  
    //singleton createActivityLog
//    func createActivityLog(itemId: Int, podId: Int, userEmail: String, columnValues: [String: ColumnValue], podColumns: [PodColumn], notes: String, completion: @escaping (Result<Date, Error>) -> Void) {
//        guard let url = URL(string: "\(baseUrl)/create-activity-log/") else {
//            completion(.failure(NetworkError.invalidURL))
//            return
//        }
//
//        let serializedColumnData = podColumns.compactMap { column -> [String: Any]? in
//            guard let value = columnValues[column.name] else { return nil }
//            
//            let serializedValue: Any
//            switch value {
//            case .string(let str):
//                serializedValue = str
//            case .number(let num):
//                serializedValue = num
//            case .null:
//                serializedValue = NSNull()
//            }
//            
//            return [
//                "name": column.name,
//                "type": column.type,
//                "value": serializedValue
//            ]
//        }
//
//        let body: [String: Any] = [
//            "itemId": itemId,
//            "podId": podId,
//            "userEmail": userEmail,
//            "columnData": serializedColumnData,
//            "notes": notes
//        ]
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//        do {
//            request.httpBody = try JSONSerialization.data(withJSONObject: body)
//        } catch {
//            completion(.failure(NetworkError.encodingError))
//            return
//        }
//
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                print("Network error: \(error.localizedDescription)")
//                completion(.failure(error))
//                return
//            }
//
//            guard let data = data else {
//                print("No data received from server")
//                completion(.failure(NetworkError.noData))
//                return
//            }
//
//            do {
//                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
//                    print("Received JSON: \(json)")
//                    
//                    // Check if 'success' is 1 (true) as an integer
//                    let success = (json["success"] as? Int) == 1
//                    
//                    if success,
//                       let loggedAtString = json["loggedAt"] as? String {
//                        // Create a custom date formatter to handle the server's date format
//                        let dateFormatter = ISO8601DateFormatter()
//                        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
//                        
//                        if let loggedAt = dateFormatter.date(from: loggedAtString) {
//                            completion(.success(loggedAt))
//                        } else {
//                            print("Failed to parse date: \(loggedAtString)")
//                            completion(.failure(NetworkError.decodingError))
//                        }
//                    } else {
//                        print("Failed to parse success or loggedAt from JSON")
//                        completion(.failure(NetworkError.decodingError))
//                    }
//                } else {
//                    print("Failed to parse JSON")
//                    completion(.failure(NetworkError.decodingError))
//                }
//            } catch {
//                print("JSON parsing error: \(error.localizedDescription)")
//                completion(.failure(error))
//            }
//        }.resume()
//    }
    func createActivityLog(itemId: Int, podId: Int, userEmail: String, columnValues: [String: ColumnValue], podColumns: [PodColumn], notes: String, completion: @escaping (Result<PodItemActivityLog, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/create-activity-log/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let serializedColumnData = podColumns.compactMap { column -> [String: Any]? in
            guard let value = columnValues[column.name] else { return nil }
            
            let serializedValue: Any
            switch value {
            case .string(let str):
                serializedValue = str
            case .number(let num):
                serializedValue = num
            case .null:
                serializedValue = NSNull()
            }
            
            return [
                "name": column.name,
                "type": column.type,
                "value": serializedValue
            ]
        }

        let body: [String: Any] = [
            "itemId": itemId,
            "podId": podId,
            "userEmail": userEmail,
            "columnData": serializedColumnData,
            "notes": notes
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
                print("Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                print("No data received from server")
                completion(.failure(NetworkError.noData))
                return
            }

            do {
                let decoder = JSONDecoder()
                let logJSON = try decoder.decode(PodItemActivityLogJSON.self, from: data)
                let activityLog = PodItemActivityLog(from: logJSON)
                completion(.success(activityLog))
            } catch {
                print("JSON parsing error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
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
  
    //singleton fetchPodItem
//    func fetchPodItem(podId: Int, itemId: Int, completion: @escaping (Result<PodItem, Error>) -> Void) {
//            let urlString = "\(baseUrl)/fetch-pod-item/\(podId)/\(itemId)/"
//            
//            guard let url = URL(string: urlString) else {
//                completion(.failure(NetworkError.invalidURL))
//                return
//            }
//            
//            URLSession.shared.dataTask(with: url) { data, response, error in
//                if let error = error {
//                    completion(.failure(error))
//                    return
//                }
//                
//                guard let data = data else {
//                    completion(.failure(NetworkError.noData))
//                    return
//                }
//                
//                do {
//                    let decoder = JSONDecoder()
//                    let podItemJSON = try decoder.decode(PodItemJSON.self, from: data)
//                    let podItem = PodItem(from: podItemJSON)
//                    completion(.success(podItem))
//                } catch {
//                    completion(.failure(error))
//                }
//            }.resume()
//        }
    
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
}

