import SwiftUI
import AuthenticationServices  // For Apple Sign In
import GoogleSignIn


struct LandingView: View {
    // Background color as specified
    let backgroundColor = Color(red: 70/255, green: 87/255, blue: 245/255)
    @Binding var isAuthenticated: Bool
    @State private var showSignupView = false
    @EnvironmentObject var viewModel: OnboardingViewModel

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
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { request in
                                // Configure the request here.
                            },
                            onCompletion: { result in
                                // Handle the authorization result.
                                // Update isAuthenticated as needed
                            }
                        )
                        .frame(height: 44)
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
                    .padding(.vertical, 40) // Vertical padding inside the card
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
//            guard let clientID = Bundle.main.object(forInfoDictionaryKey: ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"]) as String else {
//                fatalError("Missing CLIENT_ID in Info.plist")
//            }
        
        guard let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] else {
            print("Environment variables for GOOGLE_CLIENT_ID are not set.")
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
                
                NetworkManager().sendTokenToBackend(idToken: idToken) { success, message, isNewUser in
                             if success {
                                 print("Token sent successfully")
                                 if isNewUser {
                                     // Update view model and navigate to welcome view
                                     UserDefaults.standard.set(true, forKey: "isAuthenticated")
                                     UserDefaults.standard.set(result.user.profile?.email, forKey: "userEmail")
                                    viewModel.email = result.user.profile?.email ?? ""
                                    viewModel.currentStep = .welcome
                                                   } else {
                                                       viewModel.currentStep = .landing
                                                       UserDefaults.standard.set(true, forKey: "isAuthenticated")
                                                       UserDefaults.standard.set(result.user.profile?.email, forKey: "userEmail")
                                                      viewModel.email = result.user.profile?.email ?? ""
                                                       self.isAuthenticated = true
                                                   }
                                 
                             } else {
                                 print("Failed to send token: \(message ?? "Unknown error")")
                             }
                         }
            }
        }
        
        func getRootViewController() -> UIViewController? {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return nil
            }
            return rootViewController
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
