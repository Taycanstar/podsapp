//
//  ModernLoadingView.swift
//  Pods
//
//  Created by Claude on 8/24/25.
//

import SwiftUI

struct ModernLoadingView: View {
    let message: String
    @State private var shimmerOffset: CGFloat = -200
    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 32) {
            // Elegant loading indicator
            VStack(spacing: 16) {
                // Subtle pulsing dots
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .scaleEffect(pulseScale)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: pulseScale
                            )
                    }
                }
                
                // Status text
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: message)
            }
            
            // Skeleton exercise cards
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    skeletonExerciseCard
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            startAnimations()
        }
        .accessibilityLabel("Loading workout. \(message)")
        .accessibilityHint("Please wait while your workout is being generated")
    }
    
    private var skeletonExerciseCard: some View {
        HStack(spacing: 16) {
            // Thumbnail skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(shimmerGradient)
                .frame(width: 60, height: 60)
            
            // Content skeleton
            VStack(alignment: .leading, spacing: 8) {
                // Exercise name
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 16)
                
                // Sets/reps info
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 60, height: 12)
                    
                    Spacer()
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private var shimmerGradient: LinearGradient {
        let baseColor = Color(.systemGray5)
        let shimmerColor = Color(.systemGray4)
        
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
    
    private func startAnimations() {
        // Pulsing dots animation
        pulseScale = 1.2
        
        // Shimmer animation
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 200
        }
    }
}

// MARK: - Reduced Motion Support

private struct ReducedMotionModernLoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.accentColor)
            
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityLabel("Loading workout. \(message)")
        .accessibilityHint("Please wait while your workout is being generated")
    }
}

// MARK: - Environment-Aware Wrapper

struct AdaptiveLoadingView: View {
    let message: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        if reduceMotion {
            ReducedMotionModernLoadingView(message: message)
        } else {
            ModernLoadingView(message: message)
        }
    }
}

// MARK: - Preview

#Preview {
    AdaptiveLoadingView(message: "Creating your workout...")
}