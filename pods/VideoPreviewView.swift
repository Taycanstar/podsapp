import SwiftUI
import AVKit

struct VideoPreviewView: View {
    var videoURL: URL
    @Binding var showPreview: Bool
    var saveAction: () -> Void

    var body: some View {
        ZStack {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .edgesIgnoringSafeArea(.all)
               

            VStack {
                HStack {
                    Button(action: {
                        self.showPreview = false
                    }) {
                        Image(systemName: "xmark")
                            .padding()
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                Spacer()
                Button(action: {
                    saveAction()
                }) {
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
