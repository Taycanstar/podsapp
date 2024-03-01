import SwiftUI
import AVKit

struct ItemView: View {
    var items: [PodItem]
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0 // Track drag offset
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(items.indices, id: \.self) { index in
//                    VideoContentView(url: items[index].videoURL)
                    VideoContentView(url: items[index].videoURL, isActive: index == currentIndex)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(x: 0, y: getYOffsetFor(index: index, in: geometry.size.height))
                        .animation(.easeInOut(duration: 0.3), value: dragOffset) // Smooth transition
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }
            .gesture(
                DragGesture().onChanged { gesture in
                    dragOffset = gesture.translation.height
                }
                .onEnded { gesture in
                    if abs(gesture.translation.height) > 50 { // Sensitivity of swipe
                        let swipeUp = gesture.translation.height < 0
                        changeIndex(swipeUp: swipeUp)
                    }
                    dragOffset = 0 // Reset drag offset
                }
            )
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .padding(.bottom, 46) // Adjust based on your UI needs
    }

    private func getYOffsetFor(index: Int, in height: CGFloat) -> CGFloat {
        // Calculate offsets to ensure videos are attached
        if index == currentIndex {
            return dragOffset // Apply dragging offset
        } else if index < currentIndex {
            return dragOffset - height // Move previous videos directly above current
        } else {
            return height + dragOffset // Position next videos directly below current
        }
    }

    private func changeIndex(swipeUp: Bool) {
        if swipeUp {
            if currentIndex < items.count - 1 {
                currentIndex += 1
            } else {
                currentIndex = 0 // Go to the first item if currently at the last item
            }
        } else {
            if currentIndex > 0 {
                currentIndex -= 1
            } else {
                currentIndex = items.count - 1 // Go to the last item if currently at the first item
            }
        }
    }


    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left").foregroundColor(.white)
        }
    }
}

struct VideoContentView: View {
    let url: URL
    var isActive: Bool // Determines if this view is the active (current) item
    @State private var player = AVPlayer()

    var body: some View {
        VideoPlayer(player: player)
            .edgesIgnoringSafeArea(.all)
            .aspectRatio(contentMode: .fill)
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                cleanupPlayer()
            }
            .onChange(of: isActive) { newValue in
                if newValue {
                    player.play()
                } else {
                    player.pause()
                }
            }
    }

    private func setupPlayer() {
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        if isActive {
            player.play()
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            player.seek(to: .zero)
            if isActive {
                player.play()
            }
        }
    }
    
    private func cleanupPlayer() {
        player.pause()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
}




