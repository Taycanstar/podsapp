import SwiftUI
import AVKit
import PhotosUI
import Photos
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
            
         
            
//            if !cameraModel.isRecording {
//                HStack {
//
//                                  Button(action: {
//                                      isShowingVideoPicker = true
//                                  }) {
//                                      Image(systemName: "photo")
//                                          
//                                          .font(.system(size: 18))
//                                          .foregroundColor(.white)
////                                          .padding(.horizontal, 10)
////                                          .padding(.vertical, 10)
////
//                                          .background(Color(red: 0, green: 0, blue: 0, opacity: 0.5))
//                                         
//                                          .background(Circle().fill(Color.black.opacity(0.5))) // Circle background
//                                          .frame(width: 60, height: 60)
//                                  }
////                                  .background(Circle().fill(Color.black.opacity(0.5))) // Circle background
//                                  .padding(.bottom, 100)
//                                  .frame(width: 60, height: 60)
//                                  .sheet(isPresented: $isShowingVideoPicker) {
//                                      PhotoPicker(isPresented: $isShowingVideoPicker, cameraViewModel: cameraModel)
//                                  }
//
//
//                    Spacer()
//                    
//                    
//                    if !cameraModel.currentPod.items.isEmpty {
//                        Button(action: {
//                            // TODO: Trigger the video picker
//                            if let previewURL = cameraModel.previewURL {
//                                   print("Preview URL: \(previewURL)")
//                                   cameraModel.showPreview = true
//                               } else {
//                                   print("No preview URL available")
//                               }
//                        }) {
//                            Image(systemName: "chevron.right")
//                                
//                                .font(.system(size: 18))
//                                .foregroundColor(.white)
//                            
////                                .padding(.horizontal, 10)
////                                .padding(.vertical, 10)
////
////                                .background(Color(red: 0, green: 0, blue: 0, opacity: 0.5)) // Style as needed
////                                .clipShape(Circle())
//                        }
//                        .background(Circle().fill(Color.black.opacity(0.5))) // Circle background
//                        .frame(width: 60, height: 60) // Example size, adjust as needed
//
//                        .padding(.bottom, 100)
//                   
//                      }
//                    }
//                  
//                   .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
//            }
//          
//            
//            if !cameraModel.isRecording {
//                HStack {
//                    // "photo" button with circular background
//                    Button(action: {
//                        isShowingVideoPicker = true
//                    }) {
//                        Image(systemName: "photo")
//                            .font(.system(size: 18))
//                            .foregroundColor(.white)
//                    }
//                    .frame(width: 40, height: 40) // Ensures the touch area is a 60x60 square
//                    .background(Circle().fill(Color.black.opacity(0.5))) // Creates the circular background
//                    .padding(.bottom, 100) // Adjust the position as needed
//                    .sheet(isPresented: $isShowingVideoPicker) {
//                        PhotoPicker(isPresented: $isShowingVideoPicker, cameraViewModel: cameraModel)
//                    }
//
//                    Spacer()
//                    
//                    if !cameraModel.currentPod.items.isEmpty {
//                        // "chevron.right" button with circular background
//                        Button(action: {
//                            // Action for the button
//                            if let previewURL = cameraModel.previewURL {
//                                print("Preview URL: \(previewURL)")
//                                cameraModel.showPreview = true
//                            } else {
//                                print("No preview URL available")
//                            }
//                        }) {
//                            Image(systemName: "chevron.right")
//                                .font(.system(size: 18))
//                                .foregroundColor(.white)
//                        }
//                        .frame(width: 40, height: 40) // Ensures the touch area is a 60x60 square
//                        .background(Circle().fill(Color.black.opacity(0.5))) // Creates the circular background
//                        .padding(.bottom, 100) // Adjust the position as needed
//                    }
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
//                .padding(15)
//            }

        
//            // Add Thumbnail Carousel
//                       if !cameraModel.currentPod.items.isEmpty {
//                           VStack {
//                               Spacer()
//                               HStack {
//                                  
//                                       ThumbnailCarouselView(items: cameraModel.currentPod.items)
//                                           .padding(.leading)
//                                    
//                                 
//                                   Spacer()
//
//                               }
//                           }
////                           .padding(.vertical, 35)
//                       }

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

                     

//            // MARK: Controls
//            ZStack{
//                Button {
//                    if cameraModel.isRecording{
//                        cameraModel.stopRecording()
//                    } else {
//                        cameraModel.startRecording()
//                    }
//                } label: {
//                    ZStack {
//                        Circle()
//                            .fill(cameraModel.isRecording ? Color.red : Color.white) // Inner circle color
//                            .frame(width: 65, height: 65) // Inner circle size
//
//                        Circle()
//                            .stroke(cameraModel.isRecording ? Color.clear : Color.white, lineWidth: 4) // Outer circle border
//                            .frame(width: 75, height: 75) // Outer circle size (including padding)
//                    }
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

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
                                RoundedRectangle(cornerRadius: 8)
    //                                .strokeBorder(Color.gray, lineWidth: 0.5)
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.black)
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
//            .opacity(!cameraModel.recordedURLs.isEmpty && cameraModel.previewURL != nil && !cameraModel.isRecording ? 1 : 0)
        }
        

        
