import SwiftUI
import Foundation

struct SignupView: View {
    @State private var password: String = ""
    @State private var email: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil
    @State private var navigateToEmailVerification = false
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    
    // Debouncer for email and password input
    private var emailDebouncer = Debouncer(delay: 0.5)
    private var passwordDebouncer = Debouncer(delay: 0.5)
    
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
            Image("black-logo")
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
            networkManager.signup(email: email, password: password) { success, message in
                if success {
                    DispatchQueue.main.async {
                        // Skip email verification and go directly to info screen
                        self.viewModel.currentStep = .info
                        self.viewModel.email = self.email
                        self.viewModel.password = self.password
                        isLoading = false
                    }
                } else {
                    self.errorMessage = message
                    isLoading = false
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
        SignupView()
    }
}
