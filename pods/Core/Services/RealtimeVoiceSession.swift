//
//  RealtimeSessionState.swift
//  pods
//
//  Created by Dimi Nunez on 12/7/25.
//


//
//  RealtimeVoiceSession.swift
//  pods
//
//  Created by Claude on 12/7/25.
//

import Foundation
import AVFoundation
import WebRTC

enum RealtimeSessionState: Equatable {
    case idle
    case connecting
    case connected
    case muted
    case error(String)

    static func == (lhs: RealtimeSessionState, rhs: RealtimeSessionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.connecting, .connecting),
             (.connected, .connected), (.muted, .muted):
            return true
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}

struct RealtimeMessage: Identifiable, Equatable {
    let id = UUID()
    let isUser: Bool
    let text: String
}

@MainActor
class RealtimeVoiceSession: NSObject, ObservableObject {
    @Published var state: RealtimeSessionState = .idle
    @Published var transcribedText: String = ""
    @Published var messages: [RealtimeMessage] = []
    var delegate: RealtimeVoiceSessionDelegate?
    // Track which conversation items we've already rendered so we don't double-add
    private var processedItemIds: Set<String> = []
    // Items we originated locally (via speakText) so we can skip duplicating them when echoed back
    private var localAssistantItemIds: Set<String> = []

    // Streaming text for live display
    @Published var currentUserText: String = ""
    @Published var currentAssistantText: String = ""
    @Published var isProcessing: Bool = false

    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var audioTrack: RTCAudioTrack?
    private var ephemeralKey: String?
    private var factory: RTCPeerConnectionFactory?

    override init() {
        super.init()
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
    }

    func connect() async throws {
        state = .connecting
        transcribedText = ""
        messages = []
        currentUserText = ""
        currentAssistantText = ""
        localAssistantItemIds.removeAll()

        // 1. Get ephemeral key from backend
        ephemeralKey = try await fetchEphemeralKey()
        processedItemIds.removeAll()

        // 2. Setup peer connection with audio
        try setupPeerConnection()

        // 3. Create offer and exchange SDP
        let offer = try await createOffer()
        let answer = try await sendOfferToOpenAI(offer: offer)
        try await setRemoteDescription(answer: answer)

        state = .connected
    }

    func disconnect() {
        dataChannel?.close()
        peerConnection?.close()
        peerConnection = nil
        dataChannel = nil
        audioTrack = nil
        state = .idle
        processedItemIds.removeAll()
        localAssistantItemIds.removeAll()
    }

    func toggleMute() {
        guard let track = audioTrack else { return }
        if state == .muted {
            track.isEnabled = true
            state = .connected
        } else if state == .connected {
            track.isEnabled = false
            state = .muted
        }
    }

