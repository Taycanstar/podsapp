//
//  AgentTabBar.swift
//  pods
//
//  Created by Dimi Nunez on 10/27/25.
//

import SwiftUI
import UIKit

struct AgentTabBar: View {
    @Binding var text: String
    var isPromptFocused: FocusState<Bool>.Binding
    var onPlusTapped: () -> Void = {}
    var onBarcodeTapped: () -> Void = {}
    var onMicrophoneTapped: () -> Void = {}
    var onWaveformTapped: () -> Void = {}
    var onSubmit: () -> Void = {}

    // Attachment menu callbacks
    var onFilesTapped: (() -> Void)?
    var onCameraTapped: (() -> Void)?
    var onPhotosTapped: (() -> Void)?

    // Attachments binding for thumbnail strip
    @Binding var attachments: [ChatAttachment]

    // Realtime voice session properties
    var realtimeState: RealtimeSessionState = .idle
    var onRealtimeStart: (() -> Void)?
    var onRealtimeEnd: (() -> Void)?
    var onMuteToggle: (() -> Void)?

    @State private var isListening = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var isSendingMessage = false
    @State private var sendPulseScale: CGFloat = 1.0
    @StateObject private var speechRecognizer = SpeechRecognizer()

    var body: some View {
        VStack(spacing: 0) {
            TransparentBlurView(removeAllFilters: true)
                .blur(radius: 14)
                .frame(height:10)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

            contentCard
        }
        .background(
            TransparentBlurView(removeAllFilters: true)
                .blur(radius: 14)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
        )
    }

    private var contentCard: some View {
        let hasUserInput = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            // Attachment thumbnail strip (shown when attachments exist)
            if !attachments.isEmpty {
                AttachmentThumbnailStrip(attachments: $attachments)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            ZStack(alignment: .topLeading) {
                // Placeholder text
                if text.isEmpty {
                    Text("Log or ask anything...")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .tint(Color.accentColor) // ensure visible caret color
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(maxHeight: 120)
                    .fixedSize(horizontal: false, vertical: true)
                    .focused(isPromptFocused)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isPromptFocused.wrappedValue = true
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                HStack(spacing: 10) {
                    ActionCircleButton(
                        systemName: "plus",
                        action: onPlusTapped,
                        backgroundColor: Color.accentColor,
                        foregroundColor: .white
                    )

                    ActionCircleButton(
                        systemName: "barcode.viewfinder",
                        action: onBarcodeTapped
                    )

                    // Paperclip attachment menu
                    attachmentMenuButton
                }

                Spacer()

                rightButtons(hasUserInput: hasUserInput)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color("chat"))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, -12)
        .padding(.bottom, isPromptFocused.wrappedValue ? 10 : 0)
        .onChange(of: speechRecognizer.transcript) { newTranscript in
            if !newTranscript.isEmpty {
                text = newTranscript
            }
        }
        .onChange(of: isListening) { listening in
            if listening {
                speechRecognizer.startRecording()
                pulseScale = 1.2
            } else {
                speechRecognizer.stopRecording()
                pulseScale = 1.0
            }
        }
        .onDisappear {
            if isListening {
                isListening = false
                speechRecognizer.stopRecording()
            }
        }
        // .padding(.bottom, 12)
    }

    private func toggleSpeechRecognition() {
        isListening.toggle()
    }

    // MARK: - Attachment Menu

    private var attachmentMenuButton: some View {
        Menu {
            Button {
                HapticFeedback.generate()
                onFilesTapped?()
            } label: {
                Label("Files", systemImage: "doc")
            }

            Button {
                HapticFeedback.generate()
                onCameraTapped?()
            } label: {
                Label("Camera", systemImage: "camera")
            }

            Button {
                HapticFeedback.generate()
                onPhotosTapped?()
            } label: {
                Label("Photos", systemImage: "photo")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color("chaticon"))
                Image(systemName: "paperclip")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(width: 30, height: 30)
        }
    }

    private func submitAgentPrompt() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        text = trimmed
        HapticFeedback.generate()

        // Start pulsing animation immediately for visual feedback
        isSendingMessage = true
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            sendPulseScale = 1.15
        }

