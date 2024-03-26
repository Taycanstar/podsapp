import SwiftUI

struct EmailVerificationView: View {
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var birthday: Date? = nil
    @State private var showingDatePicker = false
    private let networkManager = NetworkManager()
    @State private var showingAlert = false
       @State private var alertMessage = ""
    
    
    // DateFormatter to display the date
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    

    @Environment(\.presentationMode) var presentationMode // For dismissing the view
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    
    var body: some View {
       
        VStack {
            HStack {
                Button("Sign out") {
//                    presentationMode.wrappedValue.dismiss()
                    viewModel.currentStep = .landing
                }
                .foregroundColor(Color(red: 70/255, green: 87/255, blue: 245/255))
                .padding()
                Spacer()
            }

           

            VStack(alignment: .leading, spacing: 20) {
                Text("Finish creating your Humuli account")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("An email to \(viewModel.email) has been sent. Click on the link to get started.")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Button("Resend email") {
                           resendVerificationEmail()
                       }
                       .foregroundColor(Color(red: 70/255, green: 87/255, blue: 245/255))
//                       .padding()

                    
                   }
            .alert(isPresented: $showingAlert) {
                       Alert(title: Text("Email Verification"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                   
            }
            .padding(.horizontal)
            
            Spacer()
            
            VStack {
                

                Button(action: {
                    // Handle continue action here
                    print(viewModel.email, "email")
                  checkEmailVerification()
                }) {
                    Text("I have verified my email")
                        .foregroundColor(.black)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 50)
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.light)
    }
    private func checkEmailVerification() {
        networkManager.checkEmailVerified(email: viewModel.email) { success, message in
            DispatchQueue.main.async {
                if success {
                    // Navigate to the next view or update the state as necessary
                    self.viewModel.currentStep = .info 
                } else {
                    self.alertMessage = message ?? "Your email  hasn't been verified. Check your email."
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func resendVerificationEmail() {
        networkManager.resendVerificationEmail(email: viewModel.email) { success, message in
            DispatchQueue.main.async {
                if success {
                    self.alertMessage = "Verification email resent successfully."
                } else {
                    self.alertMessage = message ?? "Failed to resend verification email."
                }
                self.showingAlert = true
            }
        }
    }
    
}

struct EmailVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        EmailVerificationView()
    }
}




