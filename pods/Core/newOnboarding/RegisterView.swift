import SwiftUI
import AuthenticationServices
import GoogleSignIn
import CryptoKit

struct RegisterView: View {
    private let backgroundColor = Color.black

    @Binding var isAuthenticated: Bool
    @EnvironmentObject private var viewModel: OnboardingViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var currentNonce: String?
    @State private var showEmailSignup = false
    @State private var showGeneratingProgram = false
    @State private var isNewUserSignup = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 24) {
                        Image("logo-bkv2")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)

                        VStack(spacing: 12) {
                            Text("Your personalized plan is ready.")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)

                            Text("Sign up below to save your profile and get started.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 40)
                        }
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        SignInWithAppleButton(
                            .signUp,
                            onRequest: configureAppleSignIn,
                            onCompletion: handleAppleSignIn
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(36)

                        Button(action: handleGoogleSignIn) {
                            HStack {
                                Image("gg")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 20)

                                Text("Sign up with Google")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(AuthenticationButtonStyle())

                        Button(action: {
                            showEmailSignup = true
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 18))
                                Text("Sign up with Email")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(AuthenticationButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                    .padding(.bottom, 72)
                    .background(Color.white.cornerRadius(25, corners: [.topLeft, .topRight]))
                }
                .edgesIgnoringSafeArea(.bottom)

                NavigationLink(isActive: $showEmailSignup) {
                    SignupView(isAuthenticated: $isAuthenticated)
                        .environmentObject(viewModel)
                } label: {
                    EmptyView()
                }
                .hidden()
            }
            .preferredColorScheme(.light)
            .toolbar(.hidden, for: .navigationBar)
        }
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $showGeneratingProgram) {
            GeneratingProgramView(isPresented: $showGeneratingProgram) {
                // Program generation complete - show paywall for new users
                showGeneratingProgram = false
                if isNewUserSignup {
                    viewModel.showProOnboarding = true
                }
                // Navigate to welcome/paywall
                completeOnboarding()
            }
            .environmentObject(viewModel)
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
        UserDefaults.standard.set(false, forKey: "onboardingInProgress")
        UserDefaults.standard.synchronize()
        isAuthenticated = true
        NotificationCenter.default.post(name: Notification.Name("AuthenticationCompleted"), object: nil)
    }

    private func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("⚠️ Apple Sign-In credential incomplete")
                return
            }

            if let credentialEmail = appleIDCredential.email, !credentialEmail.isEmpty {
                viewModel.email = credentialEmail
            }

            let onboardingPayload = viewModel.signupOnboardingPayload()
            if onboardingPayload == nil {
                print("⚠️ No onboarding payload available, sending Apple signup without onboarding data")
            }
            NetworkManager().completeAppleSignup(
                idToken: idTokenString,
                nonce: nonce,
                onboarding: onboardingPayload,
                name: viewModel.name
            ) { success, message, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser in
                if success {
                    DispatchQueue.main.async {
                        if let resolvedEmail = email, !resolvedEmail.isEmpty {
                            viewModel.email = resolvedEmail
                        }

                        let onboardingName = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let backendName = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let resolvedName = onboardingName.isEmpty ? backendName : onboardingName

                        viewModel.username = resolvedName
                        viewModel.name = resolvedName

                        let derivedInitial = resolvedName.isEmpty ? "" : String(resolvedName.prefix(1)).uppercased()
                        let resolvedInitial = derivedInitial.isEmpty ? (profileInitial ?? "") : derivedInitial
                        viewModel.profileInitial = resolvedInitial

                        viewModel.profileColor = profileColor ?? ""
                        UserDefaults.standard.set(viewModel.email, forKey: "userEmail")
                        UserDefaults.standard.set(resolvedName, forKey: "userName")
                        UserDefaults.standard.set(resolvedInitial, forKey: "profileInitial")
                        UserDefaults.standard.synchronize()

                        if isNewUser {
                            // New user: show loading screen while generating program
                            self.isNewUserSignup = true
                            self.showGeneratingProgram = true
                        } else {
                            // Existing user: complete authentication
                            self.isAuthenticated = true
                            UserDefaults.standard.set(true, forKey: "isAuthenticated")
                            UserDefaults.standard.synchronize()
                            NotificationCenter.default.post(name: Notification.Name("AuthenticationCompleted"), object: nil)
                        }
                    }
                } else {
                    print("⚠️ Apple Sign-In backend failure: \(message ?? "Unknown error")")
                }
            }
        case .failure(let error):
            print("⚠️ Apple Sign-In failed: \(error.localizedDescription)")
        }
    }

    private func handleGoogleSignIn() {
        guard let clientID = ConfigurationManager.shared.getValue(forKey: "GOOGLE_CLIENT_ID") as? String else {
            print("⚠️ Missing Google client ID")
            return
        }

        let signInConfig = GIDConfiguration(clientID: clientID)

        guard let presentingViewController = getRootViewController() else {
            print("⚠️ Missing presenting view controller")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, hint: nil, additionalScopes: ["profile"]) { signInResult, error in
            if let error = error {
                print("⚠️ Google Sign-In error: \(error.localizedDescription)")
                return
            }

            guard let result = signInResult,
                  let idToken = result.user.idToken?.tokenString else {
                print("⚠️ Google Sign-In missing token")
                return
            }

            if let googleEmail = result.user.profile?.email, !googleEmail.isEmpty {
                viewModel.email = googleEmail
            }

            let onboardingPayload = viewModel.signupOnboardingPayload()
            if onboardingPayload == nil {
                print("⚠️ No onboarding payload available, sending Google signup without onboarding data")
            }
            NetworkManager().completeGoogleSignup(
                idToken: idToken,
                onboarding: onboardingPayload,
                name: viewModel.name
            ) { success, message, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser in
                if success {
                    DispatchQueue.main.async {
                        if let resolvedEmail = email, !resolvedEmail.isEmpty {
                            viewModel.email = resolvedEmail
                        }

                        let onboardingName = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let backendName = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let resolvedName = onboardingName.isEmpty ? backendName : onboardingName

                        viewModel.username = resolvedName
                        viewModel.name = resolvedName

                        let derivedInitial = resolvedName.isEmpty ? "" : String(resolvedName.prefix(1)).uppercased()
                        let resolvedInitial = derivedInitial.isEmpty ? (profileInitial ?? "") : derivedInitial
                        viewModel.profileInitial = resolvedInitial

                        viewModel.profileColor = profileColor ?? ""
                        UserDefaults.standard.set(viewModel.email, forKey: "userEmail")
                        UserDefaults.standard.set(resolvedName, forKey: "userName")
                        UserDefaults.standard.set(resolvedInitial, forKey: "profileInitial")
                        UserDefaults.standard.synchronize()

                        if isNewUser {
                            // New user: show loading screen while generating program
                            self.isNewUserSignup = true
                            self.showGeneratingProgram = true
                        } else {
                            // Existing user: complete authentication
                            self.isAuthenticated = true
                            UserDefaults.standard.set(true, forKey: "isAuthenticated")
                            UserDefaults.standard.synchronize()
                            NotificationCenter.default.post(name: Notification.Name("AuthenticationCompleted"), object: nil)
                        }
                    }
                } else {
                    print("⚠️ Google Sign-In backend failure: \(message ?? "Unknown error")")
                }
            }
        }
    }

    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
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

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView(isAuthenticated: .constant(false))
            .environmentObject(OnboardingViewModel())
    }
}
