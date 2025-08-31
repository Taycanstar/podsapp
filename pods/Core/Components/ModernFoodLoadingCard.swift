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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var foodManager: FoodManager
    
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
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray4), lineWidth: 0.5)
                )
        )
        .accessibilityLabel("Humuli analysis in progress. Finishing up...")
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