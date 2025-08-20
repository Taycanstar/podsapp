//
//  EditNameView.swift
//  Pods
//
//  Created by Dimi Nunez on 7/5/25.
//

import SwiftUI

struct EditNameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var onboarding: OnboardingViewModel
    
    @State private var name: String = ""
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var canChangeName: Bool = true
    @State private var daysRemaining: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Input field
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter your name", text: $name)
                    .font(.system(size: 17))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("tiktoknp"))
                    .cornerRadius(8)
                    .disabled(isLoading)
                
                if canChangeName {
                    Text("This is the name that will be displayed on your profile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("You can change your name again in \(daysRemaining) day\(daysRemaining == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Name")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveName()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || !canChangeName)
                .foregroundColor((name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canChangeName) ? .secondary : .accentColor)
            }
        }
        .onAppear {
            // Initialize with current name from profile data
            if let profileData = onboarding.profileData {
                name = profileData.name
            } else {
                name = onboarding.name ?? ""
            }
            
            // Check name eligibility
            checkNameEligibility()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
    
    private func saveName() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Name cannot be empty"
            showError = true
            return
        }
        
        isLoading = true
        
        // Call API to update name
        NetworkManagerTwo.shared.updateName(email: onboarding.email, name: trimmedName) { result in
            Task { @MainActor in
                isLoading = false
                
                switch result {
                case .success:
                    // Update local data
                    onboarding.name = trimmedName
                    if var profileData = onboarding.profileData {
                        profileData.name = trimmedName
                        onboarding.profileData = profileData
                    }
                    
                    // Dismiss the view
                    dismiss()
                    
                case .failure(let error):
                    if let networkError = error as? NetworkError,
                       case .serverError(let message) = networkError {
                        errorMessage = message
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showError = true
                }
            }
        }
    }
    
    private func checkNameEligibility() {
        NetworkManagerTwo.shared.checkNameEligibility(email: onboarding.email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    canChangeName = response.canChangeName
                    daysRemaining = response.daysRemaining
                    
                case .failure(let error):
                    print("❌ Failed to check name eligibility: \(error)")
                    // If we can't check eligibility, assume they can change (fail open)
                    canChangeName = true
                    daysRemaining = 0
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        EditNameView()
    }
}
