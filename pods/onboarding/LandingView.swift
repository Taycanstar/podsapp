import SwiftUI
import AuthenticationServices  // For Apple Sign In
import GoogleSignIn
import CryptoKit

struct LandingView: View {
    // Background color as specified
    let backgroundColor = Color(red: 70/255, green: 87/255, blue: 245/255)
    @Binding var isAuthenticated: Bool
    @State private var showSignupView = false
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var currentNonce: String?
    @State private var idTokenString: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    // Image centered on the screen
                    Image("clear-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200) // Adjust size as needed
                    Spacer()
                    
                    // Bottom card with buttons, corrected for padding and edge issues
                    VStack(spacing: 10) { // Increased spacing for visual appeal
//                        SignInWithAppleButton(
//                                                    .signIn,
//                                                    onRequest: configureAppleSignIn,
//                                                    onCompletion: handleAppleSignIn
//                                                )
//                        .frame(height: 44)
//                        .cornerRadius(10)
//                        
                        Button(action: {
                            // Handle Google sign-in
                            handleGoogleSignIn()
                        }) {
                            HStack {
                                Image("gg") // Make sure this image is in your assets
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 20) // Adjust based on your design needs
                                
                                Text("Sign in with Google")
                                    .foregroundColor(.black) // Set text color
                            }
                        }
                        .buttonStyle(AuthenticationButtonStyle())
                        
                        
                        Button(action: {

                            viewModel.currentStep = .signup
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill") // Apple's envelope icon
                                    .font(.system(size: 18)) // Adjust the size as needed
                                
                                Text("Sign up with Email")
                                    .foregroundColor(.black) // Set text color
                            }
                        }

                                   
                        .buttonStyle(AuthenticationButtonStyle())
                        
                        
                        
                        Button("Login") {
                            // Handle Login
                            viewModel.currentStep = .login
                        }
                        .buttonStyle(AuthenticationButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .padding(.top, 25)
                    .background(Color.white.cornerRadius(25, corners: [.topLeft, .topRight]))
                    //                .shadow(radius: 10)
                }
                .edgesIgnoringSafeArea(.all)
                
            }
            .padding(.bottom, 1)
            .preferredColorScheme(.light)
            .ignoresSafeArea()
        }
    }
    func handleGoogleSignIn() {
        
//        guard let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] else {
//            print("Environment variables for GOOGLE_CLIENT_ID are not set.")
//            return
//        }
        
        guard let clientID = ConfigurationManager.shared.getValue(forKey: "GOOGLE_CLIENT_ID") as? String
                       else {
                    print("Missing configuration values for google client")
                  
                    return
                }
            
            let signInConfig = GIDConfiguration(clientID: clientID)
            
            guard let presentingViewController = getRootViewController() else {
                fatalError("Failed to retrieve root view controller.")
            }
            
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController,  hint: nil,  additionalScopes: ["profile", "https://www.googleapis.com/auth/user.birthday.read"]) { signInResult, error in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                
                guard let result = signInResult else { return }
                
                guard let idToken = result.user.idToken?.tokenString else {
                    print("Error: No ID token found")
                    return
                }
                
                NetworkManager().sendTokenToBackend(idToken: idToken) { success, message, isNewUser, email, username in
                             if success {
                                 print("Token sent successfully")
                                 if isNewUser {
                                     // Update view model and navigate to welcome view
                                     UserDefaults.standard.set(true, forKey: "isAuthenticated")
                                     UserDefaults.standard.set(result.user.profile?.email, forKey: "userEmail")
                                     UserDefaults.standard.set(username, forKey: "username")
                                    viewModel.email = result.user.profile?.email ?? ""
                                     viewModel.username = username ?? ""
                                    
                                    viewModel.currentStep = .welcome
                                                   } else {
                                                       viewModel.currentStep = .landing
                                                       UserDefaults.standard.set(true, forKey: "isAuthenticated")
                                                       UserDefaults.standard.set(result.user.profile?.email, forKey: "userEmail")
                                                      viewModel.email = result.user.profile?.email ?? ""
                                                       UserDefaults.standard.set(result.user.profile?.email, forKey: "username")
                                                       viewModel.username = username ?? ""
                                                       self.isAuthenticated = true
                                                   }
                                 
                             } else {
                                 print("Failed to send token: \(message ?? "Unknown error")")
                             }
                         }
            }
        }
    
    func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
          let nonce = randomNonceString()
          currentNonce = nonce
          request.requestedScopes = [.fullName, .email]
          request.nonce = sha256(nonce)
      }

    
