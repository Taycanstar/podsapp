import SwiftUI
import AVKit
import PhotosUI
import Photos
import UniformTypeIdentifiers


struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var cameraViewModel: CameraViewModel

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        // Allow both photos and videos
        config.filter = .any(of: [.images, .videos])
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false // Dismiss the picker immediately
            guard let provider = results.first?.itemProvider else {
                print("No provider found for the selected item.")
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                processVideo(provider: provider)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                processImage(provider: provider)
            }
        }

        private func processVideo(provider: NSItemProvider) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.movie.identifier) { data, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error loading video data: \(error.localizedDescription)")
                        return
                    }

                    guard let data = data, let url = self.writeDataToTemporaryLocation(data: data) else {
                        print("Unable to write video data to temporary location.")
                        return
                    }

                    // Process the selected video
                    self.parent.cameraViewModel.handleSelectedVideo(url)
                }
            }
        }

        private func processImage(provider: NSItemProvider) {
            provider.loadObject(ofClass: UIImage.self) { (object, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error loading image: \(error.localizedDescription)")
                    }
                    if let image = object as? UIImage {
                        print("Successfully selected image: \(image)")
                        self.parent.cameraViewModel.handleSelectedImage(image)
                    } else {
                        print("No image found in the provider.")
                    }
                }
            }
        }


        private func writeDataToTemporaryLocation(data: Data) -> URL? {
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempUrl = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")

            do {
                try data.write(to: tempUrl)
                return tempUrl
            } catch {
                print("Error writing video data to temporary location: \(error)")
                return nil
            }
        }
    }
}



