
import SwiftUI

struct MyTeamMembersView: View {
    let teamId: Int
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @Environment(\.colorScheme) var colorScheme
    @State private var members: [TeamMember] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var role: String = ""
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedMember: TeamMember?
    @State private var memberToRemove: TeamMember?
    @State private var showingRemoveConfirmation = false
    @State private var showingInviteSheet = false
    
    private var canAddMembers: Bool {
        role.lowercased() == "owner" || role.lowercased() == "admin"
    }
    
    var body: some View {
        ZStack {
            Color("mxdBg").edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading) {
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(members) { member in
                                MyTeamMemberRowView(member: member)
                                    .onTapGesture {
                                        self.selectedMember = member
                                    }
                            }
                            .disabled(!canAddMembers)
                        }
                        .padding()
                    }
                }
                
                if canAddMembers {
                    Button(action: {
                        showingInviteSheet = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                            Text("Invite member")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Team Members")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isTabBarVisible.wrappedValue = false
            loadTeamMembers()
            print("role is", role, "can add members?", canAddMembers)
        }
        .sheet(item: $selectedMember) { member in
            TeamMemberRoleOptions(
                currentRole: TeamMemberRole(rawValue: member.role.lowercased()) ?? .member,
                onRoleChange: { newRole in
                    updateMemberRole(member: member, newRole: newRole)
                },
                onRemoveMember: {
                    selectedMember = nil
                    memberToRemove = member
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingRemoveConfirmation = true
                    }
                }
            )
            .presentationDetents([.height(UIScreen.main.bounds.height / 1.7)])
        }
        .sheet(isPresented: $showingInviteSheet) {
            InviteTeamMemberView(teamId: teamId, isPresented: $showingInviteSheet)
        }
        .alert(isPresented: $showingRemoveConfirmation) {
            Alert(
                title: Text("Remove Member"),
                message: Text("Are you sure you want to remove this member from the team?"),
                primaryButton: .destructive(Text("Remove")) {
                    if let member = memberToRemove {
                        removeMember(member)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func loadTeamMembers() {
        isLoading = true
        NetworkManager().fetchTeamMembers(teamId: teamId) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let fetchedMembers):
                    self.members = fetchedMembers
                    self.determineUserRole()
                    self.sortMembers()
                case .failure(let error):
                    print("Error fetching team members: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func removeMember(_ member: TeamMember) {
        NetworkManager().removeTeamMember(teamId: teamId, memberId: member.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = members.firstIndex(where: { $0.id == member.id }) {
                        members.remove(at: index)
                    }
                    selectedMember = nil
                case .failure(let error):
                    print("Error removing member: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func determineUserRole() {
        if let currentUserMember = members.first(where: { $0.email == viewModel.email }) {
            self.role = currentUserMember.role
        } else {
            self.role = "member" // Default to member if not found
        }
        
    }
    
    private func updateMemberRole(member: TeamMember, newRole: TeamMemberRole) {
        NetworkManager().updateTeamMembership(teamId: teamId, memberId: member.id, newRole: newRole.rawValue) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = members.firstIndex(where: { $0.id == member.id }) {
                        let updatedMember = TeamMember(
                            id: member.id,
                            name: member.name,
                            email: member.email,
                            role: newRole.rawValue,
                            profileInitial: member.profileInitial,
                            profileColor: member.profileColor
                        )
                        members[index] = updatedMember
                        sortMembers()
                    }
                    selectedMember = nil
                case .failure(let error):
                    print("Error updating member role: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func sortMembers() {
        let rolePriority: [String: Int] = [
            "owner": 0,
            "member": 1
        ]
        
        members.sort { member1, member2 in
            let role1 = rolePriority[member1.role.lowercased()] ?? Int.max
            let role2 = rolePriority[member2.role.lowercased()] ?? Int.max
            
            if role1 != role2 {
                return role1 < role2
            } else {
                return member1.name < member2.name
            }
        }
    }
}

struct MyTeamMemberRowView: View {
    let member: TeamMember
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            HStack(spacing: 15) {
                DefaultProfilePicture(
                    initial: member.profileInitial,
                    color: member.profileColor,
                    size: 30
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.system(size: 14, weight: .semibold))
                    Text(member.email)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(member.role.capitalized)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(roleColor(for: member.role))
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
            .padding(8)
            .background(Color("mxdBg"))

            Divider()
                .background(borderColor)
        }
    }

    private func roleColor(for role: String) -> Color {
        switch role.lowercased() {
        case "owner": return .blue
        case "member": return .orange
        default: return .gray
        }
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 71, 71, 71) : Color(rgb: 219, 223, 236)
    }
}

struct TeamMemberRoleOptions: View {
    let currentRole: TeamMemberRole
    @State private var selectedRole: TeamMemberRole
    let onRoleChange: (TeamMemberRole) -> Void
    @Environment(\.presentationMode) var presentationMode
    let onRemoveMember: () -> Void
    
    init(currentRole: TeamMemberRole, onRoleChange: @escaping (TeamMemberRole) -> Void, onRemoveMember: @escaping () -> Void) {
        self.currentRole = currentRole
        self.onRoleChange = onRoleChange
        self.onRemoveMember = onRemoveMember
        self._selectedRole = State(initialValue: currentRole)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(TeamMemberRole.allCases, id: \.self) { role in
                        Button(action: {
                            selectedRole = role
                            onRoleChange(role)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: selectedRole == role ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedRole == role ? .accentColor : .gray)
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Image(systemName: role.iconName)
                                        Text(role.rawValue)
                                            .font(.headline)
                                    }
                                    Text(role.description)
                                        .font(.system(size: 12))
                                        .fontWeight(.regular)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                Button(action: {
                    onRemoveMember()
                    print("tapped remove")
                }) {
                    Text("Remove member")
                        .foregroundColor(.red)
                        .fontWeight(.regular)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            }
            .listStyle(PlainListStyle())
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
            )
            .navigationBarTitle("Member Role", displayMode: .inline)
        }
    }
}

enum TeamMemberRole: String, CaseIterable, Identifiable {
    case owner = "Owner"
    case member = "Member"

    var id: String { self.rawValue }
    
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "owner": self = .owner
        case "member": self = .member
        default: return nil
        }
    }
    
    var iconName: String {
        switch self {
        case .owner: return "crown.fill"
        case .member: return "person.badge.shield.checkmark"
        }
    }
    
    var description: String {
        switch self {
        case .owner: return "Has total control of the team"
        case .member: return "Can create & edit content"
        }
    }
}


struct InviteTeamMemberView: View {
    let teamId: Int
    @State private var email: String = ""
    @State private var selectedRole: PodMemberRole = .member
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var isLoading = false
        @State private var errorMessage: String?
        @State private var showAlert = false
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Invite via email")
                        .foregroundColor(.primary)
                        .fontWeight(.bold)

                    HStack {
                        TextField("Enter email address", text: $email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:244, 246, 247))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                    )
                    .cornerRadius(10)
                    .padding(.top)
                    
                    HStack {
                        Text("User role")
                        Spacer()
                        Picker("User Role", selection: $selectedRole) {
                            ForEach(PodMemberRole.allCases, id: \.self) { role in
                                Text(role.rawValue).tag(role)
                                    .foregroundColor(.primary)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:244, 246, 247))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                    )
                    .cornerRadius(10)
                    
                    Button(action: {
                        sendInvite()
                    }) {
                        HStack(spacing: 5) {
                            Text("Send invite")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 17)
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:218,222,237), lineWidth: colorScheme == .dark ? 1 : 1)
                        )
                    }
                    .disabled(email.isEmpty)
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 10)
                    
                    if let errorMessage = errorMessage {
                                          Text(errorMessage)
                                              .foregroundColor(.red)
                                              .font(.caption)
                                      }
                    if showAlert {
                        Text("Pod invite sent successfully")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 35)
            }
            .background(Color("mdBg").edgesIgnoringSafeArea(.all))
            .navigationTitle("Invite a new pod member")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .background(Color("mdBg").edgesIgnoringSafeArea(.all))
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 86, 86, 86) : Color(rgb: 230, 230, 230)
    }
    
    private func sendInvite() {
         isLoading = true
         errorMessage = nil
         
         NetworkManager().inviteTeamMember(
             teamId: teamId,
             inviterEmail: viewModel.email,
             inviteeEmail: email,
             role: selectedRole.rawValue
         ) { result in
             DispatchQueue.main.async {
                 isLoading = false
                 switch result {
                 case .success:
                     showAlert = true
                     DispatchQueue.main.asyncAfter(deadline: .now() + 4){
                         showAlert = false
                     }
                 case .failure(let error):
                     errorMessage = error.localizedDescription
                 }
             }
         }
     }
}