        // Navigate optimistically - don't wait for API
        onWaveformTapped()
        text = ""
        isPromptFocused.wrappedValue = false

        // Reset pulse state after a brief moment (animation continues in AgentChatView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.1)) {
                sendPulseScale = 1.0
            }
            isSendingMessage = false
        }
    }

    @ViewBuilder
    private func rightButtons(hasUserInput: Bool) -> some View {
        switch realtimeState {
        case .connecting:
            Button {
                HapticFeedback.generate()
                onRealtimeEnd?()
            } label: {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white })))
                        .scaleEffect(0.8)
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white }))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(UIColor { $0.userInterfaceStyle == .dark ? .white : .black }))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

        case .connected, .muted:
            HStack(spacing: 10) {
                // Mic toggle button
                ActionCircleButton(
                    systemName: realtimeState == .muted ? "mic.slash.fill" : "mic.fill",
                    action: {
                        HapticFeedback.generate()
                        onMuteToggle?()
                    },
                    backgroundColor: realtimeState == .muted ? .red : Color("chaticon"),
                    foregroundColor: realtimeState == .muted ? .white : .primary
                )

                // End button with animated waveform
                Button(action: {
                    HapticFeedback.generate()
                    onRealtimeEnd?()
                }) {
                    HStack(spacing: 6) {
                        AnimatedWaveform()
                            .frame(width: 20, height: 16)
                        Text("End")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

        default: // .idle, .error
            if isListening {
                Button {
                    HapticFeedback.generate()
                    toggleSpeechRecognition()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .scaleEffect(pulseScale)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    ActionCircleButton(
                        systemName: "mic",
                        action: {
                            HapticFeedback.generate()
                            toggleSpeechRecognition()
                        },
                        backgroundColor: Color("chaticon"),
                        foregroundColor: .primary
                    )

                    ActionCircleButton(
                        systemName: hasUserInput ? "arrow.up" : "waveform",
                        action: {
                            if hasUserInput {
                                submitAgentPrompt()
                            } else {
                                HapticFeedback.generate()
                                onRealtimeStart?()
                            }
                        },
                        backgroundColor: hasUserInput ? Color.accentColor : Color("chaticon"),
                        foregroundColor: hasUserInput ? .white : .primary
                    )
                    .scaleEffect(isSendingMessage ? sendPulseScale : 1.0)
                }
            }
        }
    }

    private var borderColor: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.20)
            : UIColor.black.withAlphaComponent(0.08)
        })
    }
}

private struct ActionCircleButton: View {
    var systemName: String
    var action: () -> Void
    var backgroundColor: Color = Color("chaticon")
    var foregroundColor: Color = .primary
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(foregroundColor)
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }
}

struct AgentTabBar_Previews: PreviewProvider {
    static var previews: some View {
        AgentTabBarPreview()
            .padding()
            .background(Color(.systemGroupedBackground))
            .previewLayout(.sizeThatFits)
    }
}

private struct TransparentBlurView: UIViewRepresentable {
    var removeAllFilters: Bool = false

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        DispatchQueue.main.async {
            guard let backdropLayer = uiView.layer.sublayers?.first else { return }

            if removeAllFilters {
                backdropLayer.filters = []
            } else {
                backdropLayer.filters?.removeAll { filter in
                    String(describing: filter) != "gaussianBlur"
                }
            }
        }
    }
}

private struct AgentTabBarPreview: View {
    @State private var prompt: String = ""
    @State private var attachments: [ChatAttachment] = []
    @FocusState private var isFocused: Bool

    var body: some View {
        AgentTabBar(text: $prompt, isPromptFocused: $isFocused, attachments: $attachments)
    }
}

struct AnimatedWaveform: View {
    @State private var heights: [CGFloat] = Array(repeating: 4, count: 5)
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 3, height: heights[index])
            }
        }
        .onAppear { startAnimation() }
        .onDisappear { stopAnimation() }
    }

    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                heights = (0..<5).map { _ in CGFloat.random(in: 4...16) }
            }
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}
