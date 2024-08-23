

import SwiftUI

struct PodMembersView: View {
    let podId: Int
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @Environment(\.colorScheme) var colorScheme
    @State private var members: [PodMember] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var role: String = ""
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedMember: PodMember?
    
    @State private var memberToRemove: PodMember?
    @State private var showingRemoveConfirmation = false
    
    private var canAddMembers: Bool {
        role.lowercased() == "owner" || role.lowercased() == "admin"
    }
    
    var body: some View {
        ZStack {
            Color("mxdBg").edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading) {
                if canAddMembers {
                    Button(action: {
                        print("Add pod members tapped")
                    }) {
                        Text("Add pod members")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16, weight: .regular))
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                }
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(members) { member in
                                MemberRowView(member: member)
                                    .onTapGesture {
                                        self.selectedMember = member
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Pod Members")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isTabBarVisible.wrappedValue = false
            loadPodMembers()
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

    private func updateMemberRole(member: PodMember, newRole: PodMemberRole) {
       
        NetworkManager().updatePodMembership(podId: podId, memberId: member.id, newRole: newRole.rawValue) { result in
            DispatchQueue.main.async {
           
                switch result {
                case .success:
                    if let index = members.firstIndex(where: { $0.id == member.id }) {
                        let updatedMember = PodMember(
                            id: member.id,
                            name: member.name,
                            email: member.email,
                            profileInitial: member.profileInitial,
                            profileColor: member.profileColor,
                            role: newRole.rawValue
                        )
                        members[index] = updatedMember
                    }
                    selectedMember = nil // Dismiss the sheet
                case .failure(let error):
                   print("errpr")
                }
            }
        }
    }
    private func loadPodMembers() {
        NetworkManager().fetchPodMembers(podId: podId, userEmail: viewModel.email) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let (fetchedMembers, fetchedUserRole)):
                    self.members = fetchedMembers
                    self.role = fetchedUserRole
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
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
            .padding()
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

