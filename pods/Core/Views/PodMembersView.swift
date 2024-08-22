//
//  PodMembersView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/21/24.
//


import SwiftUI


struct PodMembersView: View {
    let podId: Int
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @Environment(\.colorScheme) var colorScheme
    @State private var members: [PodMember] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color("mxdBg").edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(members) { member in
                            MemberRowView(member: member)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Pod Members")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isTabBarVisible.wrappedValue = false
            loadPodMembers()
        }
    }

    private func loadPodMembers() {
        NetworkManager().fetchPodMembers(podId: podId) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let fetchedMembers):
                    self.members = fetchedMembers
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
        HStack(spacing: 15) {
            DefaultProfilePicture(
                initial: member.profileInitial,
                color: member.profileColor,
                size: 40
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.system(size: 16, weight: .semibold))
                Text(member.email)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(member.role.capitalized)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(roleColor(for: member.role))
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding()
        .background(colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private func roleColor(for role: String) -> Color {
        switch role.lowercased() {
        case "owner":
            return .blue
        case "admin":
            return .green
        case "member":
            return .orange
        case "viewer":
            return .purple
        case "guest":
            return .gray
        default:
            return .gray
        }
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 71, 71, 71) : Color(rgb: 219, 223, 236)
    }
}