struct CameraContainerView: View {
    @StateObject var cameraModel = CameraViewModel()
    @State private var showCreatePodView = false
    @State private var isShowingVideoPicker = false
    @State private var selectedVideoURL: URL?
    @State private var isProcessingVideo = false
    @Binding var shouldNavigateToHome: Bool
    @State private var showingVoiceCommandPopup = false
    @State private var voiceCommandPopupMessage: String? = nil
    @Binding var showingVideoCreationScreen: Bool
    @State private var latestPhoto: UIImage? = nil





    
    var body: some View {
        ZStack {
            // MARK: Camera View
            AltCameraView()
                .environmentObject(cameraModel)
            
                .fullScreenCover(isPresented: $showCreatePodView) {
                    CreatePodView(pod: $cameraModel.currentPod, shouldNavigateToHome: $shouldNavigateToHome)
                                  // Pass any required environment objects or parameters
                          }
     
            // Add a button to reset the current pod
//                      if !cameraModel.currentPod.items.isEmpty {
//                          Button(action: {
//                              // Reset the current pod and any other necessary states
//                              print("xxx")
//                              cameraModel.currentPod = Pod(id: -1, items:[],title: "")
//                              cameraModel.recordedDuration = 0
//                              cameraModel.previewURL = nil
//                          }) {
//                              Image(systemName: "xmark")
//                                  
//                                  .foregroundColor(.white)
//                                  .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
//                                  .font(.system(size: 22))
//                                  .padding()
//                          }
//                          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//                       
//                          .padding(.top, 15)
//                          .padding(.leading, 0)
//                        
//                      }
            
            if !cameraModel.isRecording {
                Button(action: {
                    // Instead of resetting properties, just close the video creation screen
                    showingVideoCreationScreen = false
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                        .font(.system(size: 22))
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 15)
                .padding(.leading, 5)
                .padding(.leading, 0)

            }
            
         
            


            // Floating Camera Control Buttons
            if !cameraModel.isRecording {
                VStack(spacing: 0) {  // Adjust spacing as needed
                    Button(action: cameraModel.switchCamera) {
                        Image(systemName: "arrow.triangle.capsulepath")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                            .font(.system(size: 16))
                            .padding()
                    }
                    Button(action: cameraModel.toggleFlash) {
                        Image(systemName: cameraModel.isFlashOn ? "bolt" : "bolt.slash")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                            .font(.system(size: 16))
                            .padding()
                    }
                    
                    Button(action: {
                        cameraModel.toggleWaveform()
                           // Set the message based on the waveform state
                           voiceCommandPopupMessage = cameraModel.isWaveformEnabled ? "Voice commands enabled: Say 'start recording' or 'stop recording'" : "Voice commands disabled"

                           // Show the message
                           withAnimation {
                               showingVoiceCommandPopup = true
                           }

                        // Hide the popup after a few seconds and reset the message
                          DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                              showingVoiceCommandPopup = false
                              // Reset the message after the animation completes to ensure it's ready for the next toggle
                              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                  voiceCommandPopupMessage = nil
                              }
                          }
                    }) {
                        Image(systemName: "waveform")
                            .font(.title)
                            .foregroundColor(cameraModel.isWaveformEnabled ? Color(red: 70/255, green: 87/255, blue: 245/255) : .white)
                            .font(.system(size: 16))
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                            .padding()
                    }

                }
                .position(x: UIScreen.main.bounds.width - 33, y: 100)
            }
            
            if let message = voiceCommandPopupMessage {
                   VStack {
                       VoiceCommandPopupView(message: message)
                           .padding(.top, 20) // Adjust this value to ensure it doesn't overlap with the notch or status bar
                           .transition(.move(edge: .top).combined(with: .opacity))
                           .animation(.easeInOut, value: UUID())

                       Spacer() // Pushes the popup to the top
                   }
                   .zIndex(1) // Ensure it's above other content
               }

                     
            HStack(spacing: 55) { // This HStack contains all main elements

                
                if !cameraModel.currentPod.items.isEmpty {
                        // Thumbnail Carousel
                        ThumbnailCarouselView(items: cameraModel.currentPod.items)
//                            .frame(width: 40, height: 40) 
                        .frame(width: 40, height: 40)
                        .padding(.top, -5)
                   
                               
                    } else {
                        // Invisible Placeholder when there are no items
                        VStack {
                            Color.clear
                                .frame(width: 40, height: 40)
                            Text(" ")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.clear)
                        }
                    }
                
                Button(action: {
                    if cameraModel.isRecording{
                        cameraModel.stopRecording()
                    } else {
                        cameraModel.startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(cameraModel.isRecording ? Color.red : Color.white) // Inner circle color
                            .frame(width: 65, height: 65) // Inner circle size

                        Circle()
                            .stroke(cameraModel.isRecording ? Color.clear : Color.white, lineWidth: 4) // Outer circle border
                            .frame(width: 75, height: 75) // Outer circle size (including padding)
                    }
                }
                
                if !cameraModel.isRecording {
                    
                    VStack {
                        if let latestPhoto = latestPhoto {
                            Button(action: {
                                // Trigger upload functionality
                                isShowingVideoPicker = true
                                print("xy")
                            }) {
                                Image(uiImage: latestPhoto)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40) // Adjust size as needed
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
                            }
                        } else {
                            Button(action: {
                                // Placeholder or action for when no photo is available
                            }) {
                                Image("ms")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40) // Adjust size as needed
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
                            }
                        }
                        Text("Upload") // This ensures the text is below the button
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .sheet(isPresented: $isShowingVideoPicker) {
                        PhotoPicker(isPresented: $isShowingVideoPicker, cameraViewModel: cameraModel)
                    }
                } else {
                    VStack {
                        Color.clear
                            .frame(width: 40, height: 40)
                        Text(" ")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.clear)
                    }
                    
                }

               
                
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            .padding(.bottom,15)

            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .padding(.top)

        }
        

