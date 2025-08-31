//
//  ModernFoodLoadingCard.swift
//  Pods
//
//  Created by Claude Code on 8/30/25.
//
//  Modern, elegant loading experience for food scanning that eliminates race conditions
//  Inspired by ModernWorkoutLoadingView but designed for food analysis flow

import SwiftUI

struct ModernFoodLoadingCard: View {
    let state: FoodScanningState
    @State private var pulseOpacity: Double = 0.7
    @State private var shimmerOffset: CGFloat = -200
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var foodManager: FoodManager
    
    // Customization parameters
    private let shimmerSpeed: Double = 1.0
    private let shimmerOpacity: Double = 0.8
    private let shimmerColorDark = Color.white.opacity(0.1)
    private let shimmerColorLight = Color.black.opacity(0.05)
    
    var body: some View {
        // DEBUG: Print current state and progress
        let _ = print("🔍 DEBUG ModernFoodLoadingCard - State: \(state), Progress: \(state.progress)")
        
        // Perplexity-style loading panel
        VStack(spacing: 16) {
            // Header with Humuli logo and title
            HStack(spacing: 12) {
                Image("logx")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                
                Text("Humuli Analysis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Show thumbnail for image analysis
                if let thumbnailImage = extractThumbnailImage() {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.35))
                        )
                }
            }
            
            // Animated progress bar with smooth transitions
            ZStack(alignment: .leading) {
                // Background track
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    // Animated progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * foodManager.animatedProgress, height: 4)
                        .opacity(pulseOpacity)
                        .animation(.easeInOut(duration: 0.8), value: foodManager.animatedProgress)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseOpacity)
                }
            }
            .frame(height: 4)
            .onAppear {
                // Start pulse animation
                withAnimation {
                    pulseOpacity = 1.0
                }
                // Start continuous shimmer animation with delay to ensure view is stable
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startShimmerAnimation()
                }
            }
            .onDisappear {
                stopShimmerAnimation()
            }
            
            // Dynamic status text based on actual state
            HStack {
                Text(state.displayMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: state.displayMessage)
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("containerbg"))
                .overlay(
                    // Shimmer light effect
                    RoundedRectangle(cornerRadius: 16)
                        .fill(shimmerGradient)
                        .opacity(shimmerOpacity)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray4), lineWidth: 0.5)
                )
        )
        .accessibilityLabel("Humuli analysis in progress. Finishing up...")
    }
    
    private var shimmerGradient: LinearGradient {
        let baseColor = Color.clear
        let shimmerColor = colorScheme == .dark ? shimmerColorDark : shimmerColorLight
        
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: baseColor, location: 0),
                .init(color: shimmerColor, location: 0.5),
                .init(color: baseColor, location: 1)
            ]),
            startPoint: .init(x: -0.3 + shimmerOffset/200, y: 0),
            endPoint: .init(x: 0.3 + shimmerOffset/200, y: 0)
        )
    }
    
    private func startShimmerAnimation() {
        // Respect accessibility settings
        guard !reduceMotion else { return }
        
        // Reset to start position
        shimmerOffset = -200
        
        // Start continuous shimmer animation (matching ModernWorkoutLoadingView exactly)
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 200
        }
    }
    
    private func stopShimmerAnimation() {
        shimmerOffset = -200 // Reset position
    }
    
    /// Extract thumbnail image from current scanning state
    private func extractThumbnailImage() -> UIImage? {
        // Only show thumbnail during image scanning
        guard foodManager.isImageScanning else { return nil }
        
        // Use persistent image property
        return foodManager.currentScanningImage
    }
}

// MARK: - Preview Provider
struct ModernFoodLoadingCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            ModernFoodLoadingCard(state: .preparing(image: UIImage()))
            ModernFoodLoadingCard(state: .uploading(progress: 0.5))
            ModernFoodLoadingCard(state: .analyzing)
            ModernFoodLoadingCard(state: .processing)
            ModernFoodLoadingCard(state: .failed(error: .networkError("Connection timeout")))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}