    /// Add a system/assistant message to the conversation (used for food pipeline responses)
    func addSystemMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(RealtimeMessage(isUser: false, text: trimmed))
    }

    /// Send text to OpenAI Realtime to be spoken aloud
    /// This injects a message into the conversation and triggers the assistant to speak it
    func speakText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Add to our local messages for display
        messages.append(RealtimeMessage(isUser: false, text: trimmed))

        // Send to OpenAI via data channel to be spoken
        guard let dataChannel = dataChannel, dataChannel.readyState == .open else {
            print("⚠️ Data channel not ready for sending text")
            return
        }

        // Create a conversation item with the text we want spoken
        let itemId = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(32))
        localAssistantItemIds.insert(itemId)
        let createItemEvent: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "id": itemId,
                "type": "message",
                "role": "assistant",
                "content": [
                    [
                        "type": "text",
                        "text": trimmed
                    ]
                ]
            ]
        ]

        // Send the item creation event
        if let jsonData = try? JSONSerialization.data(withJSONObject: createItemEvent),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Sending conversation.item.create: \(trimmed)")
            let buffer = RTCDataBuffer(data: jsonData, isBinary: false)
            dataChannel.sendData(buffer)
        }

        // Trigger response generation to speak the text
        let responseEvent: [String: Any] = [
            "type": "response.create",
            "response": [
                "output_modalities": ["audio"],
                "instructions": "Read the last message aloud exactly as written. Do not add any additional commentary."
            ]
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: responseEvent) {
            print("📤 Sending response.create to trigger speech")
            let buffer = RTCDataBuffer(data: jsonData, isBinary: false)
            dataChannel.sendData(buffer)
        }
    }

    private func fetchEphemeralKey() async throws -> String {
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            throw RealtimeError.noUserEmail
        }

        let baseUrl = NetworkManager().baseUrl
        guard let url = URL(string: "\(baseUrl)/agent/realtime-key/") else {
            throw RealtimeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["user_email": email])

        print("📡 [REALTIME] Fetching ephemeral key from \(url)")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ [REALTIME] Server returned status \(statusCode)")
            if let responseStr = String(data: data, encoding: .utf8) {
                print("❌ [REALTIME] Response body: \(responseStr.prefix(500))")
            }
            throw RealtimeError.serverError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RealtimeError.invalidResponse
        }

        print("📡 [REALTIME] Response keys: \(json.keys)")

        // GA API returns client_secret object with value field
        if let clientSecret = json["client_secret"] as? [String: Any],
           let value = clientSecret["value"] as? String {
            print("✅ [REALTIME] Got ephemeral key from client_secret.value")
            return value
        }

        // Fallback: direct value field (beta API format)
        if let value = json["value"] as? String {
            print("✅ [REALTIME] Got ephemeral key from value (beta format)")
            return value
        }

        print("❌ [REALTIME] Could not find ephemeral key in response: \(json)")
        throw RealtimeError.invalidResponse
    }

    private func setupPeerConnection() throws {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection = factory?.peerConnection(with: config, constraints: constraints, delegate: self)

        guard peerConnection != nil else {
            throw RealtimeError.connectionFailed
        }

        // Add audio track
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let audioSource = factory?.audioSource(with: audioConstraints) else {
            throw RealtimeError.audioSetupFailed
        }
        audioTrack = factory?.audioTrack(with: audioSource, trackId: "audio0")
        if let track = audioTrack {
            peerConnection?.add(track, streamIds: ["stream0"])
        }

        // Create data channel for events
        let dcConfig = RTCDataChannelConfiguration()
        dataChannel = peerConnection?.dataChannel(forLabel: "oai-events", configuration: dcConfig)
        dataChannel?.delegate = self
    }

    private func createOffer() async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            let constraints = RTCMediaConstraints(
                mandatoryConstraints: ["OfferToReceiveAudio": "true"],
                optionalConstraints: nil
            )
            peerConnection?.offer(for: constraints) { [weak self] sdp, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sdp = sdp else {
                    continuation.resume(throwing: RealtimeError.sdpFailed)
                    return
                }
                self?.peerConnection?.setLocalDescription(sdp) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: sdp)
                    }
                }
            }
        }
    }

    private func sendOfferToOpenAI(offer: RTCSessionDescription) async throws -> RTCSessionDescription {
        guard let key = ephemeralKey else {
            throw RealtimeError.noEphemeralKey
        }

        guard let url = URL(string: "https://api.openai.com/v1/realtime/calls") else {
            throw RealtimeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = offer.sdp.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw RealtimeError.sdpExchangeFailed
        }

        guard let sdpString = String(data: data, encoding: .utf8) else {
            throw RealtimeError.invalidResponse
        }

        return RTCSessionDescription(type: .answer, sdp: sdpString)
    }

    private func setRemoteDescription(answer: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peerConnection?.setRemoteDescription(answer) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - RTCPeerConnectionDelegate
extension RealtimeVoiceSession: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("🔄 Signaling state changed: \(stateChanged.rawValue)")
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("📥 Stream added with \(stream.audioTracks.count) audio tracks")
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("📤 Stream removed")
    }

    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("🤝 Should negotiate")
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("🧊 ICE connection state: \(newState.rawValue)")
        if newState == .failed || newState == .disconnected {
            Task { @MainActor in
                self.state = .error("Connection lost")
            }
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("🧊 ICE gathering state: \(newState.rawValue)")
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("🧊 ICE candidate generated")
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("🧊 ICE candidates removed")
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("📡 Data channel opened: \(dataChannel.label)")
    }
}

