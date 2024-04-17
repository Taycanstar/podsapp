import Foundation
import SwiftUI

class UploadViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress: Float = 0.0
    @Published var thumbnailImage: Image? // Store the thumbnail as an Image
    @Published var postSuccess = false


    func updateProgress(_ progress: Float) {
        DispatchQueue.main.async {
            self.uploadProgress = progress
        }
    }

    func uploadCompleted() {
        DispatchQueue.main.async {
            self.isUploading = false
            self.postSuccess = true
        }
    }
    
    func startUpload(withThumbnail thumbnail: UIImage) {
        self.thumbnailImage = Image(uiImage: thumbnail)
        isUploading = true
        simulateProgress() // Simulate for demonstration
    }

    // Simulate progress
    private func simulateProgress() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            DispatchQueue.main.async {
                if self.uploadProgress < 1.0 {
                    self.uploadProgress += 0.05
                } else {
                    timer.invalidate()
                    self.uploadCompleted()
                }
            }
        }
    }

}
