//
//  ChatsView.swift
//  pods
//
//  Created by Dimi Nunez on 10/28/25.
//

import SwiftUI

struct ChatsView: View {
    let name: String
    var onNavigateToDashboard: () -> Void
    var onSelectConversationId: ((String?) -> Void)?

    // Bindings for immediate new conversation update
    @Binding var newConversationId: String?
    @Binding var newConversationTitle: String?

    // Binding to trigger refresh from parent (e.g., when returning from AgentChatView)
    @Binding var shouldRefresh: Bool

    @Environment(\.dismiss) private var dismiss
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = false
    @EnvironmentObject private var onboardingViewModel: OnboardingViewModel

    @State private var showSettingsSheet = false

    // Simple data arrays - no complex types in @State
    @State private var pinnedIds: [String] = []
    @State private var pinnedTitles: [String] = []
    @State private var recentIds: [String] = []
    @State private var recentTitles: [String] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = false
    @State private var currentOffset = 0
    @State private var searchText = ""

    // Rename state - only primitives
    @State private var renameConversationId: String?
    @State private var renameText = ""

    private let pageSize = 50

    var body: some View {
        List {
            // Pinned Section
            if !filteredPinnedIndices.isEmpty {
                Section {
                    ForEach(filteredPinnedIndices, id: \.self) { index in
                        conversationRow(
                            id: pinnedIds[index],
                            title: pinnedTitles[index],
                            isPinned: true
                        )
                    }
                } header: {
                    Text("Pinned")
                }
            }

            // Recent Section - no header per requirements
            if !filteredRecentIndices.isEmpty {
                Section {
                    ForEach(filteredRecentIndices, id: \.self) { index in
                        conversationRow(
                            id: recentIds[index],
                            title: recentTitles[index],
                            isPinned: false
                        )
                    }
                }
            }

            // Empty State
            if pinnedIds.isEmpty && recentIds.isEmpty && !isLoading {
                Section {
                    emptyStateView
                }
                .listSectionSeparator(.hidden)
            }

            // Loading indicator for initial load
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listSectionSeparator(.hidden)
            }

            // Load more trigger at bottom of list
            if hasMore && !isLoading && !isLoadingMore {
                Section {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            loadMoreConversations()
                        }
                }
                .listRowSeparator(.hidden)
            }