//                .overlay(content: {
//            if let url = cameraModel.previewURL,cameraModel.showPreview{
//                
//                FinalPreview(url: url, showPreview: $cameraModel.showPreview, cameraModel: cameraModel, isFrontCameraUsed: cameraModel.isFrontCameraUsed, showCreatePodView: $showCreatePodView )
//                    .transition(.move(edge: .trailing))
//            }
//            
//            
//            
//            
//        })
//        .animation(.easeInOut, value: cameraModel.showPreview)
////        .preferredColorScheme(.dark)
//        
        
        .fullScreenCover(isPresented: $cameraModel.showPreview) {
                // Make sure to safely unwrap the `cameraModel.previewURL` or handle nil case appropriately
                if let url = cameraModel.previewURL {
                    FinalPreview(url: url, showPreview: $cameraModel.showPreview, cameraModel: cameraModel, isFrontCameraUsed: cameraModel.isFrontCameraUsed, showCreatePodView: $showCreatePodView)
                        .background(Color.black.edgesIgnoringSafeArea(.all))
                        .environment(\.colorScheme, .dark)
                }
            }

        .overlay(
                fullScreenOverlayView
            )
        Spacer() // Pushes the bar to the bottom
        
//        HStack {
//                       
//                       Rectangle() // Represents the bottom bar
//                           .foregroundColor(.black) // Set the color to black
//                           .frame(height: 60) // Set the height of the bottom bar
//                           .edgesIgnoringSafeArea(.bottom) // Ensures it goes to the edge of the screen
//                   }
        
        
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
    
    @State var url: URL
    @Binding var showPreview: Bool
     var player = AVPlayer()
    @ObservedObject var cameraModel = CameraViewModel()
    var isFrontCameraUsed: Bool
    @Binding var showCreatePodView: Bool
    @State private var isPresentingEditor = false
    @State private var editParameters = VideoEditParameters()

    
    var body: some View {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    VideoPlayer(player: player)
                        .id(url)
                        .scaleEffect(x: isFrontCameraUsed ? -1 : 1, y: 1, anchor: .center)
    //                    .edgesIgnoringSafeArea(.all)
                        .ignoresSafeArea()
                        .aspectRatio(CGSize(width: 9, height: 16), contentMode: .fill)
                        .frame(width: size.width, height: size.height)
 
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




                }
//

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
//                                    Image(systemName: "xmark")
//                                        .foregroundColor(.white)
//                                        .font(.system(size: 22))
//                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
//                                        .padding()
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
                                    cameraModel.confirmAndNavigateToCreatePod()
                                    showCreatePodView = true
                                    print("Forward arrow tapped")
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 22) // Half of height for full curvature
                                            .foregroundColor(.black)
                                            .opacity(0.4)
                                            .frame(width: 75, height: 38) // Adjust the size as needed, ensuring the cornerRadius is half of height

                                        Text("Next")
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
                            HStack {
                                Spacer()
                                Button(action: {
                                    cleanUpPlayer()
                                    cameraModel.confirmVideo()
                                }) {
                                    ZStack {
                                        Circle()
                                            .foregroundColor(.white)
                                            .frame(width: 50, height: 50) // Adjust size as needed
                                        if cameraModel.isTranscribing {
                                                        // Show a loading animation or progress view
                                                        ProgressView()
                                                            .scaleEffect(1, anchor: .center)
                                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 22))
                                                .foregroundColor(.black)
                                        }
                                    }
                                }

                            }
                            .padding(.vertical, 76)
                            
                        }
                        .padding()
                    }

//                    .sheet(isPresented: $isPresentingEditor, onDismiss: {
//                            // Handle what to do when the editor is dismissed
//                            // For example, re-setup the player if needed
//                        
//                        
//                        }) {
//                            // Update representable to pass and receive edit parameters instead of new URL
//                            VideoEditorRepresentable(videoURL: url, onConfirmEditing: { parameters in
//                                DispatchQueue.main.async {
//                                    // Update the edit parameters to reflect the changes made
//                                    self.editParameters = parameters
//                                    // Potentially re-setup the player or apply edits as needed
//                                    applyEditParametersAndSetupPlayer()
//                                }
//                            })
//                            .ignoresSafeArea()
//                        }
                    .fullScreenCover(isPresented: $isPresentingEditor, onDismiss: {
                        // Handle what to do when the editor is dismissed
                        // For example, re-setup the player if needed
                    }) {
                        // Update representable to pass and receive edit parameters instead of new URL
                        VideoEditorRepresentable(videoURL: url, onConfirmEditing: { parameters in
                            DispatchQueue.main.async {
                                // Update the edit parameters to reflect the changes made
                                self.editParameters = parameters
                                // Potentially re-setup the player or apply edits as needed
                                applyEditParametersAndSetupPlayer()
                            }
                        })
                        // .ignoresSafeArea() is optional based on your layout needs
                    }

                       
  
            }
        }
    

//    private func setupPlayer() {
//        print("Setting up player with URL: \(url)")
//        let playerItem = AVPlayerItem(url: url)
//        self.player.replaceCurrentItem(with: playerItem)
//        self.player.play()
//    }
    private func setupPlayer() {
        DispatchQueue.main.async {
            print("Setting up player with URL: \(self.url)")
            let playerItem = AVPlayerItem(url: self.url)
            self.player.replaceCurrentItem(with: playerItem)
            self.player.play()
            
            // Additional step: Ensure the observer for loop playback is correctly set up
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: .main) { [self] _ in
                self.player.seek(to: .zero)
                self.player.play()
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
        let videoURL = self.url

        // Create an AVAsset and AVPlayerItem from your video URL
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
