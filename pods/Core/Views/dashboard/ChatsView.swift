//
//  ChatsView.swift
//  pods
//
//  Created by Dimi Nunez on 10/28/25.
//

import SwiftUI

struct ChatsView: View {
    let initial: String
    let name: String
    let showsBorder: Bool
    var onNavigateToDashboard: () -> Void
    var chats: [String] = []

    @Environment(\.dismiss) private var dismiss
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = false

    @State private var showMyProfile = false
    @State private var showSettingsSheet = false
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack(spacing: 16) {
                // Leading: Avatar + Name
                Button {
                    showMyProfile = true
                } label: {
                    HStack(spacing: 12) {
                        ChatsAvatarCircle(initial: initial, showsBorder: showsBorder)
                        Text(name)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Trailing: Gear + Forward Chevron
                HStack(spacing: 16) {
                    // Gear icon - opens ProfileView as sheet
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)

                    // Forward chevron - navigates to DashboardView
                    Button {
                        onNavigateToDashboard()
                    } label: {
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color("primarybg"))

            // Content
            List(filteredChats, id: \.self) { chat in
                Text(chat)
                    .font(.body)
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $showMyProfile) {
            MyProfileView(isAuthenticated: Binding(get: { isAuthenticated }, set: { isAuthenticated = $0 }))
                .environment(\.isTabBarVisible, .constant(true))
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                ProfileView(isAuthenticated: Binding(get: { isAuthenticated }, set: { isAuthenticated = $0 }))
            }
        }
    }

    private var filteredChats: [String] {
        guard !searchText.isEmpty else { return chats }
        return chats.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
}

private struct ChatsAvatarCircle: View {
    var initial: String
    var showsBorder: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(showsBorder ? 0.35 : 0.15), lineWidth: showsBorder ? 1.6 : 1)
                )
            Text(initial)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(width: 36, height: 36)
    }
}
