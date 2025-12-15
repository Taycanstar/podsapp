//
//  FloatingFoodLoader.swift
//  pods
//
//  Created by Dimi Nunez on 12/15/25.
//


//
//  FloatingFoodLoader.swift
//  Pods
//
//  Created by Claude Code on 12/15/25.
//
//  Modern floating loader with liquid glass effect for food scanning
//  Displays above AgentTabBar with shimmer effects on logo, text, and progress bar

import SwiftUI
import UIKit

struct FloatingFoodLoader: View {
    let state: FoodScanningState

    @State private var shimmerOffset: CGFloat = -200
    @State private var rotatingTextIndex: Int = 0
    @State private var textRotationTimer: Timer?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var foodManager: FoodManager

    private let rotatingTexts = ["Analyzing...", "Thinking...", "Finishing up..."]
    private let textRotationInterval: TimeInterval = 3.0

    var body: some View {
        HStack(spacing: 12) {
            // Metryc logo with shimmer
            shimmerContent {
                Image("logx")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Rotating status text with shimmer (hardcoded rotation)
                shimmerContent {
                    Text(rotatingTexts[rotatingTextIndex])
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.primary)
                }
                .animation(.easeInOut(duration: 0.3), value: rotatingTextIndex)

                // Progress bar with shimmer
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 3)

                        // Progress fill with shimmer
                        shimmerContent {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(width: max(geometry.size.width * foodManager.animatedProgress, 20), height: 3)
                        }
                        .animation(.easeInOut(duration: 0.8), value: foodManager.animatedProgress)
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            // Thumbnail if available
            if let thumbnailImage = extractThumbnailImage() {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            liquidGlassBackground
        )
        .padding(.horizontal, 16)
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
    }

    private var liquidGlassBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.1 : 0.4),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.3 : 0.6),
                                Color.white.opacity(colorScheme == .dark ? 0.1 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    private func startAnimations() {
        guard !reduceMotion else { return }

        // Start shimmer animation
        shimmerOffset = -200
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 200
        }

        // Start text rotation timer
        textRotationTimer?.invalidate()
        textRotationTimer = Timer.scheduledTimer(withTimeInterval: textRotationInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                rotatingTextIndex = (rotatingTextIndex + 1) % rotatingTexts.count
            }
        }
    }

    private func stopAnimations() {
        textRotationTimer?.invalidate()
        textRotationTimer = nil
        shimmerOffset = -200
        rotatingTextIndex = 0
    }

    private func extractThumbnailImage() -> UIImage? {
        guard foodManager.isImageScanning else { return nil }
        return foodManager.currentScanningImage
    }

    // MARK: - Shimmer Content Builder

    @ViewBuilder
    private func shimmerContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shimmerColor = colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.4)

        content()
            .overlay(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: shimmerColor, location: 0.5),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: .init(x: -0.3 + shimmerOffset / 200, y: 0),
                    endPoint: .init(x: 0.3 + shimmerOffset / 200, y: 0)
                )
                .blendMode(.overlay)
            )
            .mask(content())
    }
}

// MARK: - Preview

struct FloatingFoodLoader_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack {
                Spacer()
                FloatingFoodLoader(state: .analyzing)
                    .environmentObject(FoodManager())
                    .padding(.bottom, 100)
            }
        }
    }
}
