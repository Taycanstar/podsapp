import SwiftUI
import AVKit
import PhotosUI
import UniformTypeIdentifiers
//
//
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var cameraViewModel: CameraViewModel
   

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .videos
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
                self.parent.cameraViewModel.isProcessingVideo = true // Start loading immediately

                provider.loadDataRepresentation(forTypeIdentifier: UTType.movie.identifier) { data, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Error loading video data: \(error.localizedDescription)")
                            self.parent.cameraViewModel.isProcessingVideo = false // Stop loading if error
                            return
                        }
                        
                        guard let data = data, let url = self.writeDataToTemporaryLocation(data: data) else {
                            print("Unable to write video data to temporary location.")
                            self.parent.cameraViewModel.isProcessingVideo = false // Stop loading if unable to write data
                            return
                        }

                        // Process the selected video
                        self.parent.cameraViewModel.handleSelectedVideo(url)
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
    


    
    var body: some View {
        ZStack {
            // MARK: Camera View
            AltCameraView()
                .environmentObject(cameraModel)
            
                .fullScreenCover(isPresented: $showCreatePodView) {
                              CreatePodView(pod: $cameraModel.currentPod)
                                  // Pass any required environment objects or parameters
                          }
     
            // Add a button to reset the current pod
                      if !cameraModel.currentPod.items.isEmpty  {
                          Button(action: {
                              // Reset the current pod and any other necessary states
                              cameraModel.currentPod = Pod(title: "")
                              cameraModel.recordedDuration = 0
                              cameraModel.previewURL = nil
                              cameraModel.recordedURLs.removeAll()
                          }) {
                              Image(systemName: "xmark")
                                  
                                  .foregroundColor(.white)
                                  .font(.system(size: 22))
                                  .padding()
                          }
                          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                          .padding(.top, 20)
                          .padding(.leading, 0)
                        
                      }
            
            if !cameraModel.isRecording {
                HStack {

                                  Button(action: {
                                      isShowingVideoPicker = true
                                  }) {
                                      Image(systemName: "photo")
                                          
                                          .font(.system(size: 18))
                                          .foregroundColor(.white)
                                          .padding(.horizontal, 10)
                                          .padding(.vertical, 10)

                                          .background(Color(red: 0, green: 0, blue: 0, opacity: 0.5)) // Style as needed
                                          .clipShape(Circle())
                                  }
                                  .padding(.bottom, 100)
                                  .frame(width: 60, height: 60)
                                  .sheet(isPresented: $isShowingVideoPicker) {
                                      PhotoPicker(isPresented: $isShowingVideoPicker, cameraViewModel: cameraModel)
                                  }


                    Spacer()
                    
                    
                    if !cameraModel.currentPod.items.isEmpty {
                        Button(action: {
                            // TODO: Trigger the video picker
                            if let previewURL = cameraModel.previewURL {
                                   print("Preview URL: \(previewURL)")
                                   cameraModel.showPreview = true
                               } else {
                                   print("No preview URL available")
                               }
                        }) {
                            Image(systemName: "chevron.right")
                                
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)

                                .background(Color(red: 0, green: 0, blue: 0, opacity: 0.5)) // Style as needed
                                .clipShape(Circle())
                        }
                        .frame(width: 60, height: 60) // Example size, adjust as needed

                        .padding(.bottom, 100)
                   
                      }
                    }
                  
                   .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
          
        
            // Add Thumbnail Carousel
                       if !cameraModel.currentPod.items.isEmpty {
                           VStack {
                               Spacer()
                               HStack {
                                   ThumbnailCarouselView(items: cameraModel.currentPod.items)
                                       .padding(.leading)
                                   Spacer()
                               }
                           }
                           .padding(.vertical, 25)
                       }
          
            // Floating Camera Control Buttons
            if !cameraModel.isRecording {
                VStack(spacing: 0) {  // Adjust spacing as needed
                    Button(action: cameraModel.switchCamera) {
                        Image(systemName: "arrow.triangle.capsulepath")
                            .font(.title)
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                            .padding()
                    }
                    Button(action: cameraModel.toggleFlash) {
                        Image(systemName: cameraModel.isFlashOn ? "bolt" : "bolt.slash")
                            .font(.title)
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                            .padding()
                    }
                }
                .position(x: UIScreen.main.bounds.width - 33, y: 80)
            }

                     
            
            // MARK: Controls
            ZStack{
                
                Button {
                    if cameraModel.isRecording{
                        cameraModel.stopRecording()
                    }
                    else{
                        cameraModel.startRecording()
                    }
                } label: {
                    Image("Reels")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.black)
                        .opacity(cameraModel.isRecording ? 0 : 1)
                        .padding(12)
                        .frame(width: 60, height: 60)
                        .background{
                            Circle()
                                .stroke(cameraModel.isRecording ? .clear : .black)
                        }
                        .padding(6)
                        .background{
                            Circle()
                                .fill(cameraModel.isRecording ? .red : .white)
                        }
                }
                

            }
            .frame(maxHeight: .infinity,alignment: .bottom)
           
            .padding(.bottom,20)
            
            Button {
                cameraModel.recordedDuration = 0
                cameraModel.previewURL = nil
                cameraModel.recordedURLs.removeAll()
            } label: {
                Image(systemName: "xmark")
                    .font(.title)
                    .foregroundColor(.white)
            }

            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .padding(.top)
            .opacity(!cameraModel.recordedURLs.isEmpty && cameraModel.previewURL != nil && !cameraModel.isRecording ? 1 : 0)
        }
        

        
        
        .overlay(content: {
            if let url = cameraModel.previewURL,cameraModel.showPreview{
                
                FinalPreview(url: url, showPreview: $cameraModel.showPreview, cameraModel: cameraModel, isFrontCameraUsed: cameraModel.isFrontCameraUsed, showCreatePodView: $showCreatePodView )
                    .transition(.move(edge: .trailing))
            }
            
            
            
            
        })
        .animation(.easeInOut, value: cameraModel.showPreview)
        .preferredColorScheme(.dark)
        
        .overlay(
                fullScreenOverlayView
            )
    }
    
    private func handleSelectedVideoURL() async {
         if let url = selectedVideoURL {
             // Set it as the preview URL and show the preview
             cameraModel.previewURL = url
             cameraModel.showPreview = true
             selectedVideoURL = nil // Reset after handling
         }
     }
    
    private var fullScreenOverlayView: some View {
         Group {
             if cameraModel.isProcessingVideo {
                 ZStack {
                     // Changed the background color to the specified RGB value
                     Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
                         
                         .ignoresSafeArea() // Ensures the overlay covers the full screen
                     
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





struct FinalPreview: View {
    
    var url: URL
    @Binding var showPreview: Bool
    private let player = AVPlayer()
    @ObservedObject var cameraModel = CameraViewModel()
    var isFrontCameraUsed: Bool
    @Binding var showCreatePodView: Bool
    

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            VideoPlayer(player: player)
                .scaleEffect(x: isFrontCameraUsed ? -1 : 1, y: 1, anchor: .center)
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .onAppear {
                    setupPlayer()
                }
                .onDisappear {
                    cleanUpPlayer()
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
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 22))
                                    .padding() // Adds more tappable area around the icon
                            }
                            .padding(.leading, -15)
                            Spacer()
                            Button(action: {
                                cleanUpPlayer()
                                cameraModel.confirmAndNavigateToCreatePod()
                                   showCreatePodView = true
                                print("Forward arrow tapped")
                            }) {
                                ZStack {
                                    Circle()
                                        .foregroundColor(.black)
                                        .frame(width: 44, height: 44)  // Adjust the size as needed

                                    Image(systemName: "arrow.forward")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .scaleEffect(0.8)  // Adjust the scale to fit the icon within the black circle
                                }
                            }                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                cleanUpPlayer()
                                cameraModel.confirmVideo()
                            }) {
                                ZStack {
                                    Circle()
                                        .foregroundColor(.blue)
                                        .frame(width: 44, height: 44) // Adjust size as needed
                                    if cameraModel.isTranscribing {
                                                    // Show a loading animation or progress view
                                                    ProgressView()
                                                        .scaleEffect(1, anchor: .center)
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                    }
                                }
                            }

                        }
                        .padding(.vertical, 30)
                        
                    }
                    .padding()
                }
        }
    }

    private func setupPlayer() {
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }
    private func cleanUpPlayer() {
           player.pause()
           player.replaceCurrentItem(with: nil) // Reset the player
           NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
       }
}

extension Image {
    func iconStyle() -> some View {
        self
            .font(.title)
            .foregroundColor(.white)
    }
}


#Preview {
    CameraContainerView()
}
