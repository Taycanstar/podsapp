//
//  AddWorkspaceView.swift
//  Podstack
//
//  Created by Dimi Nunez on 9/6/24.
//

import SwiftUI

struct AddWorkspaceView: View {
    @Binding var isPresented: Bool
    @State private var workspaceName: String = ""
    @State private var workspaceDescription: String = ""
    @State private var isPrivate: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    var networkManager: NetworkManager = NetworkManager()
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                    .edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    // Workspace Name Input
                    HStack {
                        TextField("Workspace Name", text: $workspaceName)
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:244, 246, 247))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                    )
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top)

                    // Privacy Selection
                    HStack {
                        Image(systemName: isPrivate ? "lock" : "lock.open")
                            .foregroundColor(.blue)
                        Text("Privacy")
                        Spacer()
                        Toggle("", isOn: $isPrivate)
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:244, 246, 247))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                    )
                    .cornerRadius(10)
                    .padding(.horizontal)

                    Spacer()
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Add workspace")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .foregroundColor(.blue)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Create") {
                            createWorkspace()
                        }
                        .disabled(workspaceName.isEmpty)
                        .foregroundColor(workspaceName.isEmpty ? .gray : .blue)
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

    private func createWorkspace() {
            guard !workspaceName.isEmpty else {
                errorMessage = "Workspace name is required."
                return
            }

            guard let activeTeamId = viewModel.activeTeamId else {
                errorMessage = "No active team found."
                return
            }

            networkManager.createWorkspace(name: workspaceName, description: workspaceDescription, isPrivate: isPrivate, teamId: activeTeamId, email: viewModel.email) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let workspace):
                        print("Workspace created successfully with ID: \(workspace.id)")
                        self.homeViewModel.workspaces.append(workspace)
                        self.isPresented = false
                    case .failure(let error):
                        print("Failed to create workspace: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
}
