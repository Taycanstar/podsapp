import SwiftUI

struct InfoView: View {
    @State private var username: String = ""
    @State private var name: String = ""
    @State private var showError: Bool = false // State to control error message visibility
    @State private var errorMessage: String = ""
    @State private var isLoading = false
    
    @EnvironmentObject var viewModel: OnboardingViewModel
    var networkManager: NetworkManager = NetworkManager()
    @Environment(\.presentationMode) var presentationMode // For dismissing the view
    
    var body: some View {
        VStack {
            HStack {
                Button("Sign out") {
                    viewModel.currentStep = .landing
                }
                .foregroundColor(Color(red: 35/255, green: 108/255, blue: 255/255))
                .padding()
                Spacer()
            }

            VStack(alignment: .leading, spacing: 20) {
                Text("Finish creating your Humuli account")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Text("Tell us about you.")
                    .font(.headline)
                    .foregroundColor(.gray)

                ZStack(alignment: .leading) {
                    CustomTextField(placeholder: "Name", text: $name)
                        .autocapitalization(.none)
                        .keyboardType(.default)
                }
                
                ZStack(alignment: .leading) {
                    CustomTextField(placeholder: "Username", text: $username)
                        .autocapitalization(.none)
                        .keyboardType(.default)
                }
                
                if showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            VStack {
                HStack {
                    Text("By continuing, you agree to the ")
                    
                    Text("Terms")
                        .foregroundColor(Color.accentColor)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "http://humuli.com/policies/terms") {
                                UIApplication.shared.open(url)
                            }
                        }
                    
                    Text(" and ")
                    
                    Text("Privacy Policy")
                        .foregroundColor(Color.accentColor)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "https://humuli.com/policies/privacy-policy") {
                                UIApplication.shared.open(url)
                            }
                        }
                }
                .font(.footnote)
                .foregroundColor(.gray)

                Button(action: {
                    guard !name.isEmpty, !username.isEmpty else {
                        self.errorMessage = "Name and Username are required."
                        self.showError = true
                        return
                    }
                    
                    // Example function call, replace with actual implementation
                    networkManager.updateUserInformation(email: viewModel.email, name: name, username: username) { success, message in
                        DispatchQueue.main.async {
                            isLoading = true
                            if success {
                                // Handle success
                                self.viewModel.username = self.username
                                
                                viewModel.currentStep = .welcome
                                isLoading = false
                            } else {
                                // Handle error, optionally update errorMessage and showError to inform the user
                                print("Error updating user information: \(message)")
                            }
                        }
                    }
                    
                    // Reset error state when button action is successfully triggered
                    self.showError = false
                }) {
                    Text("Continue")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 35/255, green: 108/255, blue: 255/255))
                        .cornerRadius(10)
                }
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .padding(.bottom, 50)
            .background(Color.white)
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.white)
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView()
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding() // This adds padding around the text
//            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(10) // Rounded corners for the background
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 0.2) // Custom border
            )
    }
}