// MARK: - RTCDataChannelDelegate
extension RealtimeVoiceSession: RTCDataChannelDelegate {
    nonisolated func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("📡 Data channel state: \(dataChannel.readyState.rawValue)")
        if dataChannel.readyState == .open {
            // Request input audio transcription so we receive text events for user speech
            Task { @MainActor in
                self.sendSessionUpdate()
            }
        }
    }

    nonisolated func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        guard let json = try? JSONSerialization.jsonObject(with: buffer.data) as? [String: Any],
              let type = json["type"] as? String else {
            print("📨 Received non-JSON or malformed event")
            return
        }

        // Log ALL events with full content for debugging
        if type.contains("error") {
            print("❌ [REALTIME EVENT] \(type): \(json)")
        } else if type.contains("transcript") {
            // Log transcript events with full content to debug message display
            if let rawString = String(data: buffer.data, encoding: .utf8) {
                print("📨 [REALTIME TRANSCRIPT] \(type): \(rawString.prefix(500))")
            } else {
                print("📨 [REALTIME TRANSCRIPT] \(type): \(json)")
            }
        } else if type.contains("audio") {
            print("📨 [REALTIME EVENT] \(type)")
        } else {
            print("📨 [REALTIME EVENT] \(type): \(json.keys)")
        }

        // Handle tool/function call arguments
        if type == "response.function_call_arguments.done",
           let callId = json["call_id"] as? String,
           let name = json["name"] as? String,
           let arguments = json["arguments"] as? String {
            Task { @MainActor in
                self.isProcessing = true
                await self.handleToolCall(callId: callId, name: name, arguments: arguments)
            }
        }

        // Handle full conversation items (covers newer event types)
        if (type == "conversation.item.added" || type == "conversation.item.done"),
           let item = json["item"] as? [String: Any],
           let itemId = item["id"] as? String,
           let role = item["role"] as? String,
           let content = item["content"] as? [[String: Any]] {
            print("🗒️ [REALTIME ITEM] role=\(role) id=\(itemId) keys=\(item.keys.sorted()) contentKeys=\(content.map { $0.keys.joined(separator: ",") })")
            Task { @MainActor in
                guard !self.processedItemIds.contains(itemId) else { return }
                self.processedItemIds.insert(itemId)
                // If this is an echo of text we already inserted locally, skip to avoid duplicates.
                if self.localAssistantItemIds.contains(itemId) {
                    return
                }
                var extracted = Self.extractText(from: content)
                // Fallback: some event shapes include transcripts under input_audio_transcription
                if extracted.isEmpty,
                   let transcription = item["input_audio_transcription"] as? [String: Any],
                   let transcript = transcription["transcript"] as? String {
                    extracted = transcript
                }
                if !extracted.isEmpty {
                    print("📝 [REALTIME TEXT] role=\(role) text='\(extracted)'")
                }
                if !extracted.isEmpty {
                    let isUser = role == "user"
                    self.messages.append(RealtimeMessage(isUser: isUser, text: extracted))
                    if isUser {
                        self.transcribedText = extracted
                        self.currentUserText = ""
                        // Model auto-responds via create_response: true in turn_detection
                    } else {
                        self.currentAssistantText = ""
                    }
                }
            }
        }

        // Handle user input transcription streaming (legacy event names)
        if type == "conversation.item.input_audio_transcription.delta",
           let delta = json["delta"] as? String {
            Task { @MainActor in
                self.currentUserText += delta
            }
        }

        // Handle user input transcription completed
        if type == "conversation.item.input_audio_transcription.completed",
           let transcript = json["transcript"] as? String {
            Task { @MainActor in
                let finalText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🎤 [USER TRANSCRIPT] '\(finalText)'")
                if !finalText.isEmpty {
                    self.messages.append(RealtimeMessage(isUser: true, text: finalText))
                    print("✅ [MESSAGES] Added user message, count now: \(self.messages.count)")
                    self.transcribedText = finalText
                }
                self.currentUserText = ""
            }
        }

        // Handle assistant response streaming
        if type == "response.audio_transcript.delta",
           let delta = json["delta"] as? String {
            Task { @MainActor in
                self.isProcessing = false
                self.currentAssistantText += delta
            }
        }

        // Handle assistant response completed
        if type == "response.audio_transcript.done",
           let transcript = json["transcript"] as? String {
            Task { @MainActor in
                let finalText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !finalText.isEmpty {
                    self.messages.append(RealtimeMessage(isUser: false, text: finalText))
                }
                self.currentAssistantText = ""
            }
        }

        // Fallback for output audio transcript events
        if type == "response.output_audio_transcript.delta",
           let delta = json["delta"] as? String {
            Task { @MainActor in
                self.isProcessing = false
                self.currentAssistantText += delta
            }
        }

        if type == "response.output_audio_transcript.done",
           let transcript = json["transcript"] as? String {
            Task { @MainActor in
                let finalText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !finalText.isEmpty {
                    self.messages.append(RealtimeMessage(isUser: false, text: finalText))
                }
                self.currentAssistantText = ""
            }
        }
    }
}