//        .fullScreenCover(isPresented: $cameraModel.showPreview) {
//                // Make sure to safely unwrap the `cameraModel.previewURL` or handle nil case appropriately
//                if let url = cameraModel.previewURL {
//                    FinalPreview(url: url, showPreview: $cameraModel.showPreview, cameraModel: cameraModel, isFrontCameraUsed: cameraModel.isFrontCameraUsed, showCreatePodView: $showCreatePodView)
//                        .background(Color.black.edgesIgnoringSafeArea(.all))
//                        .environment(\.colorScheme, .dark)
//                }
//            }
        .fullScreenCover(isPresented: $cameraModel.showPreview) {
            if let url = cameraModel.previewURL {
                // Present with video URL
                FinalPreview(url: url, selectedImage: nil, showPreview: $cameraModel.showPreview, cameraModel: cameraModel, isFrontCameraUsed: cameraModel.isFrontCameraUsed, showCreatePodView: $showCreatePodView)
                    .background(Color.black.edgesIgnoringSafeArea(.all))
                    .environment(\.colorScheme, .dark)
            } else if let selectedImage = cameraModel.selectedImage {
                // Present with image
               
                FinalPreview(url: nil,  selectedImage: selectedImage, showPreview: $cameraModel.showPreview, cameraModel: cameraModel, isFrontCameraUsed: cameraModel.isFrontCameraUsed, showCreatePodView: $showCreatePodView)
                    .background(Color.black.edgesIgnoringSafeArea(.all))
                    .environment(\.colorScheme, .dark)
            }
        }


        .overlay(
                fullScreenOverlayView
            )
        Spacer() // Pushes the bar to the bottom
        

        
        HStack(spacing: 10) { // Spacing between buttons is 10
            // Start Over Button
            
            if !cameraModel.currentPod.items.isEmpty {
                Button("Start over") {
                    // Action for Start Over
                    cameraModel.currentPod = Pod(id: -1, items:[],title: "")
                    cameraModel.recordedDuration = 0
                    cameraModel.previewURL = nil
                }
                .foregroundColor(.black) // Text color
                .padding(.vertical, 15) // Padding for thickness
                .frame(maxWidth: .infinity) // Make button expand
                .background(Color.white) // Background color of the button
                .cornerRadius(8) // Rounded corners
                .fontWeight(.semibold)

                // Next Button
                Button("Next") {
                    // Action for Next
                    if let previewURL = cameraModel.previewURL {
                        print("Preview URL: \(previewURL)")
                        cameraModel.showPreview = true
                    } else {
                        print("No preview URL available")
                    }
                }
                .foregroundColor(.white) // Text color for the Next button
                .padding(.vertical, 15) // Padding for thickness
                .frame(maxWidth: .infinity) // Make button expand
                .fontWeight(.semibold)
                .background(Color(red: 70/255, green: 87/255, blue: 245/255)) // Background color
                .cornerRadius(8) // Rounded corners
            } else{
                Rectangle()
                    .foregroundColor(.black)
            }
     
        }
        .padding(.horizontal, 10) // Horizontal padding from the screen edges, 10 points on each side
        .frame(height: 60) // Set the height of the bottom bar
        .background(Color.black) // Set the color to black
        .edgesIgnoringSafeArea(.bottom) // Ensures it goes to the edge of the screen



        .onAppear {
                  // Request authorization and fetch latest photo
                  PHPhotoLibrary.requestAuthorization { status in
                      if status == .authorized {
                          self.fetchLatestPhoto { photo in
                              self.latestPhoto = photo
                          }
                      }
                  }
              }
        
    }
    
    
    
    private func handleSelectedVideoURL() async {
         if let url = selectedVideoURL {
             // Set it as the preview URL and show the preview
             cameraModel.previewURL = url
             cameraModel.showPreview = true
             selectedVideoURL = nil // Reset after handling
         }
        
      
     }
    
    

    func fetchLatestPhoto(completion: @escaping (UIImage?) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let lastAsset = fetchResult.firstObject else {
            completion(nil)
            return
        }

        let options = PHImageRequestOptions()
        options.version = .current
        options.isSynchronous = true

        PHImageManager.default().requestImage(for: lastAsset, targetSize: CGSize(width: 60, height: 60), contentMode: .aspectFill, options: options) { image, _ in
            completion(image)
        }
    }

    
    
    
    private var fullScreenOverlayView: some View {
         Group {
             if cameraModel.isProcessingVideo {
                 ZStack {
                     // Changed the background color to the specified RGB value
                     Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
                         
                         .ignoresSafeArea(.all)
                     // Customized ProgressView for a larger display
                     ProgressView()
                         .progressViewStyle(CircularProgressViewStyle(tint: .white))
                         .scaleEffect(2) // Scale up the ProgressView to make it larger
                         .foregroundColor(.white)
                 }
             }
         }
     }
       
}



