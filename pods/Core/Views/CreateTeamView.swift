//
//  CreateTeamView.swift
//  Podstack
//
//  Created by Dimi Nunez on 9/8/24.
//
import SwiftUI

struct CreateTeamView: View {
    @Binding var isPresented: Bool
    @State private var teamName: String = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    var networkManager: NetworkManager = NetworkManager()

    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                    .edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    TextField("Team Name", text: $teamName)
                        .padding()
                        .background(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:244, 246, 247))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                        )
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.top)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }

                    Spacer()
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("New Team")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .foregroundColor(.blue)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Create") {
                            createTeam()
                        }
                        .disabled(teamName.isEmpty || isCreating)
                        .foregroundColor(teamName.isEmpty || isCreating ? .gray : .blue)
                    }
                }
            }
        }
        .accentColor(.blue)
        .background(colorScheme == .dark ? Color.black : Color.white)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 86, 86, 86) : Color(rgb: 230, 230, 230)
    }

    private func createTeam() {
        isCreating = true
        errorMessage = nil
        networkManager.createTeam(name: teamName, email: viewModel.email) { result in
            DispatchQueue.main.async {
                isCreating = false
                switch result {
                case .success(let newTeam):
                    // Update homeViewModel
                    homeViewModel.teams.append(newTeam)
                    
                    // Update viewModel
                    viewModel.activeTeamId = newTeam.id
                    viewModel.canCreateNewTeam = false
                    
                    // Update UserDefaults
                    UserDefaults.standard.set(newTeam.id, forKey: "activeTeamId")
                    
                    // Dismiss the view
                    isPresented = false
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
