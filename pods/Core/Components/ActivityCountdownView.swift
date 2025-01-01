import SwiftUI

struct ActivityCountdownView: View {
    @Binding var isPresented: Bool
    let onFinished: () -> Void
    
    @State private var countdown: Int = 3
    @State private var progress: CGFloat = 1.0
    @State private var showReady = true
    
    var body: some View {
        ZStack {
            Color("iosbg")
                .ignoresSafeArea()
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color("greenLoop").opacity(0.3), lineWidth: 8)
                    .frame(width: 300, height: 300)
                
                // Animated progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color("greenLoop"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 300, height: 300)
                    .rotationEffect(.degrees(-90))
                
                // Ready text or Countdown numbers
                if showReady {
                    Text("Ready")
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                } else {
                    Text("\(countdown)")
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale),
                            removal: .opacity.combined(with: .scale)
                        ))
                        .id(countdown) // Force view update on countdown change
                }
            }
        }
        .contentShape(Rectangle()) // Make entire view tappable
        .onTapGesture {
            skipCountdown()
        }
        .onAppear {
            startCountdown()
        }
    }
    
    private func skipCountdown() {
        // Cancel any pending animations/updates
        withAnimation {
            isPresented = false
        }
        onFinished()
    }
    
    private func startCountdown() {
        // Start with "Ready" for 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                showReady = false
            }
            
            // Start the countdown animation
            withAnimation(.linear(duration: 3)) {
                progress = 0
            }
            
            // Count down from 3 to 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    countdown = 2
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    countdown = 1
                }
            }
            
            // Complete the countdown after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isPresented = false
                }
                onFinished()
            }
        }
    }
}
