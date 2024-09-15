import SwiftUI

enum TeamNavigationDestination: Hashable {
    case teamInfo
    case teamMembers

    func hash(into hasher: inout Hasher) {
        switch self {
        case .teamInfo:
            hasher.combine("teamInfo")
        case .teamMembers:
            hasher.combine("teamMembers")

        }
    }

    static func == (lhs: TeamNavigationDestination, rhs: TeamNavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.teamInfo, .teamInfo), (.teamMembers, .teamMembers):
            return true
        default:
            return false
        }
    }
}

struct TeamOptionsView: View {
    @Binding var showTeamOptionsSheet: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isSharePresented = false
    @State private var shareURL: URL?
    var onDeleteTeam: () -> Void
    var teamName: String
    var teamId: Int
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme
    var navigationAction: (TeamNavigationDestination) -> Void
    @State private var navigateToTeamInfo = false
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {

                
                VStack(alignment: .leading, spacing: 0) {
                    MenuItemView(iconName: "square.and.arrow.up", text: "Share", action: {
                        generateShareLink()
                        HapticFeedback.generate()
                    }, color: .primary)
                    
//                    MenuItemView(iconName: "info.circle", text: "Team info", action: {
//                        dismiss()
//                        HapticFeedback.generate()
//                        navigationAction(.teamInfo)
//                    }, color: .primary)
                    NavigationLink(destination: TeamInfoView(teamId: teamId), isActive: $navigateToTeamInfo) {
                                     MenuItemView(iconName: "info.circle", text: "Team info", action: {
                                         HapticFeedback.generate()
                                         navigateToTeamInfo = true
                                     }, color: .primary)
                                 }
                    

                    MenuItemView(iconName: "person.2", text: "Team members", action: {
                        dismiss()
                        HapticFeedback.generate()
//                        navigationAction(.teamMembers)
                    }, color: .primary)
                    
                    Divider().padding(.vertical, 5)
                    
                    MenuItemView(iconName: "trash", text: "Delete Team", action: {
                        showDeleteConfirmation = true
                        HapticFeedback.generate()
                    }, color: .red)
                }
                .padding(.horizontal, 25)
                .padding(.top, 20)
                .padding(.bottom, 15)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
            .cornerRadius(20)
            .confirmationDialog("Delete \"\(teamName)\"?",
                                isPresented: $showDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDeleteTeam()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        
        .sheet(isPresented: $isSharePresented, content: {
            if let url = shareURL {
                ActivityViewController(activityItems: [url])
                    .presentationDetents([.height(UIScreen.main.bounds.height / 2)])
            }
        })
    }
    
    private func generateShareLink() {
           NetworkManager().shareTeam(teamId: teamId, userEmail: viewModel.email) { result in
               switch result {
               case .success(let invitation):
                   self.shareURL = URL(string: invitation.token)
                   self.isSharePresented = true
               case .failure(let error):
                   print("Failed to generate share link: \(error)")
               }
           }
       }
}
