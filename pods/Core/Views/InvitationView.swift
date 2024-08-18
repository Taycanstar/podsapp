//
//  InvitationView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/17/24.
//

import SwiftUI

struct InvitationView: View {
    let podId: Int
    let token: String
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("You've been invited to join a pod!")
                .font(.title)
                .multilineTextAlignment(.center)

            Text("Pod ID: \(podId)")
                .font(.subheadline)

            if isLoading {
                ProgressView()
            } else {
                Button("Accept Invitation") {
                    acceptInvitation()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    private func acceptInvitation() {
        isLoading = true
        NetworkManager().acceptPodInvitation(podId: podId, token: token, userEmail: viewModel.email) { result in
            isLoading = false
            switch result {
            case .success:
                presentationMode.wrappedValue.dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}