extension View {
    func alignAsFloating() -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

struct VoiceCommandPopupView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14))
            .fontWeight(.semibold)
            .padding(15)
            .background(Color(red: 66 / 255, green: 66 / 255, blue: 66 / 255))
            .foregroundColor(.white)
            .cornerRadius(100)
            .frame(width: 300) // Set a fixed width for the popup
    }
}



struct FinalPreview: View {
    
    @State var url: URL?
    @State var selectedImage: UIImage?
    @Binding var showPreview: Bool
     var player = AVPlayer()
    @ObservedObject var cameraModel = CameraViewModel()
    var isFrontCameraUsed: Bool
    @Binding var showCreatePodView: Bool
    @State private var isPresentingEditor = false
    @State private var editParameters = VideoEditParameters()
    private let blackSegmentHeight: CGFloat = 100
    var videoAspectRatio: CGFloat = 9 / 16
    
    
    var body: some View {

            GeometryReader { proxy in
                let size = proxy.size
                let screenWidth = size.width
                           // Calculate video height based on its aspect ratio
                let videoHeight = screenWidth * (1 / videoAspectRatio)
                           // Calculate the remaining height for the bottom segment
                let bottomSegmentHeight = max(proxy.size.height - videoHeight, 0)


                VStack(spacing:0) {
                    
                    ZStack{
                        if let url = cameraModel.previewURL, FileManager.default.fileExists(atPath: url.path) {
                                  // Video preview
                                  VideoPlayer(player: player)
                                .scaleEffect(x: isFrontCameraUsed ? -1 : 1, y: 1, anchor: .center)
                                .frame(width: screenWidth, height: videoHeight)
                                .id(url)
                                .onAppear {
                                    setupPlayer()
                                    
                                }
                                .onDisappear {
                                    cleanUpPlayer()
                                }
                                .onChange(of: editParameters) { _ in
                                    // Apply edit parameters to the video preview
                                    // This is a placeholder action; actual implementation depends on your video processing approach
                                    applyEditParametersAndSetupPlayer()
                                }
                              } else 
                        if let image = cameraModel.selectedImage {
                              
                                  Image(uiImage: image)
                                      .resizable()
                                      .aspectRatio(contentMode: .fill)
                                      .clipped()
                                      .scaleEffect(x: isFrontCameraUsed ? -1 : 1, y: 1, anchor: .center)
                                      .frame(width: screenWidth, height: videoHeight)
                              }
        
                    }
                    .clipped()
              
                    VStack {
                    
                        Button("Continue") {
                            cleanUpPlayer()
                            cameraModel.confirmAndNavigateToCreatePod()
                            showCreatePodView = true
                        }
                        .foregroundColor(.white) // Text color for the Next button
                        .padding(.vertical, 18)
                       
                        .frame(maxWidth: .infinity) // Make button expand
                        .fontWeight(.semibold)
                        .background(Color(red: 70/255, green: 87/255, blue: 245/255)) // Background color
                        .cornerRadius(8) // Rounded corners
                            }
                    .padding(.top, 25)
                    .padding(.horizontal, 15)
                    .frame(height: bottomSegmentHeight)
                    
                }
            .overlay {
                VStack {
                    HStack {
                        Button(action: {
                            if cameraModel.currentPod.items.isEmpty {
                                // If it's the first item (Pod is empty), just close the preview
                                // This essentially cancels the recording
                                showPreview = false
                            } else {
                                // If Pod has items, prepare to re-record the current item
                                // This keeps the Pod items intact but allows for re-recording
                                cameraModel.reRecordCurrentItem()
                                showPreview = false
                            }
                        }) {

                            ZStack {
                                RoundedRectangle(cornerRadius: 22) // Half of height for full curvature
                                    .foregroundColor(.black)
                                    .opacity(0.4)
                                    .frame(width: 75, height: 38) // Adjust the size as needed, ensuring the cornerRadius is half of height

                                Text("Cancel")
                                    .font(.system(size: 17))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .scaleEffect(0.8) // Adjust the scale if needed
                            }
                        }
                        .padding(.leading, -5)
                        Spacer()
                        Button(action: {

                            cleanUpPlayer()
                            cameraModel.confirmVideo()
                         
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 22) // Half of height for full curvature
                                    .foregroundColor(.black)
                                    .opacity(0.4)
                                    .frame(width: 75, height: 38) // Adjust the size as needed, ensuring the cornerRadius is half of height

                                Text("Save")
                                    .font(.system(size: 17))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .scaleEffect(0.8) // Adjust the scale if needed
                            }
                        }
                        .padding(.trailing, -5)

                        
                    }
                    
                    HStack{
                        Spacer()
                        Button(action: {
                            // Trigger crop and rotate mode
                            player.pause()
                            isPresentingEditor = true
                        }) {
                            Image(systemName: "crop")
                                .iconStyle()
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                                
                        }
                    }
                    .padding(.vertical, 15)
                    
                    
                    Spacer()
                    
                }
                .padding()
            }

            .fullScreenCover(isPresented: $isPresentingEditor, onDismiss: {
            }) {
                // Update representable to pass and receive edit parameters instead of new URL
                if let videoURL = self.url {
                    VideoEditorRepresentable(videoURL: videoURL, onConfirmEditing: { parameters in
                        // Handle editing confirmation
                        DispatchQueue.main.async {
                            // Update the edit parameters to reflect the changes made
                            self.editParameters = parameters
                            // Potentially re-setup the player or apply edits as needed
                            applyEditParametersAndSetupPlayer()
                        }
                    })
                    .background(Color(red: 20/255, green: 20/255, blue: 20/255))
                    .edgesIgnoringSafeArea(.bottom)
                } else if let editingImage = self.selectedImage {
                    PhotoEditorRepresentable(editingImage: editingImage, onConfirmEditing: { parameters in
                        // Handle editing confirmation
                        DispatchQueue.main.async {
                            self.editParameters = parameters
                            // Additional actions as needed
                        }
                    })
                    .background(Color(red: 20/255, green: 20/255, blue: 20/255))
                    .edgesIgnoringSafeArea(.bottom)
                }
            }

               
    }
}

    private func setupPlayer() {
        DispatchQueue.main.async {
           
            if let videoURL = self.url {
                let playerItem = AVPlayerItem(url: videoURL)
                self.player.replaceCurrentItem(with: playerItem)
                self.player.play()
                // Setup the loop playback observer if needed...
                self.player.replaceCurrentItem(with: playerItem)
                self.player.play()
                
                // Additional step: Ensure the observer for loop playback is correctly set up
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: .main) { [self] _ in
                    self.player.seek(to: .zero)
                    self.player.play()
                }

            }

        }
    }

    private func cleanUpPlayer() {
           player.pause()
           player.replaceCurrentItem(with: nil) // Reset the player
           NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
       }
    

    
    // Assuming editParameters is already part of your FinalPreview and set appropriately
    private func applyEditParametersAndSetupPlayer() {
        // Since url is not optional, you can use it directly
        
        if let videoURL = self.url {
            let asset = AVAsset(url: videoURL)
            let playerItem = AVPlayerItem(asset: asset)

            // Apply your edit parameters to the playerItem if needed
            // Note: This placeholder for applying rotation and scaling is conceptual.
            // You might need to adjust this approach based on your app's specific requirements.
            
            let videoComposition = AVVideoComposition(asset: asset) { request in
                let rotation = CGAffineTransform(rotationAngle: self.editParameters.rotationAngle)
                let scaledAndRotatedTransform = rotation.scaledBy(x: self.editParameters.scale ?? 1.0, y: self.editParameters.scale ?? 1.0)
                let image = request.sourceImage.transformed(by: scaledAndRotatedTransform)
                request.finish(with: image, context: nil)
            }

            playerItem.videoComposition = videoComposition
            
            DispatchQueue.main.async {
                self.player.replaceCurrentItem(with: playerItem)
                self.player.play()
            }
        }
        }


}

extension Image {
    func iconStyle() -> some View {
        self
            .font(.title)
            .foregroundColor(.white)
    }
}



//#Preview {
//    CameraContainerView()
//}
