import SwiftUI

struct LoginView: View {
    @State private var password: String = ""
    @Binding var isAuthenticated: Bool
    @State private var email: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil // Consolidated error message for simplicity
    @State private var navigateToEmailVerification = false // Controls navigation to the email verification view
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    topBar
//                    logo
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
    }

    private var topBar: some View {
        HStack {
            Button("Sign out") {
                // Logic to handle sign out
//                presentationMode.wrappedValue.dismiss()
                viewModel.currentStep = .landing
            }
            .foregroundColor(Color(red: 70/255, green: 87/255, blue: 245/255))
            .padding()
            Spacer()
        }
    }

    private var logo: some View {
        HStack {
            Spacer()
            Image("black-logo") // Make sure the logo image is added to your asset catalog
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
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
        VStack {
            Button(action: {
                if email.isEmpty || !email.contains("@") {
                    self.errorMessage = "Please enter a valid email address."
                } else if password.count < 8 {
                    self.errorMessage = "Password must be at least 8 characters."
                } else {
                    
                    
                    let networkManager = NetworkManager()
                             networkManager.login(email: email, password: password) { success, _ in
                                 if success {
                                     // If login is successful, update the authenticated state
                                     DispatchQueue.main.async {
                                         self.isAuthenticated = true
                                         self.viewModel.email = email
                                     }
                                 } else {
                                     // Handle login failure, e.g., by showing an error message
                                     self.errorMessage = "Login failed. Please check your credentials and try again."
                                 }
                             }
                }
            }) {
                Text("Continue")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 70/255, green: 87/255, blue: 245/255))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
       
        .padding(.bottom, 50)
        
    }
    
    
    
}

//
//
//struct LoginView_Previews: PreviewProvider {
//    static var previews: some View {
//        LoginView()
//    }
//}
