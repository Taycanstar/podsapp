//
//  InvitationView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/17/24.
//

import SwiftUI

struct InvitationView: View {
    let invitation: PodInvitation
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject var homeViewModel: HomeViewModel

    var body: some View {
        ZStack {
            Color("dkBg")
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) { // Combine the image and content vertically
                // Header Image
                HStack {
                    Image(colorScheme == .dark ? "fullwte" : "fullblk")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 25)
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }, label: {
                        Image(systemName: "xmark")
                       
                            .foregroundColor(.primary)
                    })
               
                    
                }
                .padding(.horizontal, 25)
//                .padding(.vertical, 55)

                .frame(height: 44)
                Spacer()

                // Content
                VStack(alignment: .leading, spacing: 15) {

                    Text("You've been invited to a Pod")
                                          .font(.system(size: 24))
                                          .foregroundColor(.primary)
                                          .fontWeight(.bold)
                                      
                                      Text("\(invitation.userName)")
                                          .bold() +
                                      Text(" (\(invitation.userEmail)) has invited you to use Podstack together, in a pod called ")
                                          .foregroundColor(.primary) +
                                      Text("\(invitation.podName)")
                                          .foregroundColor(.primary)
                                          .bold()
             
                    if isLoading {
                        ProgressView()
                    } else {
                        HStack {
                            Spacer()
                            HStack {
                                Button(action: {
                                    acceptInvitation()
                                }) {
                                    Text("Accept Invitation")
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 14)
                                        .background(Color.accentColor)
                                        .cornerRadius(10)
                                }

                            }
                            .padding(.top, 15)
                        
                            Spacer()
                        }
                   
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 0)

                Spacer() // Ensures the content stays in the middle with equal space above and below
            }
        }
    }

    private func acceptInvitation() {
        isLoading = true
        NetworkManager().acceptPodInvitation(podId: invitation.podId, token: invitation.token, userEmail: viewModel.email, invitationType: invitation.invitationType) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    homeViewModel.refreshPods(email: viewModel.email) {
                        presentationMode.wrappedValue.dismiss()
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
