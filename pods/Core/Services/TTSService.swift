//
//  TTSService.swift
//  pods
//
//  Created by Dimi Nunez on 12/31/25.
//


//
//  TTSService.swift
//  pods
//
//  Created by Claude on 12/9/25.
//

import AVFoundation

@MainActor
class TTSService: NSObject, ObservableObject {
    static let shared = TTSService()

    @Published var isSpeaking = false
    @Published var isLoading = false

    private var audioPlayer: AVAudioPlayer?
    private let networkManager = NetworkManager()

    // Fallback synthesizer for when OpenAI TTS fails
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
    }

    /// Speak text using OpenAI TTS API via backend
    /// Falls back to system TTS if API fails
    func speak(_ text: String, voice: String = "marin") {
        // Stop any current playback
        stop()

        guard !text.isEmpty else { return }

        isLoading = true
        isSpeaking = true

        Task {
            do {
                let audioData = try await fetchTTSAudio(text: text, voice: voice)
                await playAudio(data: audioData)
            } catch {
                print("❌ TTSService: OpenAI TTS failed, falling back to system TTS: \(error)")
                await fallbackToSystemTTS(text)
            }
            isLoading = false
        }
    }

    /// Stop any current speech
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isLoading = false
    }

    // MARK: - Private Methods

    private func fetchTTSAudio(text: String, voice: String) async throws -> Data {
        let baseURL = NetworkManager.baseURL
        let url = URL(string: "\(baseURL)/agent/tts/")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "voice": voice
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TTSError.serverError(httpResponse.statusCode)
        }

        guard !data.isEmpty else {
            throw TTSError.emptyData
        }

        return data
    }

    private func playAudio(data: Data) async {
        do {
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)

            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            print("🔊 TTSService: Playing OpenAI TTS audio (\(data.count) bytes)")
        } catch {
            print("❌ TTSService: Failed to play audio: \(error)")
            isSpeaking = false
        }
    }

    private func fallbackToSystemTTS(_ text: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
    }
}

// MARK: - AVAudioPlayerDelegate

extension TTSService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isSpeaking = false
            self.audioPlayer = nil

            // Deactivate audio session
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("❌ TTSService: Audio decode error: \(error?.localizedDescription ?? "unknown")")
            self.isSpeaking = false
            self.audioPlayer = nil
        }
    }
}

// MARK: - Error Types

enum TTSError: Error {
    case invalidResponse
    case serverError(Int)
    case emptyData

    var localizedDescription: String {
        switch self {
        case .invalidResponse:
            return "Invalid response from TTS server"
        case .serverError(let code):
            return "TTS server error: \(code)"
        case .emptyData:
            return "TTS server returned empty audio data"
        }
    }
}
