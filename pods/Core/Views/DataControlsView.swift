import SwiftUI
import GoogleSignIn

struct DataControlsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showingDeleteAllPodsAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccessMessage = false
    @State private var successMessage = ""
    @Binding var isAuthenticated: Bool

    var body: some View {
        ZStack {
            Form {
                Section {
                    Button(action: {
                        showingDeleteAllPodsAlert = true
                    }) {
                        Text("Delete all pods")
                            .foregroundColor(.red)
                    }
                    .alert(isPresented: $showingDeleteAllPodsAlert) {
                        Alert(
                            title: Text("Delete All Pods"),
                            message: Text("Are you sure you want to delete all pods? This action cannot be undone."),
                            primaryButton: .destructive(Text("Delete")) {
                                deleteAllPods()
                            },
                            secondaryButton: .cancel()
                        )
                    }

                    Button(action: {
                        showingDeleteAccountAlert = true
                    }) {
                        Text("Delete account")
                            .foregroundColor(.red)
                    }
                    .alert(isPresented: $showingDeleteAccountAlert) {
                        Alert(
                            title: Text("Delete Account"),
                            message: Text("Are you sure you want to delete your account? This action cannot be undone."),
                            primaryButton: .destructive(Text("Delete")) {
                                deleteAccount()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Data Controls")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isLoading)

            if showingSuccessMessage {
                VStack {
                    Spacer()
                    ToastView(message: successMessage)
                        .transition(.move(edge: .bottom))
                        .padding(.bottom, 50)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showingSuccessMessage = false
                                }
                            }
                        }
//                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
               
               
            }
        }
    }
    
    private func logOut() {
          // Clear the authentication state and email from UserDefaults
          UserDefaults.standard.set(false, forKey: "isAuthenticated")
          UserDefaults.standard.set("", forKey: "userEmail")
        UserDefaults.standard.set("", forKey: "username")
        // Sign out from Google
                GIDSignIn.sharedInstance.signOut()
          // Update the state variables
        isAuthenticated = false
          viewModel.email = ""
      }

    private func deleteAllPods() {
        isLoading = true
        NetworkManager().deleteAllPods(email: viewModel.email) { success, message in
            isLoading = false
            if success {
                withAnimation {
                    successMessage = "All pods deleted successfully"
                    showingSuccessMessage = true
                }
            } else {
                errorMessage = message
            }
        }
    }

    private func deleteAccount() {
        isLoading = true
        NetworkManager().deleteUserAndData(email: viewModel.email) { success, message in
            isLoading = false
            if success {
                withAnimation {
                    successMessage = "Account deleted successfully"
                    showingSuccessMessage = true
                }
               logOut()
                // Add any additional steps needed to handle the user deletion
            } else {
                errorMessage = message
            }
        }
    }
}

//
//
//#Preview {
//    DataControlsView()
//}

import SwiftUI

struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
    }
}
