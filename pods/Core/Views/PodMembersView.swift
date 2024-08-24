

import SwiftUI

struct PodMembersView: View {
    let podId: Int
    let teamId: Int?
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @Environment(\.colorScheme) var colorScheme
    @State private var members: [PodMember] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var role: String = ""
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedMember: PodMember?
    @State private var teamMembers: [TeamMember] = []
    @State private var memberToRemove: PodMember?
    @State private var showingRemoveConfirmation = false
    @State private var showingTeamMembersSheet = false
    @State private var combinedMembers: [PodMember] = []
    
    @State private var podType: String = ""
    
    private var canAddMembers: Bool {
        role.lowercased() == "owner" || role.lowercased() == "admin"
    }
    
    var body: some View {
        ZStack {
            Color("mxdBg").edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading) {
//                if canAddMembers {
//                    Button(action: {
//                        print("Add pod members tapped")
//                                            showingTeamMembersSheet = true
//                    }) {
//                        Text("Add pod subscribers")
//                            .foregroundColor(.accentColor)
//                            .font(.system(size: 14, weight: .regular))
//                            .padding(.horizontal, 20)
//                    }
//                    .padding(.top, 20)
//                }
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(combinedMembers) { member in
                                MemberRowView(member: member)
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
                HStack {
                    Spacer()
            
                        Button(action: {
                            print("Invite tapped")
                        
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.semibold)
                                Text("Invite members")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                            }
                              
                        }
                        .padding(.top, 5)
                        .padding(.bottom, 20)
                    }
                    
                    Spacer()
                }
              
                
                
            }
        }
        .navigationTitle("Pod Members")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isTabBarVisible.wrappedValue = false
            loadPodMembers()
            loadTeamMembers()
        }
        .sheet(item: $selectedMember) { member in
            MemberRoleOptions(
                currentRole: PodMemberRole(rawValue: member.role.lowercased()) ?? .member,
                onRoleChange: { newRole in
                    updateMemberRole(member: member, newRole: newRole)
                },     onRemoveMember: {
                    selectedMember = nil  // Dismiss the sheet
                    memberToRemove = member
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingRemoveConfirmation = true
                                        }
                }
            )
            .presentationDetents([.height(UIScreen.main.bounds.height / 1.7)])
        }
        
        .sheet(isPresented: $showingTeamMembersSheet) {
                   TeamMembersView(teamMembers: teamMembers, podMembers: $members)
               }
        .alert(isPresented: $showingRemoveConfirmation) {
            Alert(
                title: Text("Remove Member"),
                message: Text("Are you sure you want to remove this member from the pod?"),
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
        guard let teamId = teamId else {
                  print("No team ID available")
                  return
              }
        NetworkManager().fetchTeamMembers(teamId: teamId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let fetchedMembers):
                        self.teamMembers = fetchedMembers
                    case .failure(let error):
                        print("Error fetching team members: \(error.localizedDescription)")
                    }
                }
            }
        }

    
    private func removeMember(_ member: PodMember) {
        NetworkManager().removePodMember(podId: podId, memberId: member.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = members.firstIndex(where: { $0.id == member.id }) {
                        members.remove(at: index)
                    }
                    selectedMember = nil
                case .failure(let error):
                    print("Error removing member: \(error.localizedDescription)")
                    // You might want to show an error alert here
                }
            }
        }
    }
//
    private func updateMemberRole(member: PodMember, newRole: PodMemberRole) {
       
        NetworkManager().updatePodMembership(podId: podId, memberId: member.id, newRole: newRole.rawValue) { result in
            DispatchQueue.main.async {
           
                switch result {
                case .success:
                    if let index = combinedMembers.firstIndex(where: { $0.id == member.id }) {
                        let updatedMember = PodMember(
                            id: member.id,
                            name: member.name,
                            email: member.email,
                            profileInitial: member.profileInitial,
                            profileColor: member.profileColor,
                            role: newRole.rawValue
                        )
                        combinedMembers[index] = updatedMember
                        self.sortCombinedMembers()
                    }
                    selectedMember = nil // Dismiss the sheet
                case .failure(let error):
                   print("errpr")
                }
            }
        }
    }
    
    private func sortCombinedMembers() {
        let rolePriority: [String: Int] = [
            "owner": 0,
            "admin": 1,
            "member": 2,
            "viewer": 3,
            "guest": 4
        ]
        
        combinedMembers.sort { member1, member2 in
            let role1 = rolePriority[member1.role.lowercased()] ?? Int.max
            let role2 = rolePriority[member2.role.lowercased()] ?? Int.max
            
            if role1 != role2 {
                return role1 < role2
            } else {
                return member1.name < member2.name
            }
        }
    }

    private func loadPodMembers() {
        NetworkManager().fetchPodMembers(podId: podId, userEmail: viewModel.email) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let (fetchedMembers, fetchedUserRole, fetchedPodType)):
                    self.members = fetchedMembers
                    self.role = fetchedUserRole
                    self.podType = fetchedPodType
                    self.combineMembers()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    
