import SwiftUI
import Combine
import Mixpanel

struct LoginView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil
    @Binding var isAuthenticated: Bool
    @State private var isLoading = false
    @State private var identifier: String = ""
    @State private var showForgotPassword = false

    var body: some View {
        
            NavigationView {
                ScrollView {
                    VStack {
                        topBar
                        formSection
                        Spacer(minLength: 20)
                        continueButton
                        Spacer()
                    }
                    
                    .padding(.bottom, 50)
                    .background(Color.white)
                }
                .navigationBarHidden(true)
                .background(Color.white)
               
            }
            .navigationBarBackButtonHidden(true)
            .background(Color.white)
       
      
//        .preferredColorScheme(.light)
    }

    private var topBar: some View {
        HStack {
            Button("Sign out") {
                viewModel.currentStep = .landing
            }
            .foregroundColor(Color(red: 35/255, green: 108/255, blue: 255/255))
            .padding()
            Spacer()
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome back")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.black)

            ZStack(alignment: .leading) {
                CustomTextField(placeholder: "Email or username", text: $identifier)
                    .autocapitalization(.none)
            }
                

            ZStack(alignment: .trailing) {

                CustomTextField(placeholder: "Password", text: $password, isSecure: true, showPassword: showPassword)

                Button(action: {
                    self.showPassword.toggle()
                }) {
                    Image(systemName: self.showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(Color(red: 35/255, green: 108/255, blue: 255/255))
                }
                .padding(.trailing, 15)
            }
            
            HStack {
                          Spacer()
                          Button(action: {
                              showForgotPassword = true
                          }) {
                              Text("Forgot Password?")
                                  .foregroundColor(Color(red: 35/255, green: 108/255, blue: 255/255))
                                  .font(.footnote)
                          }
                          .sheet(isPresented: $showForgotPassword) {
                              ForgotPasswordView(showForgotPassword: $showForgotPassword)
                          }
                      }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
      
        .padding(.horizontal)
    }

    private var continueButton: some View {
        Button(action: loginAction) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Continue")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.black)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.bottom, 50)
    }

    private func loginAction() {
        isLoading = true
            
        if identifier.isEmpty || identifier.contains(" ") {
            self.errorMessage = "Please enter a valid email address or username"
            isLoading = false
            return
        }

        if password.count < 8 {
            self.errorMessage = "Password must be at least 8 characters."
            isLoading = false
            return
        }

        authenticateUser()
        
    }
    private func authenticateUser() {
        isLoading = true
        NetworkManager().login(identifier: identifier, password: password) { success, error, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted in
            DispatchQueue.main.async {
                if success {
                    let userIdString = "\(userId ?? 0)"
                    self.isAuthenticated = true
                    UserDefaults.standard.set(true, forKey: "isAuthenticated")
                    UserDefaults.standard.set(userId, forKey: "userId")
                    self.viewModel.userId = userId
                    
                    // Always trust the server's onboarding status
                    let isOnboardingComplete = onboardingCompleted ?? false
                    
                    // Save both local and server onboarding status variables
                    self.viewModel.serverOnboardingCompleted = isOnboardingComplete
                    self.viewModel.onboardingCompleted = isOnboardingComplete
                    UserDefaults.standard.set(isOnboardingComplete, forKey: "onboardingCompleted")
                    UserDefaults.standard.set(isOnboardingComplete, forKey: "serverOnboardingCompleted")
                    
                    print("🔐 Login successful - Server onboarding completed: \(isOnboardingComplete)")
                    
                    if let email = email {
                        self.viewModel.email = email
                        UserDefaults.standard.set(email, forKey: "userEmail")
                        
                        // If onboarding is completed, save this email as the one who completed onboarding
                        if isOnboardingComplete {
                            UserDefaults.standard.set(email, forKey: "emailWithCompletedOnboarding")
                            print("📝 Saved \(email) as the email with completed onboarding")
                        }
                    }
                    
                    // Set onboarding flags appropriately
                    if !isOnboardingComplete {
                        // Onboarding is not complete, prepare to start/resume it
                        UserDefaults.standard.set(true, forKey: "onboardingInProgress")
                        self.viewModel.currentFlowStep = .gender
                        // Remove any saved completion email if onboarding is not complete
                        UserDefaults.standard.removeObject(forKey: "emailWithCompletedOnboarding")
                    } else {
                        // Onboarding is complete, make sure we're not in "inProgress" state
                        UserDefaults.standard.set(false, forKey: "onboardingInProgress")
                        // We can also remove any saved step if onboarding is complete
                        UserDefaults.standard.removeObject(forKey: "currentOnboardingStep")
                    }
                    
                    if let username = username {
                        self.viewModel.username = username
                        UserDefaults.standard.set(username, forKey: "username")
                    }
                    if let profileInitial = profileInitial {
                        self.viewModel.profileInitial = profileInitial
                        UserDefaults.standard.set(profileInitial, forKey: "profileInitial")
                    }
                    if let profileColor = profileColor {
                        self.viewModel.profileColor = profileColor
                        UserDefaults.standard.set(profileColor, forKey: "profileColor")
                    }
                    
                    self.viewModel.updateSubscriptionInfo(
                        status: subscriptionStatus,
                        plan: subscriptionPlan,
                        expiresAt: subscriptionExpiresAt,
                        renews: subscriptionRenews,
                        seats: subscriptionSeats,
                        canCreateNewTeam: nil
                    )
                    
                    // Force synchronize UserDefaults to ensure all changes are written
                    UserDefaults.standard.synchronize()

                    // Notify the app that authentication has completed
                    NotificationCenter.default.post(name: Notification.Name("AuthenticationCompleted"), object: nil)
                    
                    Mixpanel.mainInstance().identify(distinctId: userIdString)
                    Mixpanel.mainInstance().people.set(properties: [
                        "$email": viewModel.email,
                        "$name": viewModel.username
                    ])
                } else {
                    self.errorMessage = error ?? "Invalid credentials"
                }
                self.isLoading = false
            }
        }
    }

}



struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var showPassword: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color.gray.opacity(0.7)) // Adjust opacity for better visibility
//                    .padding(.leading, 10)
                    .padding()
            }
            if isSecure && !showPassword {
                SecureField("", text: $text)
                    .foregroundColor(.black)
                    .padding()
            } else {
                TextField("", text: $text)
                    .foregroundColor(.black)
                    .padding()
            }
        }
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray, lineWidth: 0.2)
        )
    }
}