enum RealtimeError: LocalizedError {
    case noUserEmail
    case invalidURL
    case invalidResponse
    case serverError
    case sdpFailed
    case sdpExchangeFailed
    case connectionFailed
    case audioSetupFailed
    case noEphemeralKey

    var errorDescription: String? {
        switch self {
        case .noUserEmail:
            return "No user email found"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError:
            return "Server error"
        case .sdpFailed:
            return "Failed to create SDP offer"
        case .sdpExchangeFailed:
            return "Failed to exchange SDP with OpenAI"
        case .connectionFailed:
            return "Failed to create peer connection"
        case .audioSetupFailed:
            return "Failed to setup audio"
        case .noEphemeralKey:
            return "No ephemeral key available"
        }
    }
}

private extension RealtimeVoiceSession {
    func handleToolCall(callId: String, name: String, arguments: String) async {
        guard name == "log_food" else { return }
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = args["query"] as? String else {
            sendToolResult(callId: callId, resultJSON: ["status": "error", "error": "Invalid arguments"])
            return
        }
        let nixItemId = args["nix_item_id"] as? String
        let selectionLabel = args["selection_label"] as? String

        // Always return a tool result to avoid hanging the model
        guard let delegate = delegate else {
            sendToolResult(callId: callId, resultJSON: ["status": "error", "error": "No delegate available"])
            return
        }

        delegate.realtimeSession(
            self,
            didRequestFoodLookup: query,
            nixItemId: nixItemId,
            selectionLabel: selectionLabel
        ) { [weak self] result in
            guard let self else {
                return
            }
            sendToolResult(callId: callId, resultJSON: result.toJSON())
            if result.status == .success, let food = result.food {
                delegate.realtimeSession(self, didResolveFood: food, mealItems: result.mealItems)
            }
        }
    }

