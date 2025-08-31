//
//  CircularProgressRing.swift
//  pods
//
//  Created by Claude on 8/30/25.
//

import SwiftUI

/// A circular progress ring for timer display following Apple's design patterns
/// Provides smooth animation and visual feedback for countdown timers
struct CircularProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat
    let size: CGFloat
    let foregroundColor: Color
    let backgroundColor: Color
    
    @State private var animatedProgress: Double = 0.0
    
    init(
        progress: Double,
        lineWidth: CGFloat = 8,
        size: CGFloat = 200,
        foregroundColor: Color = .blue,
        backgroundColor: Color = .gray.opacity(0.2)
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Progress ring
            Circle()
                .trim(from: 0.0, to: CGFloat(animatedProgress))
                .stroke(
                    foregroundColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90)) // Start from top
                .animation(.easeInOut(duration: 1.0), value: animatedProgress)
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

/// Timer-specific progress ring that changes color during final countdown
struct TimerProgressRing: View {
    let progress: Double
    let isFinalCountdown: Bool
    let lineWidth: CGFloat
    let size: CGFloat
    
    init(
        progress: Double,
        isFinalCountdown: Bool = false,
        lineWidth: CGFloat = 8,
        size: CGFloat = 200
    ) {
        self.progress = progress
        self.isFinalCountdown = isFinalCountdown
        self.lineWidth = lineWidth
        self.size = size
    }
    
    private var ringColor: Color {
        if isFinalCountdown {
            return .green
        } else {
            return .blue
        }
    }
    
    var body: some View {
        CircularProgressRing(
            progress: progress,
            lineWidth: lineWidth,
            size: size,
            foregroundColor: ringColor,
            backgroundColor: .gray.opacity(0.2)
        )
    }
}

#Preview("Progress Ring Examples") {
    VStack(spacing: 30) {
        Text("Progress Ring Examples")
            .font(.title)
        
        HStack(spacing: 30) {
            VStack {
                CircularProgressRing(progress: 0.0)
                Text("0%")
            }
            
            VStack {
                CircularProgressRing(progress: 0.35)
                Text("35%")
            }
            
            VStack {
                CircularProgressRing(progress: 0.75)
                Text("75%")
            }
        }
        
        VStack {
            TimerProgressRing(progress: 0.9, isFinalCountdown: true)
            Text("Final Countdown")
        }
    }
    .padding()
}