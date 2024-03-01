
import SwiftUI
import AVKit

struct ItemView: View {
    var url: URL
    @Environment(\.presentationMode) var presentationMode
    private let player = AVPlayer()
    var body: some View {
        ZStack {
            VideoPlayer(player: player)
                .edgesIgnoringSafeArea(.all)
                .aspectRatio(contentMode: .fill)
                .onAppear {
                                 // Set the player item and start playing
                                 player.replaceCurrentItem(with: AVPlayerItem(url: url))
                                 player.play()
                                 // Subscribe to the notification when the video finishes playing
                                 NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                                     // Seek to the start
                                     player.seek(to: .zero)
                                     // Play again
                                     player.play()
                                 }
                             }
                             .onDisappear {
                                 // Stop playing and clean up
                                 player.pause()
                                 NotificationCenter.default.removeObserver(self)
                             }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Use maximum available space
      
//        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton) 
        .padding(.bottom, 46)
    }
    
    
    // Inside PodView
    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left") 
                .foregroundColor(.white)
        }
        
    }
    
}
