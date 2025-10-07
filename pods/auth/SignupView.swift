import SwiftUI
import Foundation

struct SignupView: View {
    @Binding var isAuthenticated: Bool
    @State private var password: String = ""
    @State private var email: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    // Debouncer for email and password input
    private var emailDebouncer = Debouncer(delay: 0.5)
    private var passwordDebouncer = Debouncer(delay: 0.5)

    init(isAuthenticated: Binding<Bool>) {
        self._isAuthenticated = isAuthenticated
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    topBar
                    logo
                    formSection
                    Spacer(minLength: 20)
                    continueButton
                    Spacer()
                }
                .background(Color.white)
                .padding(.bottom, 50)
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.white)
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

    private var logo: some View {
        HStack {
            Spacer()
            Image("logo-wtv2")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
            Spacer()
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Create your Humuli account")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.black)
            ZStack(alignment: .leading) {
                CustomTextField(placeholder: "Email", text: $email)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                
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
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
    }

    private var continueButton: some View {
        Button(action: validateAndSignUp) {
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



    private func validateAndSignUp() {
        isLoading = true
        // Directly validate email and password to reflect the most current input
        let currentEmail = self.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPassword = self.password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if currentEmail.isEmpty || !currentEmail.contains("@") {
            self.errorMessage = "Please enter a valid email address."
            isLoading = false
            return
        } else if currentPassword.count < 8 {
            self.errorMessage = "Password must be at least 8 characters."
            isLoading = false
            return
        } else {
            self.errorMessage = nil
            let networkManager = NetworkManager()
            let onboardingPayload = viewModel.signupOnboardingPayload()
            let trimmedName = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)

            networkManager.completeEmailSignup(
                email: currentEmail,
                password: currentPassword,
                name: trimmedName.isEmpty ? nil : trimmedName,
                onboarding: onboardingPayload
            ) { success, message, email, username, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt, subscriptionRenews, subscriptionSeats, userId, onboardingCompleted, isNewUser in
                DispatchQueue.main.async {
                    self.isLoading = false

                    guard success else {
                        self.errorMessage = message ?? "Signup failed"
                        return
                    }

                    self.errorMessage = nil

                    let isOnboardingComplete = onboardingCompleted ?? false

                    UserDefaults.standard.set(true, forKey: "isAuthenticated")
                    if let email = email {
                        UserDefaults.standard.set(email, forKey: "userEmail")
                    }
                    if let username = username {
                        UserDefaults.standard.set(username, forKey: "username")
                    }
                    if let userId = userId {
                        UserDefaults.standard.set(userId, forKey: "userId")
                    }

                    viewModel.email = email ?? currentEmail
                    viewModel.username = username ?? ""
                    if let userId = userId {
                        viewModel.userId = userId
                    }
                    viewModel.onboardingCompleted = isOnboardingComplete
                    viewModel.serverOnboardingCompleted = isOnboardingComplete

                    UserDefaults.standard.set(isOnboardingComplete, forKey: "onboardingCompleted")
                    UserDefaults.standard.set(isOnboardingComplete, forKey: "serverOnboardingCompleted")

                    if isOnboardingComplete {
                        UserDefaults.standard.set(false, forKey: "onboardingInProgress")
                        UserDefaults.standard.removeObject(forKey: "currentOnboardingStep")
                        if let email = email, !email.isEmpty {
                            UserDefaults.standard.set(email, forKey: "emailWithCompletedOnboarding")
                        }
                    } else {
                        UserDefaults.standard.set(true, forKey: "onboardingInProgress")
                        UserDefaults.standard.removeObject(forKey: "emailWithCompletedOnboarding")
                    }

                    if let profileInitial = profileInitial {
                        viewModel.profileInitial = profileInitial
                        UserDefaults.standard.set(profileInitial, forKey: "profileInitial")
                    }

                    if let profileColor = profileColor {
                        viewModel.profileColor = profileColor
                        UserDefaults.standard.set(profileColor, forKey: "profileColor")
                    }

                    viewModel.updateSubscriptionInfo(
                        status: subscriptionStatus ?? "none",
                        plan: subscriptionPlan,
                        expiresAt: subscriptionExpiresAt,
                        renews: subscriptionRenews,
                        seats: subscriptionSeats,
                        canCreateNewTeam: nil
                    )

                    UserDefaults.standard.synchronize()

                    self.isAuthenticated = true
                    dismiss()
                }
            }
        }
    }
}



class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func run(action: @escaping () -> Void) {
        workItem?.cancel()
        let workItem = DispatchWorkItem(block: action)
        self.workItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}



struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView(isAuthenticated: .constant(false))
            .environmentObject(OnboardingViewModel())
    }
}
