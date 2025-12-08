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

    // Streaming text for live display
    @Published var currentUserText: String = ""
    @Published var currentAssistantText: String = ""

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

        // 1. Get ephemeral key from backend
        ephemeralKey = try await fetchEphemeralKey()

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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RealtimeError.serverError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json["value"] as? String else {
            throw RealtimeError.invalidResponse
        }
        return value
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
        print("📥 Stream added")
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
    }

    nonisolated func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        guard let json = try? JSONSerialization.jsonObject(with: buffer.data) as? [String: Any],
              let type = json["type"] as? String else { return }

        print("📨 Received event: \(type)")

        // Handle user input transcription streaming
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
                if !finalText.isEmpty {
                    self.messages.append(RealtimeMessage(isUser: true, text: finalText))
                    self.transcribedText = finalText
                }
                self.currentUserText = ""
            }
        }

        // Handle assistant response streaming
        if type == "response.audio_transcript.delta",
           let delta = json["delta"] as? String {
            Task { @MainActor in
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
