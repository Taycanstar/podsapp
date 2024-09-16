//
//  TeamInfoView.swift
//  Podstack
//
//  Created by Dimi Nunez on 9/14/24.
//

import SwiftUI

struct TeamInfoView: View {
//    @State private var team: Team?
    let teamId: Int
    @State private var currentName: String = ""
    @State private var currentDescription: String = ""
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @Environment(\.colorScheme) var colorScheme
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var teamDetails: TeamDetails?
    @EnvironmentObject var viewModel: OnboardingViewModel

    private var canEditTeam: Bool {
        teamDetails?.role == "owner" || teamDetails?.role == "admin"
    }

    var body: some View {
        ZStack {
            Color("mxdBg")
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Team Name Section
                    Section(header: Text("Team Name").font(.system(size: 14))) {
                        if canEditTeam {
                            TextField("Enter Team Name", text: $currentName)
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
//                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            Text(currentName)
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                        }
                    }

                    Divider()
                        .background(borderColor)

                    // Team Description Section
                    Section(header: Text("Team Description").font(.system(size: 14))) {
                        if canEditTeam {
                            TextEditor(text: $currentDescription)
                                .font(.system(size: 16))
                                .frame(height: 100)
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 8)
//                                        .stroke(borderColor, lineWidth: 1)
//                                )
                        } else {
                            Text(currentDescription)
                                .font(.system(size: 16))
                        }
                    }

                    Divider()
                        .background(borderColor)

                    // Created by Section
                    Section(header: Text("Created by").font(.system(size: 14))) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color("mxdBg"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(borderColor, lineWidth: 1)
                                )

                            HStack {
                                DefaultProfilePicture(
                                    initial: teamDetails?.creator.profileInitial ?? "Y",
                                    color: teamDetails?.creator.profileColor ?? "blue",
                                    size: 30
                                )

                                Text(teamDetails?.creator.name ?? "No creator")
                                    .fontWeight(.medium)
                                    .font(.system(size: 14))
                                Spacer()
                            }
                            .padding()
                        }
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .navigationBarItems(
            trailing: Group {
                if canEditTeam {
                    Button(action: {
                        saveTeamChanges()
                    }) {
                        Text("Save")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        )
        .navigationTitle("Team Info")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isTabBarVisible.wrappedValue = false
            loadTeamDetails()
        }
    }

  
     
    private func loadTeamDetails() {
        isLoading = true
        NetworkManager().fetchTeamDetails(teamId: teamId, userEmail: viewModel.email) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let details):
                    self.teamDetails = details
                    self.currentName = details.name
                    self.currentDescription = details.description
                    print(details, "dets")
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

     private func saveTeamChanges() {
         NetworkManager().updateTeamDetails(
             teamId: teamId,
             name: currentName,
             description: currentDescription
         ) { result in
             DispatchQueue.main.async {
                 switch result {
                 case .success(let (updatedName, updatedDescription)):
                     // Update local state if needed
                     self.currentName = updatedName
                     self.currentDescription = updatedDescription
                     self.presentationMode.wrappedValue.dismiss()
                 case .failure(let error):
                     print("Failed to update team: \(error)")
                 }
             }
         }
     }

    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 71, 71, 71) : Color(rgb: 219, 223, 236)
    }
}
