import Foundation

class NetworkManager {
    let baseUrl = "http://192.168.1.12:8000"

    

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
    func login(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/login/") else {
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
                    completion(false, "Login failed: \(error.localizedDescription)")
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
                // Login successful
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } else {
                // Extract error message if available
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(false, errorMessage)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, "Login failed with statusCode: \(httpResponse.statusCode)")
                    }
                }
            }
        }.resume()
    }
    
    func updateUserInformation(email: String, firstName: String, lastName: String, birthday: String, completion: @escaping (Bool, String) -> Void) {
         let url = URL(string: "\(baseUrl)/add-info/")! // Adjust the URL
         var request = URLRequest(url: url)
         request.httpMethod = "PUT"
         request.addValue("application/json", forHTTPHeaderField: "Content-Type")

         let parameters: [String: Any] = [
             "email": email,
             "firstName": firstName,
             "lastName": lastName,
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
 

//    func createPod(podTitle: String, items: [PodItem], email: String, completion: @escaping (Bool, String?) -> Void) {
//        print("Starting createPod...")
//        let dispatchGroup = DispatchGroup()
//        var updatedItems = [PodItem]()
//        var uploadErrors = [String]()
//        let containerName = ProcessInfo.processInfo.environment["BLOB_CONTAINER"]
//        print("Container Name: \(String(describing: containerName))")
//
//        items.forEach { item in
//            dispatchGroup.enter()
//            let videoBlobName = UUID().uuidString + ".mp4"
//            guard let videoData = try? Data(contentsOf: item.videoURL) else {
//                print("Failed to load video data for URL: \(item.videoURL)")
//                completion(false, "Failed to load video data for URL: \(item.videoURL)")
//                return
//            }
//
//            print("Uploading video for item \(item.id)...")
//            uploadFileToAzureBlob(containerName: containerName!, blobName: videoBlobName, fileData: videoData, contentType: "video/mp4") { success, videoUrlString in
//                if success, let videoUrl = videoUrlString {
//                    print("Video uploaded successfully for item \(item.id)")
//                    if let thumbnailImage = item.thumbnail, let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.8) {
//                        let thumbnailBlobName = UUID().uuidString + ".jpg"
//                        print("Uploading thumbnail for item \(item.id)...")
//                        self.uploadFileToAzureBlob(containerName: containerName!, blobName: thumbnailBlobName, fileData: thumbnailData, contentType: "image/jpeg") { success, thumbnailUrlString in
//                            if success, let thumbnailUrl = thumbnailUrlString {
//                                print("Thumbnail uploaded successfully for item \(item.id)")
//                                let updatedItem = PodItem(id: item.id, videoURL: URL(string: videoUrl)!, metadata: item.metadata, thumbnail: item.thumbnail)
//                                updatedItems.append(updatedItem)
//                            } else {
//                                print("Failed to upload thumbnail for item \(item.id)")
//                                uploadErrors.append("Failed to upload thumbnail for item \(item.id)")
//                            }
//                            dispatchGroup.leave()
//                        }
//                    } else {
//                        let updatedItem = PodItem(id: item.id, videoURL: URL(string: videoUrl)!, metadata: item.metadata, thumbnail: nil)
//                        updatedItems.append(updatedItem)
//                        dispatchGroup.leave()
//                    }
//                } else {
//                    print("Failed to upload video for item \(item.id)")
//                    uploadErrors.append("Failed to upload video for item \(item.id)")
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
            let videoBlobName = UUID().uuidString + ".mp4"
            guard let videoData = try? Data(contentsOf: item.videoURL) else {
                print("Failed to load video data for URL: \(item.videoURL)")
                uploadErrors.append("Failed to load video data for URL: \(item.videoURL)")
                dispatchGroup.leave()
                return
            }

            print("Uploading video for item \(item.id)...")
            uploadFileToAzureBlob(containerName: containerName, blobName: videoBlobName, fileData: videoData, contentType: "video/mp4") { success, videoUrlString in
                guard success, let videoUrl = videoUrlString else {
                    print("Failed to upload video for item \(item.id)")
                    uploadErrors.append("Failed to upload video for item \(item.id)")
                    dispatchGroup.leave()
                    return
                }

                print("Video uploaded successfully for item \(item.id)")
                if let thumbnailImage = item.thumbnail, let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.8) {
                    let thumbnailBlobName = UUID().uuidString + ".jpg"
                    print("Uploading thumbnail for item \(item.id)...")
                    self.uploadFileToAzureBlob(containerName: containerName, blobName: thumbnailBlobName, fileData: thumbnailData, contentType: "image/jpeg") { success, thumbnailUrlString in
                        guard success, let thumbnailUrl = thumbnailUrlString else {
                            print("Failed to upload thumbnail for item \(item.id)")
                            uploadErrors.append("Failed to upload thumbnail for item \(item.id)")
                            dispatchGroup.leave()
                            return
                        }

                        print("Thumbnail uploaded successfully for item \(item.id)")
                        let updatedItem = PodItem(id: item.id, videoURL: URL(string: videoUrl)!, metadata: item.metadata, thumbnail: nil, thumbnailURL: URL(string: thumbnailUrl))
                        updatedItems.append(updatedItem)
                        dispatchGroup.leave()
                    }
                } else {
                    let updatedItem = PodItem(id: item.id, videoURL: URL(string: videoUrl)!, metadata: item.metadata, thumbnail: nil, thumbnailURL: nil)
                    updatedItems.append(updatedItem)
                    dispatchGroup.leave()
                }
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
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let itemsForBody = items.map { item -> [String: Any] in
            var itemDict: [String: Any] = [
                "videoURL": item.videoURL.absoluteString,
                "label": item.metadata
            ]
            if let thumbnailURL = item.thumbnailURL {
                itemDict["thumbnail"] = thumbnailURL.absoluteString
            }
            return itemDict
        }

        let body: [String: Any] = [
            "title": podTitle,
            "items": itemsForBody,
            "email": email
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(false, "Failed to encode request body")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                completion(false, "Network error: \(error!.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    completion(true, nil)
                } else {
                    var errorMessage = "Server returned status code: \(httpResponse.statusCode)"
                    if let data = data, let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let message = jsonResponse["error"] as? String {
                        errorMessage = message
                    }
                    completion(false, errorMessage)
                }
            } else {
                completion(false, "No response from server")
            }
        }.resume()
    }