//    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
//        switch result {
//        case .success(let authResults):
//            guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else { return }
//            guard currentNonce != nil else {
//                fatalError("Invalid state: a login callback was received, but no login request was sent.")
//            }
//            guard let appleIDToken = appleIDCredential.identityToken else {
//                print("Unable to fetch identity token")
//                return
//            }
//            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
//                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
//                return
//            }
//
//            NetworkManager().sendAppleTokenToBackend(idToken: idTokenString) { success, message, isNewUser in
//                if success {
//                    DispatchQueue.main.async {
//                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
//                        UserDefaults.standard.set(appleIDCredential.email ?? "", forKey: "userEmail")
//                        viewModel.email = appleIDCredential.email ?? ""
//                        viewModel.currentStep = isNewUser ? .welcome : .landing
//                        self.isAuthenticated = true
//                    }
//                } else {
//                    print("Failed to send token: \(message ?? "Unknown error")")
//                }
//            }
//
//        case .failure(let error):
//            print("Authorization failed: \(error.localizedDescription)")
//        }
//    }
    
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else { return }
            guard let nonce = currentNonce else {
                fatalError("Invalid state: a login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }

            sendAppleTokenToBackend(idToken: idTokenString)
        case .failure(let error):
            print("Authorization failed: \(error.localizedDescription)")
        }
    }
    
    func sendAppleTokenToBackend(idToken: String) {
        guard let url = URL(string: "https://humuli-2b3070583cda.herokuapp.com/apple-login/") else {
            print("Invalid URL")
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
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    print("No response from server")
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
                        // Handle success
                    }
                } else {
                    DispatchQueue.main.async {
                        print("Invalid data from server")
                    }
                }
            } else {
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let errorMessage = json["error"] as? String ?? "Unknown error"
                    let errorDescription = json["error_description"] as? String ?? "No description"
                    DispatchQueue.main.async {
                        print("Request failed with statusCode: \(httpResponse.statusCode), error: \(errorMessage), description: \(errorDescription)")
                    }
                } else {
                    DispatchQueue.main.async {
                        print("Request failed with statusCode: \(httpResponse.statusCode)")
                    }
                }
            }
        }.resume()
    }
    
//    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
//          switch result {
//          case .success(let authResults):
//              guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else { return }
//              guard currentNonce != nil else {
//                  fatalError("Invalid state: a login callback was received, but no login request was sent.")
//              }
//              guard let appleIDToken = appleIDCredential.identityToken else {
//                  print("Unable to fetch identity token")
//                  return
//              }
//              guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
//                  print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
//                  return
//              }
//
//              // Store the token for verification
//              self.idTokenString = idTokenString
//              print(idTokenString, "token received")
//
//          case .failure(let error):
//              print("Authorization failed: \(error.localizedDescription)")
//          }
//      }
    
    



        
        func getRootViewController() -> UIViewController? {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return nil
            }
            return rootViewController
        }
    
    // Helper functions for nonce and SHA256
      
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()

        return hashString
    }

    private func randomNonceString(length: Int = 32) -> String {
            precondition(length > 0)
            let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
            var result = ""
            var remainingLength = length

            while remainingLength > 0 {
                let randoms: [UInt8] = (0..<16).map { _ in
                    var random: UInt8 = 0
                    let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                    if errorCode != errSecSuccess {
                        fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                    }
                    return random
                }

                randoms.forEach { random in
                    if remainingLength == 0 {
                        return
                    }

                    if random < charset.count {
                        result.append(charset[Int(random)])
                        remainingLength -= 1
                    }
                }
            }

            return result
        }
        
    
}

// Button style modifier for uniform styling
struct AuthenticationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .foregroundColor(.black)
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
    }
}

// Allows corner-specific rounding
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// Add this struct to enable specific corner rounding
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct LandingView_Previews: PreviewProvider {
    static var previews: some View {
        LandingView(isAuthenticated: .constant(false))
    }
}

