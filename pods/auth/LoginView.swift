import SwiftUI
import Combine

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
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(red: 35/255, green: 108/255, blue: 255/255))
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
//    private func authenticateUser() {
//        isLoading = true
//        NetworkManager().login(identifier: identifier, password: password) { success, error, email, username, activeTeamId, activeWorkspaceId, profileInitial, profileColor in
//            DispatchQueue.main.async {
//                if success {
//                    self.isAuthenticated = true
//                    UserDefaults.standard.set(true, forKey: "isAuthenticated")
//                   
//                    if let email = email {
//                        self.viewModel.email = email
//                        UserDefaults.standard.set(email, forKey: "userEmail")
//                    }
//                    if let username = username {
//                        self.viewModel.username = username
//                        UserDefaults.standard.set(username, forKey: "username")
//                    }
//                    if let activeTeamId = activeTeamId {
//                        self.viewModel.activeTeamId = activeTeamId
//                        UserDefaults.standard.set(activeTeamId, forKey: "activeTeamId")
//                    }
//                    if let activeWorkspaceId = activeWorkspaceId {
//                        self.viewModel.activeWorkspaceId = activeWorkspaceId
//                        UserDefaults.standard.set(activeWorkspaceId, forKey: "activeWorkspaceId")
//                    }
//                    if let profileInitial = profileInitial {
//                        self.viewModel.profileInitial = profileInitial
//                        UserDefaults.standard.set(profileInitial, forKey: "profileInitial")
//                    }
//                    if let profileColor = profileColor {
//                        self.viewModel.profileColor = profileColor
//                        UserDefaults.standard.set(profileColor, forKey: "profileColor")
//                    }
//                    
//                 
//                } else {
//                    self.errorMessage = error ?? "Invalid credentials"
//                }
//                self.isLoading = false
//            }
//        }
//    }
    private func authenticateUser() {
        isLoading = true
        NetworkManager().login(identifier: identifier, password: password) { success, error, email, username, activeTeamId, activeWorkspaceId, profileInitial, profileColor, subscriptionStatus, subscriptionPlan, subscriptionExpiresAt in
            DispatchQueue.main.async {
                if success {
                    self.isAuthenticated = true
                    UserDefaults.standard.set(true, forKey: "isAuthenticated")
                   
                    if let email = email {
                        self.viewModel.email = email
                        UserDefaults.standard.set(email, forKey: "userEmail")
                    }
                    if let username = username {
                        self.viewModel.username = username
                        UserDefaults.standard.set(username, forKey: "username")
                    }
                    if let activeTeamId = activeTeamId {
                        self.viewModel.activeTeamId = activeTeamId
                        UserDefaults.standard.set(activeTeamId, forKey: "activeTeamId")
                    }
                    if let activeWorkspaceId = activeWorkspaceId {
                        self.viewModel.activeWorkspaceId = activeWorkspaceId
                        UserDefaults.standard.set(activeWorkspaceId, forKey: "activeWorkspaceId")
                    }
                    if let profileInitial = profileInitial {
                        self.viewModel.profileInitial = profileInitial
                        UserDefaults.standard.set(profileInitial, forKey: "profileInitial")
                    }
                    if let profileColor = profileColor {
                        self.viewModel.profileColor = profileColor
                        UserDefaults.standard.set(profileColor, forKey: "profileColor")
                    }
                    
                    self.viewModel.updateSubscriptionInfo(status: subscriptionStatus, plan: subscriptionPlan, expiresAt: subscriptionExpiresAt)
                 
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
