import SwiftUI
import Combine

struct ForgotPasswordView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var email: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    @State private var navigateToResetPassword = false
    @Binding var showForgotPassword: Bool

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack {
                        Spacer(minLength: geometry.size.height / 4) // Adjust the value as needed
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
                .padding()
            }
            .navigationBarBackButtonHidden(true)
            .background(Color.white)
            .navigationDestination(isPresented: $navigateToResetPassword) {
                ResetPasswordView(email:email,  showForgotPassword: $showForgotPassword)
                        }
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trouble Logging in?")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.black)
            
            Text("Enter your email and we'll send you a one-time code to reset your password")
                .font(.footnote)
                .foregroundColor(.black)
                .padding(.bottom, 20)

            CustomTextField(placeholder: "Email", text: $email)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding(.bottom, 20)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
    }
    
    private var continueButton: some View {
           Button(action: resetAction) {
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
               .background(Color(red: 70/255, green: 87/255, blue: 245/255))
               .cornerRadius(10)
           }
           .padding(.horizontal)
           .padding(.bottom, 50)
       }

       private func resetAction() {
           isLoading = true

           if email.isEmpty || !email.contains("@") {
               self.errorMessage = "Please enter a valid email address."
               isLoading = false
               return
           }

           NetworkManager().requestPasswordReset(email: email) { success, errorMessage in
               DispatchQueue.main.async {
                   isLoading = false
                   if success {
                       navigateToResetPassword = true
                   } else {
                       self.errorMessage = errorMessage ?? "Failed to send reset code. Please try again."
                   }
               }
           }
       }

//    private var continueButton: some View {
//           ZStack {
//               NavigationLink(destination: ResetPasswordView(), isActive: $navigateToResetPassword) {
//                   EmptyView()
//               }
//               Button(action: resetAction) {
//                   ZStack {
//                       if isLoading {
//                           ProgressView()
//                               .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                       } else {
//                           Text("Continue")
//                               .foregroundColor(.white)
//                       }
//                   }
//                   .frame(maxWidth: .infinity)
//                   .padding()
//                   .background(Color(red: 70/255, green: 87/255, blue: 245/255))
//                   .cornerRadius(10)
//               }
//               .padding(.horizontal)
//               .padding(.bottom, 50)
//           }
//       }
//
//       private func resetAction() {
//           isLoading = true
//
//           if email.isEmpty || !email.contains("@") {
//               self.errorMessage = "Please enter a valid email address."
//               isLoading = false
//               return
//           }
//
//           NetworkManager().requestPasswordReset(email: email) { success, errorMessage in
//               DispatchQueue.main.async {
//                   isLoading = false
//                   if success {
//                       navigateToResetPassword = true
//                   } else {
//                       self.errorMessage = errorMessage ?? "Failed to send reset code. Please try again."
//                   }
//               }
//           }
//       }
}




