import Foundation

class NetworkManager {

    
//    let baseUrl = "https://humuli-2b3070583cda.herokuapp.com"

    let baseUrl = "http://192.168.1.251:8000"

    

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
//    func login(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
//        guard let url = URL(string: "\(baseUrl)/login/") else {
//            completion(false, "Invalid URL")
//            return
//        }
//        
//        let body: [String: Any] = ["username": username, "password": password]
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
//                    completion(false, "Login failed: \(error.localizedDescription)")
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
//            if httpResponse.statusCode == 200 {
//                // Login successful
//                DispatchQueue.main.async {
//                    completion(true, nil)
//                }
//            } else {
//                // Extract error message if available
//                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let errorMessage = json["error"] as? String {
//                    DispatchQueue.main.async {
//                        completion(false, errorMessage)
//                    }
//                } else {
//                    DispatchQueue.main.async {
//                        completion(false, "Login failed with statusCode: \(httpResponse.statusCode)")
//                    }
//                }
//            }
//        }.resume()
//    }
//    
    
    func login(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/login/") else {
            print("Invalid URL for login endpoint")
            completion(false, "Invalid URL")
            return
        }

        let body: [String: Any] = ["username": username, "password": password]
        var finalBody: Data? = nil
        do {
            finalBody = try JSONSerialization.data(withJSONObject: body)
            print("Sending login request with body: \(String(data: finalBody!, encoding: .utf8) ?? "")")
        } catch {
            print("Error serializing login request body: \(error)")
            completion(false, "Error creating request body")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = finalBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Login request failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, "Login failed: \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let responseData = data else {
                print("No response or data received from login request")
                DispatchQueue.main.async {
                    completion(false, "No response from server")
                }
                return
            }
            
            print("Received HTTP response status code: \(httpResponse.statusCode)")
            let responseString = String(data: responseData, encoding: .utf8)
            print("Response data string: \(String(describing: responseString))")
            
