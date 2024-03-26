import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil
    @Binding var isAuthenticated: Bool

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
            }
            .navigationBarHidden(true)
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.light)
    }

    private var topBar: some View {
        HStack {
            Button("Sign out") {
                viewModel.currentStep = .landing
            }
            .foregroundColor(Color(red: 70/255, green: 87/255, blue: 245/255))
            .padding()
            Spacer()
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome back")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("Email", text: $email)
                .textFieldStyle(CustomTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)

            ZStack(alignment: .trailing) {
                if showPassword {
                    TextField("Password", text: $password)
                        .textFieldStyle(CustomTextFieldStyle())
                } else {
                    SecureField("Password", text: $password)
                        .textFieldStyle(CustomTextFieldStyle())
                }

                Button(action: {
                    self.showPassword.toggle()
                }) {
                    Image(systemName: self.showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(Color(red: 70/255, green: 87/255, blue: 245/255))
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
        Button(action: loginAction) {
            Text("Continue")
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 70/255, green: 87/255, blue: 245/255))
                .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.bottom, 50)
    }

    private func loginAction() {
        if email.isEmpty || !email.contains("@") {
            self.errorMessage = "Please enter a valid email address."
            return
        }

        if password.count < 8 {
            self.errorMessage = "Password must be at least 8 characters."
            return
        }

        authenticateUser()
    }

    private func authenticateUser() {
        // Assuming you have a function to authenticate the user
        NetworkManager().login(email: email, password: password) { success, error in
            if success {
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    viewModel.email = email
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = error ?? "Login failed. Please check your credentials and try again."
                }
            }
        }
    }
}



//
//
//struct LoginView_Previews: PreviewProvider {
//    static var previews: some View {
//        LoginView()
//    }
//}
