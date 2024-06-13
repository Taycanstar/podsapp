import Foundation
import SwiftUI

class UploadViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress: Float = 0.0
    @Published var thumbnailImage: Image? // Store the thumbnail as an Image
    @Published var postSuccess = false
    @Published var uploadCompletion: (() -> Void)?


    func updateProgress(_ progress: Float) {
        DispatchQueue.main.async {
            self.uploadProgress = progress
        }
    }

//    func uploadCompleted() {
//        DispatchQueue.main.async {
//            self.isUploading = false
//            self.postSuccess = true
//        }
//    }
    
    func uploadCompleted() {
        DispatchQueue.main.async {
            self.isUploading = false
            self.postSuccess = true
            self.resetPostSuccessAfterDelay()
            self.uploadCompletion?()
        }
    }
    
    private func resetPostSuccessAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.postSuccess = false
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

struct UploadProgressView: View {
    @EnvironmentObject var uploadViewModel: UploadViewModel

    var body: some View {
        ZStack {
            if let thumbnail = uploadViewModel.thumbnailImage {
                thumbnail
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 70)
                    .clipped()
                    .cornerRadius(8) // Increased corner radius
                    .overlay(
                        Rectangle()
                            .foregroundColor(Color.black.opacity(0.4))
                    )
                
                Circle()
                    .stroke(lineWidth: 3) // Thicker background circle
                    .opacity(0.2)  // Background circle for progress
                    .foregroundColor(Color.white)
                    .frame(width: 35, height: 35) // Smaller circle to match the thumbnail size closely

                Circle()
                    .trim(from: 0, to: CGFloat(uploadViewModel.uploadProgress))
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round)) // Thicker progress circle
                    .foregroundColor(Color.white)
                    .rotationEffect(Angle(degrees: -90)) // Start the progress from the top
                    .frame(width: 35, height: 35) // Smaller circle to match the thumbnail size closely
            }
        }
        .cornerRadius(8)
        .frame(width: 50, height: 70) // Fixed frame for alignment
        .padding(.leading, 20) // Ensure left alignment by padding from the leading edge
    }
}


struct UploadingSection: View {
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                if let thumbnail = uploadViewModel.thumbnailImage {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 35, height: 35)
                        .clipped()
                        .opacity(0.5)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        )
                        .padding(.leading, 10)
                } else {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .opacity(0.5)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        )
                }
                Text("Keep Podstack open to finish posting...")
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .font(.system(size: 14))
                Spacer()
            }
            
            ProgressView(value: uploadViewModel.uploadProgress)
                .progressViewStyle(LinearProgressViewStyle())
//                .padding(.horizontal)
        }
        .padding(.vertical, 0)
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}
