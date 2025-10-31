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
    var onPlusTapped: () -> Void = {}
    var onBarcodeTapped: () -> Void = {}
    var onMicrophoneTapped: () -> Void = {}
    var onWaveformTapped: () -> Void = {}
    var onSubmit: () -> Void = {}
    @FocusState private var isPromptFocused: Bool
    @State private var isListening = false
    @State private var pulseScale: CGFloat = 1.0
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
            TextField("Ask or Log Anything", text: $text)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .submitLabel(.send)
                .onSubmit(onSubmit)
                .focused($isPromptFocused)
            
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
                }
                
                Spacer()
                
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
                            backgroundColor: Color(.systemGray6),
                            foregroundColor: .primary
                        )

                        ActionCircleButton(
                            systemName: hasUserInput ? "arrow.forward" : "waveform",
                            action: {
                                if hasUserInput {
                                    onWaveformTapped()
                                } else {
                                    onMicrophoneTapped()
                                }
                            },
                            backgroundColor: hasUserInput ? Color.accentColor : Color(.systemGray6),
                            foregroundColor: hasUserInput ? .white : .primary
                        )
                    }
                }
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
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, -12)
        .padding(.bottom, isPromptFocused ? 10 : 0)
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
}

private struct ActionCircleButton: View {
    var systemName: String
    var action: () -> Void
    var backgroundColor: Color = Color(.systemGray6)
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

    var body: some View {
        AgentTabBar(text: $prompt)
    }
}
