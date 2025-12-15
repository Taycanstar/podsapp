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

struct FloatingFoodLoader: View {
    let state: FoodScanningState

    @State private var shimmerOffset: CGFloat = -1.0
    @State private var rotatingTextIndex: Int = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var foodManager: FoodManager

    private let rotatingTexts = ["Analyzing...", "Thinking...", "Finishing up..."]
    private let textRotationInterval: TimeInterval = 2.0

    var body: some View {
        HStack(spacing: 12) {
            // Metryc logo with shimmer
            Image("logx")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .modifier(ShimmerModifier(offset: shimmerOffset))

            VStack(alignment: .leading, spacing: 6) {
                // Display message with shimmer
                Text(state.displayMessage.isEmpty ? rotatingTexts[rotatingTextIndex] : state.displayMessage)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                    .modifier(ShimmerModifier(offset: shimmerOffset))

                // Progress bar with shimmer
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 3)

                        // Progress fill with shimmer
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * foodManager.animatedProgress, height: 3)
                            .modifier(ShimmerModifier(offset: shimmerOffset))
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
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                RoundedRectangle(cornerRadius: 20, style: .continuous)
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
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 1.0
        }

        // Start text rotation
        startTextRotation()
    }

    private func startTextRotation() {
        Timer.scheduledTimer(withTimeInterval: textRotationInterval, repeats: true) { timer in
            guard foodManager.foodScanningState.isActive else {
                timer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                rotatingTextIndex = (rotatingTextIndex + 1) % rotatingTexts.count
            }
        }
    }

    private func stopAnimations() {
        shimmerOffset = -1.0
        rotatingTextIndex = 0
    }

    private func extractThumbnailImage() -> UIImage? {
        guard foodManager.isImageScanning else { return nil }
        return foodManager.currentScanningImage
    }
}

// MARK: - Shimmer Modifier

private struct ShimmerModifier: ViewModifier {
    let offset: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    let shimmerColor = colorScheme == .dark
                        ? Color.white.opacity(0.3)
                        : Color.white.opacity(0.6)

                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: shimmerColor, location: 0.5),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: geometry.size.width * offset)
                    .blendMode(.overlay)
                }
            )
            .mask(content)
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
