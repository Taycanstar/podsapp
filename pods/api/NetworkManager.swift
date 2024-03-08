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
 

}
