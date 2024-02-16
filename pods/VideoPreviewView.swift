import SwiftUI
import AVKit

struct VideoPreviewView: View {
    var videoURL: URL
    @Binding var showPreview: Bool

    var body: some View {
        ZStack {
            AVPlayerViewControllerRepresentable(videoURL: videoURL)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Button(action: { self.showPreview = false }) {
                    Image(systemName: "xmark")
                        .padding()
                        .foregroundColor(.white)
                }
                Spacer()
                Button(action: { /* Save video action */ }) {
                    Image(systemName: "arrow.right")
                        .padding()
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            print("VideoPreviewView appeared with video URL: \(videoURL)")
        }
    }
}

struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    var videoURL: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerViewController = AVPlayerViewController()
        let player = AVPlayer(url: videoURL)
        playerViewController.player = player
        return playerViewController
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update the controller if needed
    }
}
