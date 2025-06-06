import SwiftUI
import AuthenticationServices  // For Apple Sign In
import GoogleSignIn
import CryptoKit
import Mixpanel

struct LandingView: View {
    // Background color changed to black
    let backgroundColor = Color.black
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
                    Image("logo-bkv2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100) // Adjust size as needed
                    Spacer()
                    
                    // Bottom card with buttons, corrected for padding and edge issues
                    VStack(spacing: 10) { // Increased spacing for visual appeal
                        SignInWithAppleButton(
                                                    .continue,
                                                    onRequest: configureAppleSignIn,
                                                    onCompletion: handleAppleSignIn

                                                )
                                                
                        .frame(height: 50)
                        .cornerRadius(10)
                        
                        Button(action: {
                            // Handle Google sign-in
                            handleGoogleSignIn()
                        }) {
                            HStack {
                                Image("gg") // Make sure this image is in your assets
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 20) // Adjust based on your design needs
                                
                                Text("Continue with Google")
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
                                
                                Text("Continue with Email")
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
        guard let clientID = ConfigurationManager.shared.getValue(forKey: "GOOGLE_CLIENT_ID") as? String else {
            print("Missing configuration values for google client")
            return
        }
        
        let signInConfig = GIDConfiguration(clientID: clientID)
        
        guard let presentingViewController = getRootViewController() else {
            fatalError("Failed to retrieve root view controller.")
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, hint: nil, additionalScopes: ["profile"]) { signInResult, error in
            if let error = error {
                print("Google Sign-In error: \(error.localizedDescription)")
                return
            }
            
            guard let result = signInResult else {
                print("No sign-in result")
                return
            }
            
            guard let idToken = result.user.idToken?.tokenString else {
                print("Error: No ID token found")
                return
            }

            NetworkManager().sendTokenToBackend(idToken: idToken) { success, message, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser in
                if success {
                    print("Token sent successfully")
                    let userIdString = String(userId ?? 0)

                    DispatchQueue.main.async {
                        // Save auth state
                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
                        UserDefaults.standard.set(email, forKey: "userEmail")
                        UserDefaults.standard.set(username, forKey: "username")
                        UserDefaults.standard.set(userId, forKey: "userId")
                        
                        // Always trust the server's onboarding status
                        let isOnboardingComplete = onboardingCompleted ?? false
                        
                        // Save both local and server onboarding status variables
                        viewModel.onboardingCompleted = isOnboardingComplete
                        viewModel.serverOnboardingCompleted = isOnboardingComplete
                        UserDefaults.standard.set(isOnboardingComplete, forKey: "onboardingCompleted")
                        UserDefaults.standard.set(isOnboardingComplete, forKey: "serverOnboardingCompleted")
                        
                        print("🔑 Google Auth - Onboarding completed: \(isOnboardingComplete)")
                        
                        // If this is a new user, make sure to reset ALL onboarding UserDefaults
                        if isNewUser {
                            print("👤 New Google user detected - resetting onboarding state")
                            UserDefaults.standard.removeObject(forKey: "currentOnboardingStep")
                            UserDefaults.standard.set(0, forKey: "onboardingFlowStep")
                            UserDefaults.standard.set(false, forKey: "onboardingCompleted")
                            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
                            UserDefaults.standard.removeObject(forKey: "emailWithCompletedOnboarding")
                            viewModel.currentFlowStep = .gender
                        }
                        
                        // If user has email and onboarding is completed, save their email
                        if let email = email, !email.isEmpty, isOnboardingComplete {
                            UserDefaults.standard.set(email, forKey: "emailWithCompletedOnboarding")
                            print("📝 Saved \(email) as the email with completed onboarding")
                        }
                        
                        // Set appropriate onboarding flags based on completion status
                        if !isOnboardingComplete {
                            // Onboarding is not complete, prepare to show it
                            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
                            UserDefaults.standard.removeObject(forKey: "emailWithCompletedOnboarding")
                            viewModel.currentFlowStep = .gender
                        } else {
                            // Onboarding is complete, make sure we're not in "inProgress" state
                            UserDefaults.standard.set(false, forKey: "onboardingInProgress")
                            // Also remove any saved step if onboarding is complete
                            UserDefaults.standard.removeObject(forKey: "currentOnboardingStep")
                        }

                        // Update view model
                        viewModel.email = email ?? ""
                        viewModel.username = username ?? ""
                        viewModel.userId = userId ?? 0
                        
                        if let profileInitial = profileInitial {
                            viewModel.profileInitial = profileInitial
                            UserDefaults.standard.set(profileInitial, forKey: "profileInitial")
                        }
                        if let profileColor = profileColor {
                            viewModel.profileColor = profileColor
                            UserDefaults.standard.set(profileColor, forKey: "profileColor")
                        }

                        // Update subscription info
                        viewModel.updateSubscriptionInfo(
                            status: subscriptionStatus ?? "none",
                            plan: subscriptionPlan,
                            expiresAt: subscriptionExpiresAt,
                            renews: subscriptionRenews,
                            seats: subscriptionSeats,
                            canCreateNewTeam: nil
                        )

                        // Force synchronize to ensure all changes are written immediately
                        UserDefaults.standard.synchronize()

                        // Mixpanel tracking
                        Mixpanel.mainInstance().identify(distinctId: userIdString)
                        Mixpanel.mainInstance().people.set(properties: [
                            "$email": viewModel.email,
                            "$name": viewModel.username
                        ])
                        
                        if isOnboardingComplete {
                            // If onboarding is already completed, authenticate directly
                            self.isAuthenticated = true
                        } else {
                            // If onboarding is not completed, show the onboarding flow right away
                            viewModel.isShowingOnboarding = true
                            self.isAuthenticated = true
                        }
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
        let hashedNonce = sha256(nonce)
        request.requestedScopes = [.fullName, .email]  // Request email scope
        request.nonce = hashedNonce

        // Request a private email relay
        request.requestedScopes?.append(.email)

        print("Generated nonce: \(nonce)")
        print("SHA256 hashed nonce: \(hashedNonce)")
    }
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8),
                  let nonce = currentNonce else {
                print("Unable to fetch identity token or nonce")
                return
            }
            
            print("Sending original nonce to backend: \(nonce)")
            
            NetworkManager().sendAppleTokenToBackend(idToken: idTokenString, nonce: nonce) { success, message, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser in
                if success {
                    let userIdString = String(userId ?? 0)

                    DispatchQueue.main.async {
                        // Save auth state
                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
                        UserDefaults.standard.set(email, forKey: "userEmail")
                        UserDefaults.standard.set(username, forKey: "username")
                        UserDefaults.standard.set(userId, forKey: "userId")
                        
                        // Always trust the server's onboarding status
                        let isOnboardingComplete = onboardingCompleted ?? false
                        
                        // Save both local and server onboarding status variables
                        viewModel.onboardingCompleted = isOnboardingComplete
                        viewModel.serverOnboardingCompleted = isOnboardingComplete
                        UserDefaults.standard.set(isOnboardingComplete, forKey: "onboardingCompleted")
                        UserDefaults.standard.set(isOnboardingComplete, forKey: "serverOnboardingCompleted")
                        
                        print("🔑 Apple Auth - Onboarding completed: \(isOnboardingComplete)")
                        
                        // If this is a new user, make sure to reset ALL onboarding UserDefaults
                        if isNewUser {
                            print("👤 New Apple user detected - resetting onboarding state")
                            UserDefaults.standard.removeObject(forKey: "currentOnboardingStep")
                            UserDefaults.standard.set(0, forKey: "onboardingFlowStep")
                            UserDefaults.standard.set(false, forKey: "onboardingCompleted")
                            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
                            UserDefaults.standard.removeObject(forKey: "emailWithCompletedOnboarding")
                            viewModel.currentFlowStep = .gender
                        }
                        
                        // If user has email and onboarding is completed, save their email
                        if let email = email, !email.isEmpty, isOnboardingComplete {
                            UserDefaults.standard.set(email, forKey: "emailWithCompletedOnboarding")
                            print("📝 Saved \(email) as the email with completed onboarding")
                        }
                        
                        // Set appropriate onboarding flags based on completion status
                        if !isOnboardingComplete {
                            // Onboarding is not complete, prepare to show it
                            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
                            UserDefaults.standard.removeObject(forKey: "emailWithCompletedOnboarding")
                            viewModel.currentFlowStep = .gender
                        } else {
                            // Onboarding is complete, make sure we're not in "inProgress" state
                            UserDefaults.standard.set(false, forKey: "onboardingInProgress")
                            // Also remove any saved step if onboarding is complete
                            UserDefaults.standard.removeObject(forKey: "currentOnboardingStep")
                        }

                        // Update view model
                        viewModel.email = email ?? ""
                        viewModel.username = username ?? ""
                        viewModel.userId = userId ?? 0
                        
                        if let profileInitial = profileInitial {
                            viewModel.profileInitial = profileInitial
                            UserDefaults.standard.set(profileInitial, forKey: "profileInitial")
                        }
                        if let profileColor = profileColor {
                            viewModel.profileColor = profileColor
                            UserDefaults.standard.set(profileColor, forKey: "profileColor")
                        }

                        // Update subscription info
                        viewModel.updateSubscriptionInfo(
                            status: subscriptionStatus ?? "none",
                            plan: subscriptionPlan,
                            expiresAt: subscriptionExpiresAt,
                            renews: subscriptionRenews,
                            seats: subscriptionSeats,
                            canCreateNewTeam: nil
                        )
                        
                        // Force synchronize to ensure all changes are written immediately
                        UserDefaults.standard.synchronize()

                        // Mixpanel tracking
                        Mixpanel.mainInstance().identify(distinctId: userIdString)
                        Mixpanel.mainInstance().people.set(properties: [
                            "$email": viewModel.email,
                            "$name": viewModel.username
                        ])

                        if isOnboardingComplete {
                            // If onboarding is already completed, authenticate directly
                            self.isAuthenticated = true
                        } else {
                            // If onboarding is not completed, show the onboarding flow right away
                            viewModel.isShowingOnboarding = true
                            self.isAuthenticated = true
                        }
                    }
                } else {
                    print("Apple Sign In failed: \(message ?? "Unknown error")")
                }
            }
        case .failure(let error):
            print("Authorization failed: \(error.localizedDescription)")
        }
    }


        func getRootViewController() -> UIViewController? {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return nil
            }
            return rootViewController
        }
    
    // Helper functions for nonce and SHA256
      
    private func randomNonceString(length: Int = 32) -> String {
            precondition(length > 0)
            let charset: [Character] =
                Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
            var result = ""
            var remainingLength = length

            while remainingLength > 0 {
                let randoms: [UInt8] = (0 ..< 16).map { _ in
                    var random: UInt8 = 0
                    let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                    if errorCode != errSecSuccess {
                        fatalError(
                            "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
                        )
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

        private func sha256(_ input: String) -> String {
            let inputData = Data(input.utf8)
            let hashedData = SHA256.hash(data: inputData)
            let hashString = hashedData.compactMap {
                String(format: "%02x", $0)
            }.joined()

            return hashString
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