//    func sendPodCreationRequest(podTitle: String, items: [PodItem], email: String, completion: @escaping (Bool, String?) -> Void) {
//        guard let url = URL(string: "\(baseUrl)/create-pod/") else {
//            completion(false, "Invalid URL")
//            return
//        }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
////        request.addValue("Bearer YOUR_ACCESS_TOKEN", forHTTPHeaderField: "Authorization") // Include authorization header
//
//        let itemsForBody = items.map { item -> [String: Any] in
//            let itemDict: [String: Any] = ["videoURL": item.videoURL.absoluteString, "label": item.metadata, "thumbnail":item.thumbnail]
//            // Include thumbnail if necessary. This example skips thumbnail data for simplicity.
//            return itemDict
//        }
//
//        let body: [String: Any] = [
//            "title": podTitle,
//            "items": itemsForBody,
//            "email": email
//        ]
//
//        do {
//            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
//        } catch {
//            completion(false, "Failed to encode request body")
//            return
//        }
//
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            guard error == nil else {
//                completion(false, "Network error: \(error!.localizedDescription)")
//                return
//            }
//
//            if let httpResponse = response as? HTTPURLResponse {
//                if httpResponse.statusCode == 201 {
//                    // Pod created successfully
//                    completion(true, nil)
//                } else {
//                    // Handle errors
//                    var errorMessage = "Server returned status code: \(httpResponse.statusCode)"
//                    if let data = data, let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let message = jsonResponse["error"] as? String {
//                        errorMessage = message
//                    }
//                    completion(false, errorMessage)
//                }
//            } else {
//                completion(false, "No response from server")
//            }
//        }.resume()
//    }

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

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileData.count)", forHTTPHeaderField: "Content-Length")
        // Set the x-ms-blob-type header to BlockBlob
        request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
        request.httpBody = fileData

        // Logging request details
        print("Sending request to URL: \(url.absoluteString)")
        print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        if let requestBody = request.httpBody, let _ = String(data: requestBody, encoding: .utf8) {
            print("Request body size: \(requestBody.count) bytes")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network error
            if let error = error {
                print("Network error during upload to Azure Blob Storage: \(error.localizedDescription)")
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }

            // Handle HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                print("Response headers: \(httpResponse.allHeaderFields)")

                // Check for non-success status codes
                if httpResponse.statusCode != 201 {
                    let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "N/A"
                    print("Server returned response: \(responseBody)")

                    completion(false, "Server returned status code: \(httpResponse.statusCode)")
                } else {
                    let blobUrl = "https://\(accountName).blob.core.windows.net/\(containerName)/\(blobName)"
                    print("Upload successful to Azure Blob Storage: \(blobUrl)")
                    completion(true, blobUrl)
                }
            } else {
                print("No response from server during upload to Azure Blob Storage")
                completion(false, "No response from server")
            }
        }.resume()
    }
    
//    func fetchPodsForUser(email: String, completion: @escaping (Bool, [Pod]?, String?) -> Void) {
//        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
//        guard let url = URL(string: "\(NetworkManager().baseUrl)/get-user-pods/\(encodedEmail)") else {
//            completion(false, nil, "Invalid URL")
//            return
//        }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "GET"
//        // Add headers if needed, e.g., Authorization
//        
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            guard let data = data, error == nil else {
//                completion(false, nil, "Network request failed")
//                return
//            }
//            
//            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
//                do {
//                    let podResponse = try JSONDecoder().decode(PodResponse.self, from: data)
//                    // Use the custom initializer for Pod which was added as an extension.
//                    let pods = podResponse.pods.map { Pod(from: $0) }
//                    completion(true, pods, nil)
//                } catch {
//                    // Attempt to print the raw JSON string for debugging
//                    if let rawJSONString = String(data: data, encoding: .utf8) {
//                        print("Raw JSON string: \(rawJSONString)")
//                    }
//                    print("Decoding error: \(error)")
//                    let detailedError = (error as? DecodingError).flatMap { decodingError -> String in
//                        switch decodingError {
//                        case .dataCorrupted(let context):
//                            return "Data corrupted: \(context)"
//                        case .keyNotFound(let key, let context):
//                            return "Key '\(key.stringValue)' not found: \(context)"
//                        case .typeMismatch(let type, let context):
//                            return "Type '\(type)' mismatch: \(context)"
//                        case .valueNotFound(let type, let context):
//                            return "Value of type '\(type)' not found: \(context)"
//                        @unknown default:
//                            return "Unknown decoding error"
//                        }
//                    } ?? "Failed to decode pods"
//                    completion(false, nil, detailedError)
//                }
//            } else {
//                // Handling non-200 HTTP responses
//                if let httpResponse = response as? HTTPURLResponse {
//                    completion(false, nil, "Failed to fetch pods with HTTP status code: \(httpResponse.statusCode)")
//                } else {
//                    completion(false, nil, "Failed to fetch pods")
//                }
//            }
//        }.resume()
//    }

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


}
