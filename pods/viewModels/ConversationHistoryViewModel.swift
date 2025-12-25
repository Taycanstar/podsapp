//
//  ConversationHistoryViewModel.swift
//  pods
//
//  Created by Dimi Nunez on 12/24/25.
//


//
//  ConversationHistoryViewModel.swift
//  pods
//
//  ViewModel for managing conversation history list.
//

import Foundation
import SwiftUI

@MainActor
final class ConversationHistoryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var conversations: [AgentConversation] = []
    @Published var pinnedConversations: [AgentConversation] = []
    @Published var recentConversations: [AgentConversation] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var hasMore = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let networkManager = NetworkManager()
    private var userEmail: String?
    private var offset = 0
    private let pageSize = 50

    // MARK: - Computed Properties

    var filteredPinnedConversations: [AgentConversation] {
        guard !searchText.isEmpty else { return pinnedConversations }
        return pinnedConversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var filteredRecentConversations: [AgentConversation] {
        guard !searchText.isEmpty else { return recentConversations }
        return recentConversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var hasConversations: Bool {
        !conversations.isEmpty
    }

    // MARK: - Public Methods

    func loadConversations(userEmail: String, refresh: Bool = false) async {
        self.userEmail = userEmail

        if refresh {
            offset = 0
        }

        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let response = try await networkManager.getConversations(
                userEmail: userEmail,
                limit: pageSize,
                offset: offset
            )

            if refresh {
                conversations = response.conversations
            } else {
                conversations.append(contentsOf: response.conversations)
            }

            hasMore = response.hasMore
            offset += response.conversations.count

            // Separate pinned and recent
            pinnedConversations = conversations.filter { $0.isPinned }
            recentConversations = conversations.filter { !$0.isPinned }

        } catch {
            print("Failed to load conversations: \(error)")
            errorMessage = "Failed to load conversations"
        }
    }

    func loadMore() async {
        guard let email = userEmail, hasMore, !isLoading else { return }
        await loadConversations(userEmail: email, refresh: false)
    }

    func createNewConversation() async -> AgentConversation? {
        guard let email = userEmail else { return nil }

        do {
            let conversation = try await networkManager.createConversation(userEmail: email)
            conversations.insert(conversation, at: 0)
            recentConversations.insert(conversation, at: 0)
            return conversation
        } catch {
            print("Failed to create conversation: \(error)")
            errorMessage = "Failed to create conversation"
            return nil
        }
    }

    func togglePin(for conversation: AgentConversation) async {
        guard let email = userEmail else { return }

        do {
            let updated = try await networkManager.updateConversation(
                conversationId: conversation.id,
                userEmail: email,
                title: nil,
                isPinned: !conversation.isPinned
            )

            // Update local state
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[index] = updated
            }

            pinnedConversations = conversations.filter { $0.isPinned }
            recentConversations = conversations.filter { !$0.isPinned }

        } catch {
            print("Failed to toggle pin: \(error)")
            errorMessage = "Failed to update conversation"
        }
    }

    func renameConversation(_ conversation: AgentConversation, to newTitle: String) async {
        await renameConversationById(conversation.id, to: newTitle)
    }

    func renameConversationById(_ conversationId: String, to newTitle: String) async {
        guard let email = userEmail else { return }

        do {
            let updated = try await networkManager.updateConversation(
                conversationId: conversationId,
                userEmail: email,
                title: newTitle,
                isPinned: nil
            )

            if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                conversations[index] = updated
            }

            pinnedConversations = conversations.filter { $0.isPinned }
            recentConversations = conversations.filter { !$0.isPinned }

        } catch {
            print("Failed to rename conversation: \(error)")
            errorMessage = "Failed to rename conversation"
        }
    }

    func deleteConversation(_ conversation: AgentConversation) async {
        guard let email = userEmail else { return }

        do {
            try await networkManager.deleteConversation(
                conversationId: conversation.id,
                userEmail: email
            )

            conversations.removeAll { $0.id == conversation.id }
            pinnedConversations.removeAll { $0.id == conversation.id }
            recentConversations.removeAll { $0.id == conversation.id }

        } catch {
            print("Failed to delete conversation: \(error)")
            errorMessage = "Failed to delete conversation"
        }
    }

    func refreshConversations() async {
        guard let email = userEmail else { return }
        await loadConversations(userEmail: email, refresh: true)
    }
}