            if httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } else {
                let errorMessage = responseString ?? "Login failed with statusCode: \(httpResponse.statusCode)"
                DispatchQueue.main.async {
                    completion(false, errorMessage)
                }
            }
        }.resume()
    }

    func updateUserInformation(email: String, firstName: String, lastName: String, username: String, birthday: String, completion: @escaping (Bool, String) -> Void) {
         let url = URL(string: "\(baseUrl)/add-info/")! // Adjust the URL
         var request = URLRequest(url: url)
         request.httpMethod = "PUT"
         request.addValue("application/json", forHTTPHeaderField: "Content-Type")

         let parameters: [String: Any] = [
             "email": email,
             "firstName": firstName,
             "lastName": lastName,
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
        guard let containerName = ProcessInfo.processInfo.environment["BLOB_CONTAINER"] else {
            print("No container name found in environment variables.")
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
                            var updatedItem = PodItem(id: item.id, videoURL: URL(string: videoUrl), metadata: item.metadata, thumbnail: nil, thumbnailURL: nil)
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
                        let updatedItem = PodItem(id: item.id, videoURL: nil, image: nil, metadata: item.metadata, thumbnail: nil, thumbnailURL: URL(string: imageUrl))
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


//    func createPod(podTitle: String, items: [PodItem], email: String, completion: @escaping (Bool, String?) -> Void) {
//        print("Starting createPod...")
//        let dispatchGroup = DispatchGroup()
//        var updatedItems = [PodItem]()
//        var uploadErrors = [String]()
//        guard let containerName = ProcessInfo.processInfo.environment["BLOB_CONTAINER"] else {
//            print("No container name found in environment variables.")
//            completion(false, "No container name found.")
//            return
//        }
//
//        items.forEach { item in
//            dispatchGroup.enter()
//            let videoBlobName = UUID().uuidString + ".mp4"
//            guard let videoData = try? Data(contentsOf: item.videoURL) else {
//                print("Failed to load video data for URL: \(item.videoURL)")
//                uploadErrors.append("Failed to load video data for URL: \(item.videoURL)")
//                dispatchGroup.leave()
//                return
//            }
//
//            print("Uploading video for item \(item.id)...")
//            uploadFileToAzureBlob(containerName: containerName, blobName: videoBlobName, fileData: videoData, contentType: "video/mp4") { success, videoUrlString in
//                guard success, let videoUrl = videoUrlString else {
//                    print("Failed to upload video for item \(item.id)")
//                    uploadErrors.append("Failed to upload video for item \(item.id)")
//                    dispatchGroup.leave()
//                    return
//                }
//
//                print("Video uploaded successfully for item \(item.id)")
//                if let thumbnailImage = item.thumbnail, let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.8) {
//                    let thumbnailBlobName = UUID().uuidString + ".jpg"
//                    print("Uploading thumbnail for item \(item.id)...")
//                    self.uploadFileToAzureBlob(containerName: containerName, blobName: thumbnailBlobName, fileData: thumbnailData, contentType: "image/jpeg") { success, thumbnailUrlString in
//                        guard success, let thumbnailUrl = thumbnailUrlString else {
//                            print("Failed to upload thumbnail for item \(item.id)")
//                            uploadErrors.append("Failed to upload thumbnail for item \(item.id)")
//                            dispatchGroup.leave()
//                            return
//                        }
//
//                        print("Thumbnail uploaded successfully for item \(item.id)")
//                        let updatedItem = PodItem(id: item.id, videoURL: URL(string: videoUrl)!, metadata: item.metadata, thumbnail: nil, thumbnailURL: URL(string: thumbnailUrl))
//                        updatedItems.append(updatedItem)
//                        dispatchGroup.leave()
//                    }
//                } else {
//                    let updatedItem = PodItem(id: item.id, videoURL: URL(string: videoUrl)!, metadata: item.metadata, thumbnail: nil, thumbnailURL: nil)
//                    updatedItems.append(updatedItem)
//                    dispatchGroup.leave()
//                }
//            }
//        }
//
//        dispatchGroup.notify(queue: .main) {
//            if !uploadErrors.isEmpty {
//                print("Failed to upload one or more items: \(uploadErrors.joined(separator: ", "))")
//                completion(false, "Failed to upload one or more items: \(uploadErrors.joined(separator: ", "))")
//                return
//            }
//
//            print("Sending pod creation request...")
//            self.sendPodCreationRequest(podTitle: podTitle, items: updatedItems, email: email) { success, message in
//                print("Pod creation request result: \(success), message: \(String(describing: message))")
//                completion(success, message)
//            }
//        }
//    }

    func sendPodCreationRequest(podTitle: String, items: [PodItem], email: String, completion: @escaping (Bool, String?) -> Void) {
//        guard let url = URL(string: "\(baseUrl)/create-pod/") else {
//            print("Invalid URL for pod creation")
//            completion(false, "Invalid URL")
//            return
//        }
//
//        print("Sending pod creation request to \(url)")
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//
//        let itemsForBody = items.map { item -> [String: Any] in
//            var itemDict: [String: Any] = ["videoURL": item.videoURL.absoluteString, "label": item.metadata]
//            if let thumbnailURL = item.thumbnailURL {
//                itemDict["thumbnail"] = thumbnailURL.absoluteString
//            }
//            return itemDict
//        }
//
//        let body: [String: Any] = ["title": podTitle, "items": itemsForBody, "email": email]
//        do {
//            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
//            if let requestBody = request.httpBody, let requestBodyString = String(data: requestBody, encoding: .utf8) {
//                print("Request Body: \(requestBodyString)")
//            }
//        } catch {
//            print("Failed to encode request body, error: \(error)")
//            completion(false, "Failed to encode request body")
//            return
//        }
        guard let url = URL(string: "\(baseUrl)/create-pod/") else {
              print("Invalid URL for pod creation")
              completion(false, "Invalid URL")
              return
          }

          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.addValue("application/json", forHTTPHeaderField: "Content-Type")

          let itemsForBody = items.map { item -> [String: Any] in
              var itemDict: [String: Any] = ["label": item.metadata]

              // Include videoURL if it exists
              if let videoURL = item.videoURL?.absoluteString {
                  itemDict["videoURL"] = videoURL
              }

              // Include imageURL if it exists
              if let imageURL = item.imageURL?.absoluteString {
                  itemDict["imageURL"] = imageURL
              }

              // Include thumbnailURL if it exists
              if let thumbnailURL = item.thumbnailURL?.absoluteString {
                  itemDict["thumbnail"] = thumbnailURL
              }

              return itemDict
          }

          let body: [String: Any] = ["title": podTitle, "items": itemsForBody, "email": email]
          do {
              request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
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

    func uploadFileToAzureBlob(containerName: String, blobName: String, fileData: Data, contentType: String, completion: @escaping (Bool, String?) -> Void) {
        guard let accountName = ProcessInfo.processInfo.environment["BLOB_NAME"],
              let sasToken = ProcessInfo.processInfo.environment["SAS_TOKEN"] else {
            print("Missing required configuration for Azure Blob Storage")
            completion(false, "Missing required configuration")
            return
        }

        let endpoint = "https://\(accountName).blob.core.windows.net/\(containerName)/\(blobName)?\(sasToken)"
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
                    let blobUrl = "https://\(accountName).blob.core.windows.net/\(containerName)/\(blobName)"
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




    func fetchPodsForUser(email: String, completion: @escaping (Bool, [Pod]?, String?) -> Void) {
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(NetworkManager().baseUrl)/get-user-pods/\(encodedEmail)") else {
            completion(false, nil, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Add headers if needed, e.g., Authorization
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(false, nil, "Network request failed")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                do {
                    let podResponse = try JSONDecoder().decode(PodResponse.self, from: data)
                    // Use the custom initializer for Pod which was added as an extension.
                    let pods = podResponse.pods.map { Pod(from: $0) }
                    completion(true, pods, nil)
                } catch {
                    print(error)
                    completion(false, nil, "Failed to decode pods")
                }
            } else {
                completion(false, nil, "Failed to fetch pods")
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



}
