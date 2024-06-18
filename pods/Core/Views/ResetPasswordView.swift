//
//  ResetPasswordView.swift
//  Podstack
//
//  Created by Dimi Nunez on 6/18/24.
//

import SwiftUI

struct ResetPasswordView: View {
    @State private var code: String = ""
    @State private var newPassword: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    @State private var showPassword: Bool = false
    let email: String
    @Binding var showForgotPassword: Bool


    var body: some View {
        VStack {
            Text("Reset Password")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .padding(.top, 40)

            Text("Enter the code sent to your email")
                .font(.footnote)
                .foregroundColor(.black)
                .padding(.bottom, 20)

            CustomTextField(placeholder: "Code", text: $code)
                .autocapitalization(.none)
                .padding(.horizontal)
                .padding(.top, 10)
            
            ZStack(alignment: .trailing) {

                CustomTextField(placeholder: "New password", text: $newPassword, isSecure: true, showPassword: showPassword)
                    .autocapitalization(.none)
                
                Button(action: {
                    self.showPassword.toggle()
                }) {
                    Image(systemName: self.showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(Color(red: 70/255, green: 87/255, blue: 245/255))
                }
                .padding(.trailing, 15)
            }
            .padding(.horizontal)
            .padding(.top, 10)

//            CustomTextField(placeholder: "New password", text: $newPassword, isSecure: true, showPassword: showPassword)
//                .autocapitalization(.none)
//                .padding(.horizontal)
//                .padding(.top, 10)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }

            Button(action: resetPasswordAction) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Reset Password")
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 70/255, green: 87/255, blue: 245/255))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 20)
            }

            Spacer()
        }
        .padding()
        .alert(isPresented: .constant(errorMessage != nil)) {
            Alert(title: Text("Error"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    private func resetPasswordAction() {
        isLoading = true

        guard !code.isEmpty else {
            errorMessage = "Please enter the code."
            isLoading = false
            return
        }

        guard !newPassword.isEmpty else {
            errorMessage = "Please enter and confirm your new password."
            isLoading = false
            return
        }

        NetworkManager().resetPassword(email: email, code: code, newPassword: newPassword) { success, errorMessage in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    // Navigate to the next screen or show success message
                    showForgotPassword = false
                } else {
                    self.errorMessage = errorMessage ?? "Failed to reset password. Please try again."
                }
            }
        }
    }
}