    func sendToolResult(callId: String, resultJSON: [String: Any]) {
        guard let dataChannel = dataChannel, dataChannel.readyState == .open else { return }
        guard let outputData = try? JSONSerialization.data(withJSONObject: resultJSON),
              let outputString = String(data: outputData, encoding: .utf8) else {
            return
        }

        let itemEvent: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "function_call_output",
                "call_id": callId,
                "output": outputString
            ]
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: itemEvent) {
            let buffer = RTCDataBuffer(data: jsonData, isBinary: false)
            dataChannel.sendData(buffer)
            print("📤 [REALTIME] Sent function_call_output for \(callId)")
        }

        // Ask the model to respond using the tool result
        sendResponseCreate()
    }

    func sendResponseCreate() {
        guard let dataChannel = dataChannel, dataChannel.readyState == .open else { return }
        let responseEvent: [String: Any] = [
            "type": "response.create"
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: responseEvent) {
            let buffer = RTCDataBuffer(data: jsonData, isBinary: false)
            dataChannel.sendData(buffer)
        }
    }

    /// Configure the realtime session for food logging with tool calling.
    /// Called when the data channel opens.
    func sendSessionUpdate() {
        guard let dataChannel = dataChannel, dataChannel.readyState == .open else { return }

        let instructions = """
            You are a voice assistant for a food logging app called Metryc.
            When the user mentions food they ate, call the log_food tool with their COMPLETE description.
            IMPORTANT: If the user mentions multiple foods (e.g., "pizza, hotdog, and a coke"), call log_food ONCE with ALL foods in a single query like "pizza, hotdog, and a coke". Do NOT make separate calls for each food.
            If the tool returns options (status='needsClarification'), list them naturally without saying 'Option A/B/C'. Instead say something like:
            'I found a few options: NAME by BRAND, about CALORIES calories. Or NAME by BRAND, about CALORIES calories. Which one?'
            Keep the list clean and conversational, like you would naturally speak.
            When the user indicates their choice (saying 'the first one', 'the second', 'A', 'B', etc.), call log_food again with selection_label set to their choice (A for first, B for second, C for third).
            When the tool returns success with multiple items, confirm naturally: 'Got it, I logged pizza, hotdog, and coke.'
            When the tool returns success with a single item, confirm naturally: 'Got it, logged NAME at CALORIES calories.'
            If the tool returns an error, apologize briefly and ask them to try again.
            Keep responses brief and conversational.
            """

        let update: [String: Any] = [
            "type": "session.update",
            "session": [
                "type": "realtime",
                "model": "gpt-realtime",
                "output_modalities": ["audio"],
                "instructions": instructions,
                "tool_choice": "auto",
                "tools": [
                    [
                        "type": "function",
                        "name": "log_food",
                        "description": "Look up and log nutrition info for food the user mentions eating. Call this whenever user mentions food they ate or want to log.",
                        "parameters": [
                            "type": "object",
                            "properties": [
                                "query": [
                                    "type": "string",
                                    "description": "Natural language food description from the user"
                                ],
                                "nix_item_id": [
                                    "type": "string",
                                    "description": "Nutritionix item ID to select a specific option"
                                ],
                                "selection_label": [
                                    "type": "string",
                                    "description": "Option label (A/B/C) when user picks from choices"
                                ]
                            ],
                            "required": ["query"]
                        ]
                    ]
                ],
                "audio": [
                    "input": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24000
                        ],
                        "turn_detection": [
                            "type": "semantic_vad",
                            "create_response": true,
                            "interrupt_response": true
                        ],
                        "transcription": [
                            "model": "gpt-4o-transcribe"
                        ]
                    ],
                    "output": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24000
                        ],
                        "voice": "marin"
                    ]
                ]
            ]
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: update) {
            let buffer = RTCDataBuffer(data: jsonData, isBinary: false)
            dataChannel.sendData(buffer)
            print("📤 [REALTIME] Sent session.update with tools and auto-response enabled")
        } else {
            print("❌ [REALTIME] Failed to encode session.update payload")
        }
    }

    /// Extract any textual content from a realtime content array.
    /// Supports both `text` and `transcript` fields as returned by the API.
    static func extractText(from content: [[String: Any]]) -> String {
        var parts: [String] = []
        for piece in content {
            if let text = piece["text"] as? String {
                parts.append(text)
            } else if let transcript = piece["transcript"] as? String {
                parts.append(transcript)
            } else if let outputText = piece["output_text"] as? String {
                parts.append(outputText)
            } else if let audio = piece["audio"] as? [String: Any],
                      let transcript = audio["transcript"] as? String {
                parts.append(transcript)
            }
        }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

protocol RealtimeVoiceSessionDelegate {
    func realtimeSession(_ session: RealtimeVoiceSession,
                         didRequestFoodLookup query: String,
                         nixItemId: String?,
                         selectionLabel: String?,
                         completion: @escaping (ToolResult) -> Void)
    func realtimeSession(_ session: RealtimeVoiceSession, didResolveFood food: Food, mealItems: [MealItem]?)
}

struct ToolResult {
    enum Status: String {
        case success
        case needsClarification
        case error
    }
    let status: Status
    let food: Food?
    let mealItems: [MealItem]?
    let question: String?
    let options: [ClarificationOption]?
    let error: String?

    func toJSON() -> [String: Any] {
        var dict: [String: Any] = ["status": status.rawValue]
        if let food = food {
            dict["food"] = [
                "name": food.displayName,
                "calories": food.calories ?? 0,
                "protein": food.protein ?? 0,
                "carbs": food.carbs ?? 0,
                "fat": food.fat ?? 0,
                "serving": food.servingSizeText
            ]
        }
        if let items = mealItems, !items.isEmpty {
            dict["meal_items"] = items.map { item in
                [
                    "name": item.name,
                    "calories": item.calories ?? 0
                ]
            }
            dict["item_count"] = items.count
        }
        if let question = question {
            dict["question"] = question
        }
        if let options = options {
            dict["options"] = options.map { opt in
                [
                    "label": opt.label ?? "",
                    "name": opt.name ?? "",
                    "brand": opt.brand ?? "",
                    "serving": opt.serving ?? "",
                    "preview_calories": opt.previewCalories ?? Double(0),
                    "nix_item_id": opt.nixItemId ?? ""
                ] as [String: Any]
            }
        }
        if let error = error {
            dict["error"] = error
        }
        return dict
    }
}