            // Loading more indicator
            if isLoadingMore {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refreshConversations()
        }
        .searchable(text: $searchText, prompt: "Search conversations")
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onNavigateToDashboard()
                } label: {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 18, weight: .semibold))
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Spacer()
            }

            ToolbarItem(placement: .bottomBar) {
                Button {
                    createNewConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20))
                }
            }
        }
        .onAppear {
            loadConversations()
        }
        .onChange(of: newConversationId) { _, newId in
            // When a new conversation is created, add it to the top of recent list
            if let id = newId, let title = newConversationTitle {
                // Only add if not already in list
                if !recentIds.contains(id) && !pinnedIds.contains(id) {
                    recentIds.insert(id, at: 0)
                    recentTitles.insert(title, at: 0)
                }
                // Clear the binding
                newConversationId = nil
                newConversationTitle = nil
            }
        }
        .onChange(of: shouldRefresh) { _, newValue in
            // Refresh conversations when triggered by parent (e.g., returning from AgentChatView)
            if newValue {
                shouldRefresh = false
                loadConversations(force: true)
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                ProfileView(isAuthenticated: Binding(get: { isAuthenticated }, set: { isAuthenticated = $0 }))
            }
        }
        .alert("Rename Conversation", isPresented: .init(
            get: { renameConversationId != nil },
            set: { if !$0 { renameConversationId = nil } }
        )) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) { renameConversationId = nil }
            Button("Save") {
                if let convId = renameConversationId {
                    renameConversation(convId, to: renameText)
                }
                renameConversationId = nil
            }
        }
    }

    // MARK: - Filtered Indices

    private var filteredPinnedIndices: [Int] {
        guard !searchText.isEmpty else {
            return Array(pinnedIds.indices)
        }
        return pinnedIds.indices.filter { index in
            pinnedTitles[index].localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredRecentIndices: [Int] {
        guard !searchText.isEmpty else {
            return Array(recentIds.indices)
        }
        return recentIds.indices.filter { index in
            recentTitles[index].localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Row View

    private func conversationRow(id: String, title: String, isPinned: Bool) -> some View {
        Button {
            onSelectConversationId?(id)
        } label: {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .contextMenu {
            Button {
                renameText = title
                renameConversationId = id
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                togglePin(id: id, currentlyPinned: isPinned)
            } label: {
                Label(
                    isPinned ? "Unpin" : "Pin",
                    systemImage: isPinned ? "pin.slash" : "pin"
                )
            }

            Divider()

            Button(role: .destructive) {
                deleteConversation(id: id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No conversations yet")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowSeparator(.hidden)
    }

    // MARK: - Data Operations

    private func loadConversations(force: Bool = false) {
        guard force || (pinnedIds.isEmpty && recentIds.isEmpty) else { return }

        let email = onboardingViewModel.email.isEmpty
            ? (UserDefaults.standard.string(forKey: "userEmail") ?? "")
            : onboardingViewModel.email

        guard !email.isEmpty else { return }

        isLoading = true
        currentOffset = 0

        Task {
            do {
                let response = try await NetworkManager().getConversations(
                    userEmail: email,
                    limit: pageSize,
                    offset: 0
                )

                await MainActor.run {
                    // Separate pinned and recent
                    let pinned = response.conversations.filter { $0.isPinned }
                    let recent = response.conversations.filter { !$0.isPinned }

                    pinnedIds = pinned.map { $0.id }
                    pinnedTitles = pinned.map { $0.title }

                    recentIds = recent.map { $0.id }
                    recentTitles = recent.map { $0.title }

                    hasMore = response.hasMore
                    currentOffset = response.conversations.count
                    isLoading = false
                }
            } catch {
                print("Failed to load conversations: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    /// Async refresh for pull-to-refresh
    private func refreshConversations() async {
        let email = onboardingViewModel.email.isEmpty
            ? (UserDefaults.standard.string(forKey: "userEmail") ?? "")
            : onboardingViewModel.email

        guard !email.isEmpty else { return }

        do {
            let response = try await NetworkManager().getConversations(
                userEmail: email,
                limit: pageSize,
                offset: 0
            )

            let pinned = response.conversations.filter { $0.isPinned }
            let recent = response.conversations.filter { !$0.isPinned }

            pinnedIds = pinned.map { $0.id }
            pinnedTitles = pinned.map { $0.title }
            recentIds = recent.map { $0.id }
            recentTitles = recent.map { $0.title }

            hasMore = response.hasMore
            currentOffset = response.conversations.count
        } catch {
            print("Failed to refresh conversations: \(error)")
        }
    }

    private func loadMoreConversations() {
        guard !isLoadingMore && hasMore else { return }

        let email = onboardingViewModel.email.isEmpty
            ? (UserDefaults.standard.string(forKey: "userEmail") ?? "")
            : onboardingViewModel.email

        guard !email.isEmpty else { return }

        isLoadingMore = true

        Task {
            do {
                let response = try await NetworkManager().getConversations(
                    userEmail: email,
                    limit: pageSize,
                    offset: currentOffset
                )

                await MainActor.run {
                    // Append new conversations (only recent, pinned are already loaded)
                    let pinned = response.conversations.filter { $0.isPinned }
                    let recent = response.conversations.filter { !$0.isPinned }

                    // Append pinned (unlikely but handle it)
                    for conv in pinned {
                        if !pinnedIds.contains(conv.id) {
                            pinnedIds.append(conv.id)
                            pinnedTitles.append(conv.title)
                        }
                    }

                    // Append recent
                    for conv in recent {
                        if !recentIds.contains(conv.id) {
                            recentIds.append(conv.id)
                            recentTitles.append(conv.title)
                        }
                    }

                    hasMore = response.hasMore
                    currentOffset += response.conversations.count
                    isLoadingMore = false
                }
            } catch {
                print("Failed to load more conversations: \(error)")
                await MainActor.run {
                    isLoadingMore = false
                }
            }
        }
    }

    private func createNewConversation() {
        // Open AgentChatView with nil conversation ID
        // The conversation will be created when the first message is sent
        onSelectConversationId?(nil)
    }

    private func togglePin(id: String, currentlyPinned: Bool) {
        let email = onboardingViewModel.email.isEmpty
            ? (UserDefaults.standard.string(forKey: "userEmail") ?? "")
            : onboardingViewModel.email

        guard !email.isEmpty else { return }

        Task {
            do {
                _ = try await NetworkManager().updateConversation(
                    conversationId: id,
                    userEmail: email,
                    title: nil,
                    isPinned: !currentlyPinned
                )
                // Reload to get updated state
                await MainActor.run {
                    pinnedIds = []
                    pinnedTitles = []
                    recentIds = []
                    recentTitles = []
                    hasMore = false
                    currentOffset = 0
                }
                loadConversations()
            } catch {
                print("Failed to toggle pin: \(error)")
            }
        }
    }

    private func renameConversation(_ id: String, to newTitle: String) {
        let email = onboardingViewModel.email.isEmpty
            ? (UserDefaults.standard.string(forKey: "userEmail") ?? "")
            : onboardingViewModel.email

        guard !email.isEmpty else { return }

        Task {
            do {
                _ = try await NetworkManager().updateConversation(
                    conversationId: id,
                    userEmail: email,
                    title: newTitle,
                    isPinned: nil
                )
                await MainActor.run {
                    // Update local state
                    if let index = pinnedIds.firstIndex(of: id) {
                        pinnedTitles[index] = newTitle
                    }
                    if let index = recentIds.firstIndex(of: id) {
                        recentTitles[index] = newTitle
                    }
                }
            } catch {
                print("Failed to rename: \(error)")
            }
        }
    }

    private func deleteConversation(id: String) {
        let email = onboardingViewModel.email.isEmpty
            ? (UserDefaults.standard.string(forKey: "userEmail") ?? "")
            : onboardingViewModel.email

        guard !email.isEmpty else { return }

        Task {
            do {
                try await NetworkManager().deleteConversation(
                    conversationId: id,
                    userEmail: email
                )
                await MainActor.run {
                    if let index = pinnedIds.firstIndex(of: id) {
                        pinnedIds.remove(at: index)
                        pinnedTitles.remove(at: index)
                    }
                    if let index = recentIds.firstIndex(of: id) {
                        recentIds.remove(at: index)
                        recentTitles.remove(at: index)
                    }
                }
            } catch {
                print("Failed to delete: \(error)")
            }
        }
    }

}
