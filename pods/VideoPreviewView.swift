import SwiftUI
import AVKit

struct VideoPreviewView: View {
    let videoURL: URL
    @Binding var showPreview: Bool

    var body: some View {
        VStack {
            VideoPlayer(player: AVPlayer(url: videoURL))
            HStack {
                Button("Save") {
                    // Implement saving to the photo library
                    showPreview = false
                }
                Button("Re-record") {
                    // Dismiss the preview and allow re-recording
                    showPreview = false
                }
            }
        }
    }
}
