//
//  AgentTabBarMinimal.swift
//  pods
//
//  Created by Dimi Nunez on 12/8/25.
//


import SwiftUI
import UIKit

struct AgentTabBarMinimal: View {
    @Binding var text: String
    var isPromptFocused: FocusState<Bool>.Binding
    var placeholder: String = "Log or ask anything..."
    var onMicrophoneTapped: () -> Void = {}
    var onWaveformTapped: () -> Void = {}
    var onSubmit: () -> Void = {}

    // Realtime voice session properties
    var realtimeState: RealtimeSessionState = .idle
    var onRealtimeStart: (() -> Void)?
    var onRealtimeEnd: (() -> Void)?
    var onMuteToggle: (() -> Void)?

    @State private var isListening = false
    @State private var pulseScale: CGFloat = 1.0
    @StateObject private var speechRecognizer = SpeechRecognizer()

    var body: some View {
        contentCard
    }

    private var contentCard: some View {
        let hasUserInput = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .tint(Color.accentColor)
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
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
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
        .padding(.bottom, 0)
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
    }

    private func toggleSpeechRecognition() {
        isListening.toggle()
    }

    private func submitAgentPrompt() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        text = trimmed
        HapticFeedback.generate()
        onWaveformTapped()
        text = ""
        isPromptFocused.wrappedValue = false
    }

    @ViewBuilder
    private func rightButtons(hasUserInput: Bool) -> some View {
        switch realtimeState {
        case .connecting:
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                Button {
                    HapticFeedback.generate()
                    onRealtimeEnd?()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(UIColor { traitCollection in
                            traitCollection.userInterfaceStyle == .dark ? .black : .white
                        }))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(UIColor { traitCollection in
                                    traitCollection.userInterfaceStyle == .dark ? .white : .black
                                }))
                        )
                }
                .buttonStyle(.plain)
            }

        case .connected, .muted:
            HStack(spacing: 10) {
                    ActionCircleButtonMinimal(
                        systemName: realtimeState == .muted ? "mic.slash.fill" : "mic.fill",
                        action: {
                            HapticFeedback.generate()
                            onMuteToggle?()
                        },
                    backgroundColor: realtimeState == .muted ? .red : Color("chaticon"),
                    foregroundColor: realtimeState == .muted ? .white : .primary
                )

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

        default:
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
                    ActionCircleButtonMinimal(
                        systemName: "mic",
                        action: {
                            HapticFeedback.generate()
                            toggleSpeechRecognition()
                        },
                        backgroundColor: Color("chaticon"),
                        foregroundColor: .primary
                    )

                    ActionCircleButtonMinimal(
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

// Minimal local helpers to avoid depending on AgentTabBar’s private types.
private struct ActionCircleButtonMinimal: View {
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

private struct TransparentBlurViewMinimal: UIViewRepresentable {
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
