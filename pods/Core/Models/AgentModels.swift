import Foundation

enum AgentResponseHint: String, Codable {
    case chat = "chat"
    case logFood = "log_food"
    case logActivity = "log_activity"
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            self.value = arrayValue.map(\.value)
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            self.value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            let codableArray = arrayValue.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dictValue as [String: Any]:
            let codableDict = dictValue.mapValues { AnyCodable($0) }
            try container.encode(codableDict)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Invalid JSON value"))
        }
    }
}

struct AgentPendingAction: Identifiable, Decodable {
    let id: Int
    let actionType: String
    let payload: [String: AnyCodable]
    let rationale: String?
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case actionType = "action_type"
        case payload
        case rationale
        case createdAt = "created_at"
    }
}

struct AgentContextSnapshot: Decodable {
    let raw: [String: AnyCodable]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.raw = try container.decode([String: AnyCodable].self)
    }
}

struct AgentChatMessage: Identifiable, Equatable {
    enum Sender {
        case user
        case agent
        case system
        case pendingLog
    }

    let id = UUID()
    let sender: Sender
    let text: String
    let timestamp: Date
    let pendingLog: AgentPendingLog?

    init(
        sender: Sender,
        text: String,
        timestamp: Date,
        pendingLog: AgentPendingLog? = nil
    ) {
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.pendingLog = pendingLog
    }

    var isPendingLog: Bool {
        sender == .pendingLog && pendingLog != nil
    }

    static func == (lhs: AgentChatMessage, rhs: AgentChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct AgentPendingLog: Identifiable, Decodable {
    enum LogType: String, Decodable {
        case food
        case activity
    }

    let id: String
    let logType: LogType
    let status: String
    let mealType: String
    let targetDate: String?
    let title: String
    let description: String?
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let servingText: String?
    let activityType: String?
    let durationMinutes: Int?
    let createdAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case logType = "log_type"
        case status
        case mealType = "meal_type"
        case targetDate = "target_date"
        case title
        case description
        case calories
        case protein
        case carbs
        case fat
        case servingText = "serving_text"
        case activityType = "activity_type"
        case durationMinutes = "duration_minutes"
        case createdAt = "created_at"
    }

    var isFoodLog: Bool { logType == .food }
}
