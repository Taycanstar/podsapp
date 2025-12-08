//
//  AnimatedWaveform.swift
//  pods
//
//  Created by Claude on 12/7/25.
//

import SwiftUI

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

#Preview {
    AnimatedWaveform()
        .padding()
        .background(Color.blue)
}
