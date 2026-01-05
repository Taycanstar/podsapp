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

    // Conversation persistence
    @Published var currentConversationId: String?
    var onConversationIdUpdated: ((String) -> Void)?

    // Analytics tracking state
    private var userMessageIndex: Int = 0
    private var coachMessageIndex: Int = 0
    private var lastUserMessageId: String?
    private var lastSendTime: Date?
    var screenName: String = "voice_mode"

    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var audioTrack: RTCAudioTrack?
    private var ephemeralKey: String?
    private var factory: RTCPeerConnectionFactory?
    private let networkManager = NetworkManager()

    override init() {
        super.init()
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
    }

    /// Initialize with an existing conversation ID (for resuming conversations)
    init(conversationId: String?) {
        super.init()
        self.currentConversationId = conversationId
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

        // Reset analytics state
        userMessageIndex = 0
        coachMessageIndex = 0
        lastUserMessageId = nil
        lastSendTime = nil
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
        } else if type.contains("transcript") || type.contains("input_audio") || type.contains("speech") {
            // Log transcript and input audio events with full content to debug message display
            if let rawString = String(data: buffer.data, encoding: .utf8) {
                print("📨 [REALTIME TRANSCRIPT/INPUT] \(type): \(rawString.prefix(800))")
            } else {
                print("📨 [REALTIME TRANSCRIPT/INPUT] \(type): \(json)")
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
           let role = item["role"] as? String {
            let content = item["content"] as? [[String: Any]] ?? []
            print("🗒️ [REALTIME ITEM] role=\(role) id=\(itemId) keys=\(item.keys.sorted()) contentKeys=\(content.map { $0.keys.joined(separator: ",") })")

            // Extract text from content array
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

            Task { @MainActor in
                let isUser = role == "user"

                // For user messages, show in currentUserText bubble first
                if isUser && !extracted.isEmpty {
                    self.currentUserText = extracted
                    print("🎤 [USER BUBBLE] Showing: '\(extracted)'")
                }

                // Only add to messages array once (avoid duplicates)
                guard !self.processedItemIds.contains(itemId) else { return }
                self.processedItemIds.insert(itemId)

                // If this is an echo of text we already inserted locally, skip to avoid duplicates.
                if self.localAssistantItemIds.contains(itemId) {
                    return
                }

                if !extracted.isEmpty {
                    self.messages.append(RealtimeMessage(isUser: isUser, text: extracted))
                    if isUser {
                        self.transcribedText = extracted
                        // Clear the streaming bubble after adding to messages
                        // Use slight delay so user sees the bubble before it moves to messages
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.currentUserText = ""
                        }
                    } else {
                        self.currentAssistantText = ""
                    }
                }
            }
        }

        // Handle speech started - clear previous user text
        if type == "input_audio_buffer.speech_started" {
            print("🎤 [SPEECH STARTED]")
            Task { @MainActor in
                self.currentUserText = ""
            }
        }

        // Handle speech stopped
        if type == "input_audio_buffer.speech_stopped" {
            print("🎤 [SPEECH STOPPED]")
        }

        // Handle user input transcription streaming (per OpenAI docs)
        // Event: conversation.item.input_audio_transcription.delta
        // JSON: { "delta": "Hello," }
        if type == "conversation.item.input_audio_transcription.delta" {
            if let delta = json["delta"] as? String, !delta.isEmpty {
                print("🎤 [USER STREAMING] delta: '\(delta)'")
                Task { @MainActor in
                    self.currentUserText += delta
                }
            }
        }

        // Handle user input transcription completed (per OpenAI docs)
        // Event: conversation.item.input_audio_transcription.completed
        // JSON: { "transcript": "Hello, how are you?" }
        if type == "conversation.item.input_audio_transcription.completed" {
            if let transcript = json["transcript"] as? String {
                let finalText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🎤 [USER TRANSCRIPT COMPLETED] '\(finalText)'")
                Task { @MainActor in
                    if !finalText.isEmpty {
                        // Track user_message_sent for voice
                        self.userMessageIndex += 1
                        let messageId = UUID().uuidString
                        self.lastUserMessageId = messageId
                        self.lastSendTime = Date()

                        AnalyticsManager.shared.trackUserMessageSent(
                            conversationId: self.currentConversationId,
                            messageId: messageId,
                            messageIndex: self.userMessageIndex,
                            inputMethod: "voice",
                            triggerSource: "user_tap",
                            textLengthChars: finalText.count,
                            transcriptionSuccess: true,
                            screenName: self.screenName
                        )

                        self.messages.append(RealtimeMessage(isUser: true, text: finalText))
                        print("✅ [MESSAGES] Added user message, count now: \(self.messages.count)")
                        self.transcribedText = finalText
                        // Persist user message to conversation
                        self.persistVoiceMessage(role: "user", content: finalText)
                    }
                    self.currentUserText = ""
                }
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
                    // Track coach_message_shown for voice
                    self.coachMessageIndex += 1
                    let coachMessageId = UUID().uuidString
                    let responseLatencyMs: Int
                    if let sendTime = self.lastSendTime {
                        responseLatencyMs = Int(Date().timeIntervalSince(sendTime) * 1000)
                    } else {
                        responseLatencyMs = 0
                    }
                    AnalyticsManager.shared.trackCoachMessageShown(
                        conversationId: self.currentConversationId,
                        coachMessageId: coachMessageId,
                        coachMessageIndex: self.coachMessageIndex,
                        inReplyToMessageId: self.lastUserMessageId,
                        responseLatencyMs: responseLatencyMs
                    )

                    self.messages.append(RealtimeMessage(isUser: false, text: finalText))
                    // Persist assistant message to conversation
                    self.persistVoiceMessage(role: "assistant", content: finalText)
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
                    // Track coach_message_shown for voice (fallback handler)
                    self.coachMessageIndex += 1
                    let coachMessageId = UUID().uuidString
                    let responseLatencyMs: Int
                    if let sendTime = self.lastSendTime {
                        responseLatencyMs = Int(Date().timeIntervalSince(sendTime) * 1000)
                    } else {
                        responseLatencyMs = 0
                    }
                    AnalyticsManager.shared.trackCoachMessageShown(
                        conversationId: self.currentConversationId,
                        coachMessageId: coachMessageId,
                        coachMessageIndex: self.coachMessageIndex,
                        inReplyToMessageId: self.lastUserMessageId,
                        responseLatencyMs: responseLatencyMs
                    )

                    self.messages.append(RealtimeMessage(isUser: false, text: finalText))
                    // Persist assistant message to conversation
                    self.persistVoiceMessage(role: "assistant", content: finalText)
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
        print("🎤 [TOOL CALL] name=\(name) arguments=\(arguments)")

        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            sendToolResult(callId: callId, resultJSON: ["status": "error", "error": "Invalid arguments"])
            return
        }

        guard let delegate = delegate else {
            sendToolResult(callId: callId, resultJSON: ["status": "error", "error": "No delegate available"])
            return
        }

        // Route to appropriate tool handler
        switch name {
        case "log_food":
            handleLogFoodTool(callId: callId, args: args, delegate: delegate)
        case "log_activity":
            handleLogActivityTool(callId: callId, args: args, delegate: delegate)
        case "query_nutrition":
            handleQueryTool(callId: callId, queryType: .nutrition, args: args, delegate: delegate)
        case "query_workout":
            handleQueryTool(callId: callId, queryType: .workout, args: args, delegate: delegate)
        case "query_health_metrics":
            handleQueryTool(callId: callId, queryType: .healthMetrics, args: args, delegate: delegate)
        case "query_goals":
            handleQueryTool(callId: callId, queryType: .goals, args: args, delegate: delegate)
        case "query_user_profile":
            handleQueryTool(callId: callId, queryType: .userProfile, args: args, delegate: delegate)
        case "update_goals":
            handleUpdateGoalsTool(callId: callId, args: args, delegate: delegate)
        default:
            print("⚠️ [TOOL CALL] Unknown tool: \(name)")
            sendToolResult(callId: callId, resultJSON: ["status": "error", "error": "Unknown tool: \(name)"])
        }
    }

    // MARK: - Individual Tool Handlers

    func handleLogFoodTool(callId: String, args: [String: Any], delegate: RealtimeVoiceSessionDelegate) {
        guard let query = args["query"] as? String else {
            sendToolResult(callId: callId, resultJSON: ["status": "error", "error": "Missing required 'query' parameter"])
            return
        }

        let isBranded = args["is_branded"] as? Bool ?? false
        let brandName = args["brand_name"] as? String
        let nixItemId = args["nix_item_id"] as? String
        let selectionLabel = args["selection_label"] as? String

        print("🎤 [LOG_FOOD] query='\(query)' is_branded=\(isBranded) brand='\(brandName ?? "")'")

        delegate.realtimeSession(
            self,
            didRequestFoodLookup: query,
            isBranded: isBranded,
            brandName: brandName,
            nixItemId: nixItemId,
            selectionLabel: selectionLabel
        ) { [weak self] result in
            guard let self else { return }
            sendToolResult(callId: callId, resultJSON: result.toJSON())
            if result.status == .success, let food = result.food {
                delegate.realtimeSession(self, didResolveFood: food, mealItems: result.mealItems)
            }
        }
    }

    func handleLogActivityTool(callId: String, args: [String: Any], delegate: RealtimeVoiceSessionDelegate) {
        let activityName = args["activity_name"] as? String ?? "Activity"
        let activityType = args["activity_type"] as? String
        let durationMinutes = args["duration_minutes"] as? Int ?? 30
        let caloriesBurned = args["calories_burned"] as? Int
        let notes = args["notes"] as? String

        print("🎤 [LOG_ACTIVITY] name='\(activityName)' type=\(activityType ?? "nil") duration=\(durationMinutes)min")

        delegate.realtimeSession(
            self,
            didRequestActivityLog: activityName,
            activityType: activityType,
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned,
            notes: notes
        ) { [weak self] result in
            guard let self else { return }
            sendToolResult(callId: callId, resultJSON: result.toJSON())
        }
    }

    func handleQueryTool(callId: String, queryType: VoiceQueryType, args: [String: Any], delegate: RealtimeVoiceSessionDelegate) {
        print("🎤 [QUERY] type=\(queryType.rawValue) args=\(args)")

        delegate.realtimeSession(
            self,
            didRequestQuery: queryType,
            args: args
        ) { [weak self] result in
            guard let self else { return }
            sendToolResult(callId: callId, resultJSON: result.toJSON())
        }
    }

    func handleUpdateGoalsTool(callId: String, args: [String: Any], delegate: RealtimeVoiceSessionDelegate) {
        var goalUpdates: [String: Int] = [:]
        if let calories = args["calories"] as? Int { goalUpdates["calories"] = calories }
        if let protein = args["protein"] as? Int { goalUpdates["protein"] = protein }
        if let carbs = args["carbs"] as? Int { goalUpdates["carbs"] = carbs }
        if let fat = args["fat"] as? Int { goalUpdates["fat"] = fat }
        if let water = args["water"] as? Int { goalUpdates["water"] = water }
        if let steps = args["steps"] as? Int { goalUpdates["steps"] = steps }

        guard !goalUpdates.isEmpty else {
            sendToolResult(callId: callId, resultJSON: ["status": "error", "error": "No valid goals provided"])
            return
        }

        print("🎤 [UPDATE_GOALS] updates=\(goalUpdates)")

        delegate.realtimeSession(
            self,
            didRequestGoalUpdate: goalUpdates
        ) { [weak self] result in
            guard let self else { return }
            sendToolResult(callId: callId, resultJSON: result.toJSON())
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

    /// Configure the realtime session audio settings.
    /// Called when the data channel opens.
    /// Note: Tools and instructions are now provided by the backend via the ephemeral key.
    func sendSessionUpdate() {
        guard let dataChannel = dataChannel, dataChannel.readyState == .open else { return }

        // Session config per OpenAI Realtime API docs for CONVERSATION mode
        // Transcription goes under audio.input.transcription (NOT input_audio_transcription)
        let update: [String: Any] = [
            "type": "session.update",
            "session": [
                "type": "realtime",
                "audio": [
                    "input": [
                        "transcription": [
                            "model": "gpt-4o-transcribe"
                        ]
                    ]
                ]
            ]
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: update) {
            let buffer = RTCDataBuffer(data: jsonData, isBinary: false)
            dataChannel.sendData(buffer)
            print("📤 [REALTIME] Sent session.update with type=realtime and audio.input.transcription")
        } else {
            print("❌ [REALTIME] Failed to encode session.update payload")
        }
    }

    /// Extract any textual content from a realtime content array.
    /// Supports both `text` and `transcript` fields as returned by the API.
    nonisolated static func extractText(from content: [[String: Any]]) -> String {
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

    // MARK: - Conversation Persistence

    /// Persist a voice message to the backend conversation
    /// Creates a new conversation if none exists
    func persistVoiceMessage(role: String, content: String, responseType: String? = nil) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        guard let email = UserDefaults.standard.string(forKey: "userEmail"), !email.isEmpty else {
            print("⚠️ [VOICE] Cannot persist message: No user email")
            return
        }

        Task {
            do {
                // If no conversation exists, create one first
                if currentConversationId == nil {
                    let newConversation = try await networkManager.createConversation(
                        userEmail: email,
                        title: nil // Will be auto-generated from first message
                    )
                    currentConversationId = newConversation.id
                    onConversationIdUpdated?(newConversation.id)
                    print("✅ [VOICE] Created new conversation: \(newConversation.id)")
                }

                // Now save the message
                guard let conversationId = currentConversationId else { return }

                _ = try await networkManager.addConversationMessage(
                    conversationId: conversationId,
                    userEmail: email,
                    role: role,
                    content: trimmedContent,
                    responseType: responseType
                )
                print("✅ [VOICE] Persisted \(role) message to conversation \(conversationId)")
            } catch {
                print("❌ [VOICE] Failed to persist message: \(error)")
            }
        }
    }
}

/// Query types for voice mode data queries
enum VoiceQueryType: String {
    case nutrition = "query_nutrition"
    case workout = "query_workout"
    case healthMetrics = "query_health_metrics"
    case goals = "query_goals"
    case userProfile = "query_user_profile"
}

/// Generic result for voice tool calls (non-food tools)
struct VoiceToolResult {
    let success: Bool
    let type: String
    let data: [String: Any]?
    let error: String?

    func toJSON() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if success {
            dict["status"] = "success"
            if let data = data {
                dict["data"] = data
            }
        } else {
            dict["status"] = "error"
            dict["error"] = error ?? "Unknown error"
        }
        return dict
    }

    static func success(type: String, data: [String: Any]? = nil) -> VoiceToolResult {
        VoiceToolResult(success: true, type: type, data: data, error: nil)
    }

    static func failure(error: String) -> VoiceToolResult {
        VoiceToolResult(success: false, type: "error", data: nil, error: error)
    }
}

protocol RealtimeVoiceSessionDelegate {
    // MARK: - Food Logging (existing)
    func realtimeSession(_ session: RealtimeVoiceSession,
                         didRequestFoodLookup query: String,
                         isBranded: Bool,
                         brandName: String?,
                         nixItemId: String?,
                         selectionLabel: String?,
                         completion: @escaping (ToolResult) -> Void)
    func realtimeSession(_ session: RealtimeVoiceSession, didResolveFood food: Food, mealItems: [MealItem]?)

    // MARK: - Activity Logging (new)
    func realtimeSession(_ session: RealtimeVoiceSession,
                         didRequestActivityLog activityName: String,
                         activityType: String?,
                         durationMinutes: Int,
                         caloriesBurned: Int?,
                         notes: String?,
                         completion: @escaping (VoiceToolResult) -> Void)

    // MARK: - Data Queries (new)
    func realtimeSession(_ session: RealtimeVoiceSession,
                         didRequestQuery queryType: VoiceQueryType,
                         args: [String: Any],
                         completion: @escaping (VoiceToolResult) -> Void)

    // MARK: - Goal Updates (new)
    func realtimeSession(_ session: RealtimeVoiceSession,
                         didRequestGoalUpdate goals: [String: Int],
                         completion: @escaping (VoiceToolResult) -> Void)
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