//    private func combineMembers() {
//        var combined = members
//
//        if podType == "main" || podType == "shareable" {
//            for teamMember in teamMembers {
//                if !combined.contains(where: { $0.id == teamMember.id }) {
//                    let podMember = PodMember(
//                        id: teamMember.id,
//                        name: teamMember.name,
//                        email: teamMember.email,
//                        profileInitial: teamMember.profileInitial,
//                        profileColor: teamMember.profileColor,
//                        role: "member"  // Default role for team members not explicitly in the pod
//                    )
//                    combined.append(podMember)
//                }
//            }
//        }
//        
//        self.combinedMembers = combined.sorted { $0.name < $1.name }
//    }
    private func combineMembers() {
        var combined = members

        if podType == "main" || podType == "shareable" {
            for teamMember in teamMembers {
                if !combined.contains(where: { $0.id == teamMember.id }) {
                    let podMember = PodMember(
                        id: teamMember.id,
                        name: teamMember.name,
                        email: teamMember.email,
                        profileInitial: teamMember.profileInitial,
                        profileColor: teamMember.profileColor,
                        role: "member"  // Default role for team members not explicitly in the pod
                    )
                    combined.append(podMember)
                }
            }
        }

        // Define role priorities
        let rolePriority: [String: Int] = [
            "owner": 0,
            "admin": 1,
            "member": 2,
            "viewer": 3,
            "guest": 4
        ]

        // Sort members by role priority and then by name
        self.combinedMembers = combined.sorted {
            let role1 = rolePriority[$0.role.lowercased()] ?? Int.max
            let role2 = rolePriority[$1.role.lowercased()] ?? Int.max
            
            if role1 != role2 {
                return role1 < role2
            } else {
                return $0.name < $1.name
            }
        }
    }

}

struct MemberRowView: View {
    let member: PodMember
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
            .background(colorScheme == .dark ? Color(rgb: 44,44,44) : .white)

            Divider()
                .background(borderColor)
        }
    }

    private func roleColor(for role: String) -> Color {
        switch role.lowercased() {
        case "owner": return .blue
        case "admin": return .green
        case "member": return .orange
        case "viewer": return .purple
        case "guest": return .gray
        default: return .gray
        }
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 71, 71, 71) : Color(rgb: 219, 223, 236)
    }
}

struct MemberRoleOptions: View {
    let currentRole: PodMemberRole
    @State private var selectedRole: PodMemberRole
    let onRoleChange: (PodMemberRole) -> Void
    @Environment(\.presentationMode) var presentationMode
    let onRemoveMember: () -> Void
    
    init(currentRole: PodMemberRole, onRoleChange: @escaping (PodMemberRole) -> Void, onRemoveMember: @escaping () -> Void) {
            self.currentRole = currentRole
            self.onRoleChange = onRoleChange
            self.onRemoveMember = onRemoveMember
            self._selectedRole = State(initialValue: currentRole)
        }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(PodMemberRole.allCases, id: \.self) { role in
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
                // Add the "Remove member" label below the list
                Button(action: {
                    // Add action to remove member here
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

// PodMemberRole enum remains the same

enum PodMemberRole: String, CaseIterable, Identifiable {
    case owner = "Owner"
    case admin = "Admin"
    case member = "Member"
    case viewer = "Viewer"
    case guest = "Guest"
    
    var id: String { self.rawValue }
    
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "owner": self = .owner
        case "admin": self = .admin
        case "member": self = .member
        case "viewer": self = .viewer
        case "guest": self = .guest
        default: return nil
        }
    }
    
    var iconName: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "person.badge.key"
        case .member: return "person.badge.shield.checkmark"
        case .viewer: return "person.wave.2"
        case .guest: return "person.badge.clock"
    
        }
    }
    
    var description: String {
        switch self {
        case .owner: return "Has total control of the pod"
        case .admin: return "Can create & edit content, manage security"
        case .member: return "Can create & edit content"
        case .viewer: return "Can read only but cannot edit"
        case .guest: return "Can only access Shareable pods via invitation"
        }
    }
}


struct TeamMembersView: View {
    let teamMembers: [TeamMember]
    @Binding var podMembers: [PodMember]
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
         NavigationView {
             ZStack {
                 Color("mdBg")
                     .ignoresSafeArea(.all)

                 List(teamMembers) { member in
                     TeamMemberRowView(member: member, isSelected: isPodMember(member))
                         .onTapGesture {
                             toggleMemberSelection(member)
                         }
                         .listRowInsets(EdgeInsets())
                         .listRowBackground(Color.clear) // Make the List row background transparent
                 }
            
                 .background(Color("mdBg")) // Set the List background color
                 .scrollContentBackground(.hidden) // Hide the default List background
             }
            
             .navigationTitle("Team Members")
             .navigationBarTitleDisplayMode(.inline)
             .navigationBarItems(trailing: Button("Done") {
                 presentationMode.wrappedValue.dismiss()
             })
         }
     }

    private func isPodMember(_ member: TeamMember) -> Bool {
        podMembers.contains { $0.id == member.id }
    }

    private func toggleMemberSelection(_ member: TeamMember) {
        if let index = podMembers.firstIndex(where: { $0.id == member.id }) {
            podMembers.remove(at: index)
        } else {
            let newPodMember = PodMember(id: member.id, name: member.name, email: member.email, profileInitial: member.profileInitial, profileColor: member.profileColor, role: "member")
            podMembers.append(newPodMember)
        }
    }
}

struct TeamMemberRowView: View {
    let member: TeamMember
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            DefaultProfilePicture(
                initial: member.profileInitial,
                color: member.profileColor,
                size: 30
            )
            
            VStack(alignment: .leading) {
                Text(member.name)
                    .font(.system(size: 14))
                    .fontWeight(.medium)
    
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 3.5)
        .background(colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
    }
}
