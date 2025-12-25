
//
//  AgentConversation.swift
//  pods
//
//  Created by Dimi Nunez on 12/24/25.
//


//
//  ConversationModels.swift
//  pods
//
//  Models for agent conversation history feature.
//

import Foundation

// MARK: - Conversation Models

struct AgentConversation: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var isPinned: Bool
    let messageCount: Int
    let createdAt: Date
    let updatedAt: Date
    let lastMessageAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title
        case isPinned = "is_pinned"
        case messageCount = "message_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastMessageAt = "last_message_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        messageCount = try container.decode(Int.self, forKey: .messageCount)

        // Decode dates from ISO8601 strings
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        let lastMessageAtString = try container.decodeIfPresent(String.self, forKey: .lastMessageAt)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: createdAtString) {
            createdAt = date
        } else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            createdAt = formatter.date(from: createdAtString) ?? Date()
        }

        if let date = formatter.date(from: updatedAtString) {
            updatedAt = date
        } else {
            formatter.formatOptions = [.withInternetDateTime]
            updatedAt = formatter.date(from: updatedAtString) ?? Date()
        }

        if let lastString = lastMessageAtString {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: lastString) {
                lastMessageAt = date
            } else {
                formatter.formatOptions = [.withInternetDateTime]
                lastMessageAt = formatter.date(from: lastString)
            }
        } else {
            lastMessageAt = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(messageCount, forKey: .messageCount)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        try container.encode(formatter.string(from: createdAt), forKey: .createdAt)
        try container.encode(formatter.string(from: updatedAt), forKey: .updatedAt)
        if let lastMessageAt = lastMessageAt {
            try container.encode(formatter.string(from: lastMessageAt), forKey: .lastMessageAt)
        }
    }
}

struct AgentMessageResponse: Codable, Identifiable {
    let id: String
    let role: String
    let content: String
    let responseType: String?
    let responseData: AgentMessageData?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, role, content
        case responseType = "response_type"
        case responseData = "response_data"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        role = try container.decode(String.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        responseType = try container.decodeIfPresent(String.self, forKey: .responseType)
        responseData = try container.decodeIfPresent(AgentMessageData.self, forKey: .responseData)

        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: createdAtString) {
            createdAt = date
        } else {
            formatter.formatOptions = [.withInternetDateTime]
            createdAt = formatter.date(from: createdAtString) ?? Date()
        }
    }
}

struct AgentMessageData: Codable {
    let food: HealthCoachFood?
    let mealItems: [HealthCoachMealItem]?
    let activity: HealthCoachActivity?
    let citations: [HealthCoachCitation]?

    enum CodingKeys: String, CodingKey {
        case food
        case mealItems = "meal_items"
        case activity
        case citations
    }
}

// MARK: - API Response Models

struct ConversationsResponse: Codable {
    let conversations: [AgentConversation]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case conversations
        case hasMore = "has_more"
    }
}

struct ConversationMessagesResponse: Codable {
    let conversationId: String
    let title: String
    let isPinned: Bool
    let messages: [AgentMessageResponse]

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case title
        case isPinned = "is_pinned"
        case messages
    }
}

struct CreateConversationResponse: Codable {
    let id: String
    let title: String
    let isPinned: Bool
    let messageCount: Int
    let createdAt: String
    let updatedAt: String
    let lastMessageAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case isPinned = "is_pinned"
        case messageCount = "message_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastMessageAt = "last_message_at"
    }

    func toAgentConversation() -> AgentConversation? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let created = formatter.date(from: createdAt) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: createdAt)
        }(),
        let updated = formatter.date(from: updatedAt) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: updatedAt)
        }() else {
            return nil
        }

        var lastMessage: Date? = nil
        if let lastString = lastMessageAt {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            lastMessage = formatter.date(from: lastString) ?? {
                formatter.formatOptions = [.withInternetDateTime]
                return formatter.date(from: lastString)
            }()
        }

        // We need to construct manually since AgentConversation has custom init
        let jsonString = """
        {
            "id": "\(id)",
            "title": "\(title.replacingOccurrences(of: "\"", with: "\\\""))",
            "is_pinned": \(isPinned),
            "message_count": \(messageCount),
            "created_at": "\(createdAt)",
            "updated_at": "\(updatedAt)",
            "last_message_at": \(lastMessageAt != nil ? "\"\(lastMessageAt!)\"" : "null")
        }
        """

        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AgentConversation.self, from: data)
    }
}

struct AddMessageResponse: Codable {
    let id: String
    let conversationId: String
    let role: String
    let content: String
    let responseType: String?
    let responseData: AgentMessageData?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role, content
        case responseType = "response_type"
        case responseData = "response_data"
        case createdAt = "created_at"
    }
}
