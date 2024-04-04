import SwiftUI
import AVKit

struct ItemView: View {
    var items: [PodItem]
    var initialIndex: Int
    @State private var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sharedViewModel: SharedViewModel

    init(items: [PodItem], initialIndex: Int) {
        self.items = items
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(items.indices, id: \.self) { index in
                    VideoContentView(url: items[index].videoURL, isActive: index == currentIndex)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(x: 0, y: getYOffsetFor(index: index, in: geometry.size.height))
                        .animation(.easeInOut(duration: 0.3), value: dragOffset)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }
            .gesture(
                DragGesture().onChanged { gesture in
                    dragOffset = gesture.translation.height
                }
                .onEnded { gesture in
                    if abs(gesture.translation.height) > 50 {
                        let swipeUp = gesture.translation.height < 0
                        changeIndex(swipeUp: swipeUp)
                    }
                    dragOffset = 0
                }
            )
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .preferredColorScheme(.dark)
//        .onAppear {
//                   sharedViewModel.isItemViewActive = true
//               }
//               .onDisappear {
//                   sharedViewModel.isItemViewActive = false
//               }
//        
    }

    private func getYOffsetFor(index: Int, in height: CGFloat) -> CGFloat {
        if index == currentIndex {
            return dragOffset
        } else if index < currentIndex {
            return dragOffset - height
        } else {
            return height + dragOffset
        }
    }

    private func changeIndex(swipeUp: Bool) {
        if swipeUp {
            if currentIndex < items.count - 1 {
                currentIndex += 1
            } else {
                currentIndex = 0
            }
        } else {
            if currentIndex > 0 {
                currentIndex -= 1
            } else {
                currentIndex = items.count - 1
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
    var isActive: Bool
    @State private var player: AVPlayer = AVPlayer()

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
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            self.player.seek(to: .zero)
            if self.isActive {
                self.player.play()
            }
        }
        if isActive {
            player.play()
        }
    }

    private func cleanupPlayer() {
        player.pause()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
}
