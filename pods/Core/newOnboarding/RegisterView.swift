import SwiftUI
import AuthenticationServices
import GoogleSignIn
import CryptoKit

struct RegisterView: View {
    private let backgroundColor = Color.black

    @Binding var isAuthenticated: Bool
    @EnvironmentObject private var viewModel: OnboardingViewModel
    @State private var currentNonce: String?
    @State private var showEmailSignup = false

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
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 56)
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
                    SignupView()
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

            let networkManager = NetworkManager()
            networkManager.sendTokenToBackend(idToken: idTokenString) { success, message, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser in
                if success {
                    DispatchQueue.main.async {
                        self.isAuthenticated = true
                        viewModel.email = email ?? ""
                        viewModel.username = username ?? ""
                        viewModel.profileInitial = profileInitial ?? ""
                        viewModel.profileColor = profileColor ?? ""
                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
                        UserDefaults.standard.set(email, forKey: "userEmail")
                        UserDefaults.standard.synchronize()
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

            NetworkManager().sendTokenToBackend(idToken: idToken) { success, message, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser in
                if success {
                    DispatchQueue.main.async {
                        self.isAuthenticated = true
                        viewModel.email = email ?? ""
                        viewModel.username = username ?? ""
                        viewModel.profileInitial = profileInitial ?? ""
                        viewModel.profileColor = profileColor ?? ""
                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
                        UserDefaults.standard.set(email, forKey: "userEmail")
                        UserDefaults.standard.synchronize()
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
