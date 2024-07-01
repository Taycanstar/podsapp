//import SwiftUI
//import AVKit
//import PhotosUI
//import Photos
//import UniformTypeIdentifiers
//
//
//struct PhotoPicker: UIViewControllerRepresentable {
//    @Binding var isPresented: Bool
//    var cameraViewModel: CameraViewModel
//
//    func makeUIViewController(context: Context) -> PHPickerViewController {
//        var config = PHPickerConfiguration()
//        config.selectionLimit = 1
//        // Allow both photos and videos
//        config.filter = .any(of: [.images, .videos])
//        
//        let picker = PHPickerViewController(configuration: config)
//        picker.delegate = context.coordinator
//        return picker
//    }
//
//    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//
//    class Coordinator: NSObject, PHPickerViewControllerDelegate {
//        let parent: PhotoPicker
//
//        init(_ parent: PhotoPicker) {
//            self.parent = parent
//        }
//
//        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
//            parent.isPresented = false // Dismiss the picker immediately
//            guard let provider = results.first?.itemProvider else {
//                print("No provider found for the selected item.")
//                return
//            }
//
//            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
//                processVideo(provider: provider)
//            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
//                processImage(provider: provider)
//            }
//        }
//
//        private func processVideo(provider: NSItemProvider) {
//            provider.loadDataRepresentation(forTypeIdentifier: UTType.movie.identifier) { data, error in
//                DispatchQueue.main.async {
//                    if let error = error {
//                        print("Error loading video data: \(error.localizedDescription)")
//                        return
//                    }
//
//                    guard let data = data, let url = self.writeDataToTemporaryLocation(data: data) else {
//                        print("Unable to write video data to temporary location.")
//                        return
//                    }
//
//                    // Process the selected video
//                    self.parent.cameraViewModel.handleSelectedVideo(url)
//                }
//            }
//        }
//
//        private func processImage(provider: NSItemProvider) {
//            provider.loadObject(ofClass: UIImage.self) { (object, error) in
//                DispatchQueue.main.async {
//                    if let error = error {
//                        print("Error loading image: \(error.localizedDescription)")
//                    }
//                    if let image = object as? UIImage {
//                        print("Successfully selected image: \(image)")
//                        self.parent.cameraViewModel.handleSelectedImage(image)
//                    } else {
//                        print("No image found in the provider.")
//                    }
//                }
//            }
//        }
//
//
//        private func writeDataToTemporaryLocation(data: Data) -> URL? {
//            let tempDirectory = FileManager.default.temporaryDirectory
//            let tempUrl = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
//
//            do {
//                try data.write(to: tempUrl)
//                return tempUrl
//            } catch {
//                print("Error writing video data to temporary location: \(error)")
//                return nil
//            }
//        }
//    }
//}
//
//
//
//
//
//
//// Create the WheelPicker view
//struct WheelPicker: View {
//    @Binding var selectedMode: CameraMode
//    @ObservedObject var cameraViewModel: CameraViewModel
//    
//    var body: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: 20) {
//                ForEach(CameraMode.allCases, id: \.self) { mode in
//                    Text(mode.rawValue)
//                        .padding(.vertical, 5)
//                        .padding(.horizontal, 10)
//                        .background(self.selectedMode == mode ? Color.white : Color.clear)
//                        .foregroundColor(self.selectedMode == mode ? .black : .white)
//                        .clipShape(Capsule())
//                        .onTapGesture {
//                            self.selectedMode = mode
//                           self.cameraViewModel.selectedCameraMode = mode
//                           // Ensure session is configured for the new mode
//                           self.cameraViewModel.configureSessionFor(mode: mode)
//                           // Directly use the duration property
//                            self.cameraViewModel.maxDuration = CGFloat(mode.duration)
//                        }
//                        .animation(.easeInOut, value: selectedMode)
//                }
//            }
//            .padding(.horizontal, 5)
//        }
//    }
//}
//
//
//
//
//
//struct CameraContainerView: View {
//    @StateObject var cameraModel = CameraViewModel()
//    @State private var showCreatePodView = false
//    @State private var isShowingVideoPicker = false
//    @State private var selectedVideoURL: URL?
//    @State private var isProcessingVideo = false
//    @State private var showingVoiceCommandPopup = false
//    @State private var voiceCommandPopupMessage: String? = nil
//    @Binding var showingVideoCreationScreen: Bool
//    @State private var latestPhoto: UIImage? = nil
//    @State private var showTranscribeLabel = true
//    @State private var showCommandLabel = true
//    @Binding var selectedTab: Int
//   
//    
//    @EnvironmentObject var uploadViewModel: UploadViewModel
//    
//    
//    var body: some View {
//        ZStack {
//            // MARK: Camera View
//            AltCameraView()
//
//                .onAppear {
//                                
//                                 cameraModel.checkPermission()
////                                cameraModel.setUp()
////                                cameraModel.configureSpeechService()
//                    
//                    // Set labels to disappear after 4 seconds
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
//                        showTranscribeLabel = false
//                        showCommandLabel = false
//                    }
//                             }
//                .onDisappear {
//                                    cameraModel.deactivateAudioSession()
////                                    cameraModel.deactivateSpeechService()
//                                    cameraModel.stopAudioRecorder()
//                                }
//                .environmentObject(cameraModel)
// 
//                .fullScreenCover(isPresented: $showCreatePodView) {
//                    CreatePodView(pod: $cameraModel.currentPod, showingVideoCreationScreen: $showingVideoCreationScreen, selectedTab: $selectedTab)
//                    // Pass any required environment objects or parameters
//                }
//
//            
//            if !cameraModel.isRecording {
//                Button(action: {
//                    // Instead of resetting properties, just close the video creation screen
//                    showingVideoCreationScreen = false
//                }) {
//                    Image(systemName: "xmark")
//                        .foregroundColor(.white)
//                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
//                        .font(.system(size: 22))
//                        .padding()
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//                .padding(.top, 15)
//                .padding(.leading, 5)
//                .padding(.leading, 0)
//                
//            }
//            
//            
//            
//            
//            
//            // Floating Camera Control Buttons
//            if !cameraModel.isRecording {
//                VStack(spacing: 0) {  // Adjust spacing as needed
//                    Button(action: cameraModel.switchCamera) {
//                        Image(systemName: "arrow.triangle.capsulepath")
//                            .font(.title)
//                            .foregroundColor(.white)
//                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
//                            .font(.system(size: 16))
//                            .padding()
//                    }
//                    if cameraModel.selectedCameraMode == .photo {
//                        Button(action: {
//                         
//                                   cameraModel.toggleFlashForPhotoMode()
//                            
//                               
//                        }) {
//                            Image(systemName: getFlashIcon())
//                                .font(.title)
//                                .font(.system(size: 16))
//                                .foregroundColor(.white)
//                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
//                                .padding()
//                        }
//                    } else {
//                        Button(action: cameraModel.toggleFlash) {
//                                               Image(systemName: cameraModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
//                                                   .font(.title)
//                                                   .foregroundColor(.white)
//                                                   .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
//                                                   .font(.system(size: 16))
//                                                   .padding()
//                                        }
//                    }
//                   
//                    
//                    
//                    Button(action: {
//                  
////                            cameraModel.isWaveformEnabled.toggle()
//                        cameraModel.toggleWaveform()
//                    
////                        cameraModel.toggleWaveform()
//                        // Set the message based on the waveform state
//                        print("Waveform Enabled State: \(cameraModel.isWaveformEnabled)")
//                        voiceCommandPopupMessage = cameraModel.isWaveformEnabled ? "Video transcription on" : "Video transcription off"
//                        
//                        // Show the message
//                        withAnimation {
//                            showingVoiceCommandPopup = true
//                        }
//                        
//                        // Hide the popup after a few seconds and reset the message
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
//                            showingVoiceCommandPopup = false
//                            // Reset the message after the animation completes to ensure it's ready for the next toggle
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                                voiceCommandPopupMessage = nil
//                            }
//                        }
//                    }) {
//                        Image(systemName: "waveform")
//                            .font(.title)
//                            .foregroundColor(cameraModel.isWaveformEnabled ? Color(red: 70/255, green: 87/255, blue: 245/255) : .white)
//                            .font(.system(size: 16))
//                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
//                            .overlay(
//                                           Text("Transcribe video")
//                                            .font(.system(size: 14))
//                                            .fontWeight(.semibold)
//                                               .foregroundColor(.white)
//                                               .opacity(showTranscribeLabel ? 1.0 : 0.0) // Control opacity of the label only
//                                            .fixedSize()
//                                               .offset(x: -120) // Adjust position relative to the icon
//                                           , alignment: .leading
//                                       )
//                            .padding()
//
//                    }
//                    
//                    //Mic
////                    Button(action: {
////                        cameraModel.toggleVoiceCommands()
////                        // Set the message based on the waveform state
////                        voiceCommandPopupMessage = cameraModel.isVcEnabled ? "Voice control on" : "Voice control off"
////                        
////                        // Show the message
////                        withAnimation {
////                            showingVoiceCommandPopup = true
////                        }
////                        
////                        // Hide the popup after a few seconds and reset the message
////                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
////                            showingVoiceCommandPopup = false
////                            // Reset the message after the animation completes to ensure it's ready for the next toggle
////                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
////                                voiceCommandPopupMessage = nil
////                            }
////                        }
////                    }) {
////                        Image(systemName: "sparkles")
////                            .font(.title)
////                            .foregroundColor(cameraModel.isVcEnabled ? Color(red: 70/255, green: 87/255, blue: 245/255) : .white)
////                            .font(.system(size: 16))
////                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
////                            .overlay(
////                                           Text("Voice control")
////                                            .font(.system(size: 14))
////                                            .fontWeight(.semibold)
////                                               .foregroundColor(.white)
////                                               .opacity(showCommandLabel ? 1.0 : 0.0) // Control opacity of the label only
////                                            .fixedSize()
////                                               .offset(x: -100) // Adjust position relative to the icon
////                                           , alignment: .leading
////                                       )
////                            .padding()
////        
////                            
////                    }
//                    
//                }
//                .position(x: UIScreen.main.bounds.width - 28, y: 130)
//            }
//            
//            if let message = voiceCommandPopupMessage {
//                VStack {
//                    VoiceCommandPopupView(message: message)
//                        .padding(.top, 20) // Adjust this value to ensure it doesn't overlap with the notch or status bar
//                        .transition(.move(edge: .top).combined(with: .opacity))
//                        .animation(.easeInOut, value: UUID())
//                        .padding(.horizontal, 10)
//                    
//                    Spacer() // Pushes the popup to the top
//                }
//                .zIndex(1) // Ensure it's above other content
//            }
//            
//  
//                VStack(spacing: 10){
//                    Spacer()
//                    
//                              if !cameraModel.isRecording {
//                                  HStack{
//                                      Spacer()
//                                      WheelPicker(selectedMode: $cameraModel.selectedCameraMode, cameraViewModel: cameraModel)
//                                                 .background(Color.clear) // Just to highlight the ScrollView area
//                                                 .frame(width: 200)
//                                                 .zIndex(3)
//              //                                   .frame(maxWidth: .infinity)
//                                      Spacer()
//                                  }
//                                  .frame(maxWidth: .infinity)
//                              }
//                
//                   
//                    
//                    HStack(spacing: 55) { // This HStack contains all main elements
//
//                        if !cameraModel.isRecording {
//                            if !cameraModel.currentPod.items.isEmpty {
//                                    // Thumbnail Carousel
//                                    ThumbnailCarouselView(items: cameraModel.currentPod.items)
//            //                            .frame(width: 40, height: 40)
//                                    .frame(width: 40, height: 40)
//                                    .padding(.top, -5)
//                               
//                                           
//                                } else {
//                                    // Invisible Placeholder when there are no items
//                                    VStack {
//                                        Color.clear
//                                            .frame(width: 40, height: 40)
//                                        Text(" ")
//                                            .font(.footnote)
//                                            .fontWeight(.semibold)
//                                            .foregroundColor(.clear)
//                                    }
//                                }
//                        } else {
//                        
//                            VStack {
//                                Color.clear
//                                    .frame(width: 40, height: 40)
//                                Text(" ")
//                                    .font(.footnote)
//                                    .fontWeight(.semibold)
//                                    .foregroundColor(.clear)
//                            }
//                            
//                       
//                        }
//                   
//                        Button(action: {
//                                  if cameraModel.selectedCameraMode == .photo {
//                                      cameraModel.takePhoto()
//                                  } else if cameraModel.isRecording {
//                                      cameraModel.stopRecording()
//                                  } else {
//                                      cameraModel.startRecordingBasedOnMode()
//                                  }
//                              }) {
//                                  ZStack {
//                                      if cameraModel.selectedCameraMode == .photo {
//                                          Circle()
//                                              .fill(Color.white) // Inner circle color
//                                              .frame(width: 65, height: 65) // Inner circle size
//
//                                          Circle()
//                                              .stroke(Color.white, lineWidth: 4) // Outer circle border
//                                              .frame(width: 75, height: 75) // Outer circle size (including padding)
//                                      } else {
//                                          Circle()
//                                              .fill(Color(red: 230/255, green: 55/255, blue: 67/255)) // Inner circle color
//                                              .frame(width: cameraModel.isRecording ? 25 : 65, height: cameraModel.isRecording ? 25 : 65) // Transition to square size
//                                              .animation(.easeInOut(duration: 0.3), value: cameraModel.isRecording)
//
//                                          Circle()
//                                              .stroke(Color.white, lineWidth: 4) // Outer circle border
//                                              .frame(width: 75, height: 75) // Outer circle size (including padding)
//                                              .opacity(cameraModel.isRecording ? 0 : 1)
//                                              .animation(.easeInOut(duration: 0.3), value: cameraModel.isRecording)
//
//                                          Circle()
//                                              .fill(cameraModel.isRecording ? Color.white.opacity(0.3) : Color.clear)
//                                              .frame(width: 75, height: 75)
//                                              .animation(.easeInOut(duration: 0.3), value: cameraModel.isRecording)
//
//                                          RoundedRectangle(cornerRadius: cameraModel.isRecording ? 8 : 32)
//                                              .fill(Color(red: 230/255, green: 55/255, blue: 67/255))
//                                              .frame(width: cameraModel.isRecording ? 25 : 0, height: cameraModel.isRecording ? 25 : 0)
//                                              .animation(.easeInOut(duration: 0.3), value: cameraModel.isRecording)
//                                      }
//                                  }
//                              }
//                      
//                        
//                        if !cameraModel.isRecording {
//                            
//                            VStack {
//                                if let latestPhoto = latestPhoto {
//                                    Button(action: {
//                                        // Trigger upload functionality
//                                        isShowingVideoPicker = true
//                                      
//                                    }) {
//                                        Image(uiImage: latestPhoto)
//                                            .resizable()
//                                            .scaledToFill()
//                                            .frame(width: 40, height: 40) // Adjust size as needed
//                                            .clipShape(RoundedRectangle(cornerRadius: 8))
//                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
//                                    }
//                                } else {
//                                    Button(action: {
//                                        // Placeholder or action for when no photo is available
//                                    }) {
//                                        Image("ms")
//                                            .resizable()
//                                            .scaledToFill()
//                                            .frame(width: 40, height: 40) // Adjust size as needed
//                                            .clipShape(RoundedRectangle(cornerRadius: 8))
//                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
//                                    }
//                                }
//                                Text("Upload") // This ensures the text is below the button
//                                    .font(.footnote)
//                                    .fontWeight(.semibold)
//                                    .foregroundColor(.white)
//                            }
//                            .sheet(isPresented: $isShowingVideoPicker) {
//                                PhotoPicker(isPresented: $isShowingVideoPicker, cameraViewModel: cameraModel)
//                            }
//                        } else {
//                            VStack {
//                                Color.clear
//                                    .frame(width: 40, height: 40)
//                                Text(" ")
//                                    .font(.footnote)
//                                    .fontWeight(.semibold)
//                                    .foregroundColor(.clear)
//                            }
//                            
//                        }
//
//                       
//                        
//                        
//                    }
////                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
////                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    
//                    .padding(.bottom,15)
//                    .padding()
////                    .padding(.top)
//                    
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//
//            }
//   
//        .fullScreenCover(isPresented: $cameraModel.showPreview) {
//            if let url = cameraModel.previewURL {
//                // Present with video URL
//                FinalPreview(url: url, selectedImage: nil, showPreview: $cameraModel.showPreview, cameraModel: cameraModel, isFrontCameraUsed: cameraModel.isFrontCameraUsed, showCreatePodView: $showCreatePodView)
//                    .background(Color.black.edgesIgnoringSafeArea(.all))
//                    .environment(\.colorScheme, .dark)
//            } else if let selectedImage = cameraModel.selectedImage {
//                // Present with image
//               
//                FinalPreview(url: nil,  selectedImage: selectedImage, showPreview: $cameraModel.showPreview, cameraModel: cameraModel, isFrontCameraUsed: cameraModel.isFrontCameraUsed, showCreatePodView: $showCreatePodView)
//                    .background(Color.black.edgesIgnoringSafeArea(.all))
//                    .environment(\.colorScheme, .dark)
//            }
//        }
//
//
//        .overlay(
//                fullScreenOverlayView
//            )
//        Spacer() // Pushes the bar to the bottom
//        
//
//        if !cameraModel.isRecording {
//            HStack(spacing: 10) { // Spacing between buttons is 10
//                // Start Over Button
//                
//                if !cameraModel.currentPod.items.isEmpty {
//                    Button("Start over") {
//                        // Action for Start Over
//                        cameraModel.currentPod = Pod(id: -1, items:[],title: "")
//                        cameraModel.recordedDuration = 0
//                        cameraModel.previewURL = nil
//                    }
//                    .foregroundColor(.black) // Text color
//                    .padding(.vertical, 15) // Padding for thickness
//                    .frame(maxWidth: .infinity) // Make button expand
//                    .background(Color.white)
//                    .cornerRadius(8) // Rounded corners
//                    .fontWeight(.semibold)
//
//
//                    Button("Next") {
//                        // Check if there's either a video URL or a selected image available for preview
//                        if cameraModel.previewURL != nil || cameraModel.selectedImage != nil {
//                            cameraModel.showPreview = true
//                        } else {
//                            print("No preview content available")
//                            print(cameraModel.previewURL, "url")
//                     
//                        }
//                    }
//                    .foregroundColor(.white) // Text color for the Next button
//                    .padding(.vertical, 15) // Padding for thickness
//                    .frame(maxWidth: .infinity) // Make button expand
//                    .fontWeight(.semibold)
//                    .background(Color(red: 57/255, green: 106/255, blue: 247/255))
//                    .cornerRadius(8) // Rounded corners
//                } else{
//                    Rectangle()
//                        .foregroundColor(.black)
//                }
//         
//            }
//            .padding(.horizontal, 10) // Horizontal padding from the screen edges, 10 points on each side
//            .frame(height: 60) // Set the height of the bottom bar
//            .background(Color.black) // Set the color to black
//            .edgesIgnoringSafeArea(.bottom) // Ensures it goes to the edge of the screen
//
//            .onAppear {
//                let initialMode: CameraMode = .fifteen
//                    
//                    // Ensure session is configured for the initial mode
//                    cameraModel.configureSessionFor(mode: initialMode)
//                    
//                    // Update maxDuration based on the initial mode
//                    cameraModel.maxDuration = initialMode == .fifteen ? 15.0 : 30.0
//                      // Request authorization and fetch latest photo
//                      PHPhotoLibrary.requestAuthorization { status in
//                          if status == .authorized {
//                              self.fetchLatestPhoto { photo in
//                                  self.latestPhoto = photo
//                              }
//                          }
//                      }
//                  }
//        } else {
//            HStack { // This empty HStack ensures it covers the same height as the buttons
//                   Spacer()
//               }
//               .frame(height: 60)
//        }
//        
//
//
//        
//    }
//    
//    private func getFlashIcon() -> String {
//        if cameraModel.selectedCameraMode == .photo {
//            // For photo mode, you might want to check a different property or condition
//            // This assumes `isFlashIntendedForPhoto` exists and is managed accordingly
//            return cameraModel.isFlashIntendedForPhoto ? "bolt" : "bolt.slash"
//        } else {
//            // For video mode, you can use the existing `isFlashOn` state
//            return cameraModel.isFlashOn ? "bolt" : "bolt.slash"
//        }
//    }
//    
//    private func handleSelectedVideoURL() async {
//         if let url = selectedVideoURL {
//             // Set it as the preview URL and show the preview
//             cameraModel.previewURL = url
//             cameraModel.showPreview = true
//             selectedVideoURL = nil // Reset after handling
//         }
//        
//      
//     }
//    
//    
//
//    func fetchLatestPhoto(completion: @escaping (UIImage?) -> Void) {
//        let fetchOptions = PHFetchOptions()
//        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
//        fetchOptions.fetchLimit = 1
//
//        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
//        guard let lastAsset = fetchResult.firstObject else {
//            completion(nil)
//            return
//        }
//
//        let options = PHImageRequestOptions()
//        options.version = .current
//        options.isSynchronous = true
//
//        PHImageManager.default().requestImage(for: lastAsset, targetSize: CGSize(width: 60, height: 60), contentMode: .aspectFill, options: options) { image, _ in
//            completion(image)
//        }
//    }
//
//    
//    
//    
//    private var fullScreenOverlayView: some View {
//         Group {
//             if cameraModel.isProcessingVideo {
//                 ZStack {
//                     // Changed the background color to the specified RGB value
//                     Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
//                         
//                         .ignoresSafeArea(.all)
//                     // Customized ProgressView for a larger display
//                     ProgressView()
//                         .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                         .scaleEffect(2) // Scale up the ProgressView to make it larger
//                         .foregroundColor(.white)
//                 }
//             }
//         }
//     }
//    
//        func setUpAudio() {
//            do {
//                // Set up the audio session for recording
//                let audioSession = AVAudioSession.sharedInstance()
//                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker, .allowBluetooth])
//                try audioSession.setActive(true)
//    
//            
//            } catch {
//                print("Error setting up video/audio input or audio session: \(error)")
//            }
//        }
//       
//}
//
//
//
//extension View {
//    func alignAsFloating() -> some View {
//        self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
//    }
//}
//
//struct VoiceCommandPopupView: View {
//    let message: String
//
//    var body: some View {
//        Text(message)
//            .font(.system(size: 14))
//            .fontWeight(.semibold)
//            .padding(15)
//            .background(Color(red: 66 / 255, green: 66 / 255, blue: 66 / 255))
//            .foregroundColor(.white)
//            .cornerRadius(100)
//            .frame(width: 300) // Set a fixed width for the popup
//    }
//}
//
//
//
//struct FinalPreview: View {
//    
//    @State var url: URL?
//    @State var selectedImage: UIImage?
//    @Binding var showPreview: Bool
//     var player = AVPlayer()
//    @ObservedObject var cameraModel = CameraViewModel()
//    var isFrontCameraUsed: Bool
//    @Binding var showCreatePodView: Bool
//    @State private var isPresentingEditor = false
//    @State private var editParameters = VideoEditParameters()
//    private let blackSegmentHeight: CGFloat = 100
//    var videoAspectRatio: CGFloat = 9 / 16
//    @State private var isMuted: Bool = false
//    @State private var showAddLabel: Bool = true
//
//    
//    var body: some View {
//
//            GeometryReader { proxy in
//                let size = proxy.size
//                let screenWidth = size.width
//                           // Calculate video height based on its aspect ratio
//                let videoHeight = screenWidth * (1 / videoAspectRatio)
//                           // Calculate the remaining height for the bottom segment
//                let bottomSegmentHeight = max(proxy.size.height - videoHeight, 0)
//
//
//                VStack(spacing:0) {
//                    
//                    ZStack{
//                        if let url = cameraModel.previewURL, FileManager.default.fileExists(atPath: url.path) {
//                            CustomVideoPlayer(player: player)
//                                .onAppear {
//                                    setupPlayer()
//                                }
//                                .onDisappear {
//                                    cleanUpPlayer()
//                                }
//                                        .frame(width: screenWidth, height: videoHeight)
////                                        .offset(y: -30)
//                                        .onTapGesture {
//                                            // Toggle play/pause directly on the player
//                                            if player.timeControlStatus == .playing {
//                                                player.pause()
//                                            } else {
//                                                player.play()
//                                            }
//                                        }
//                                        .scaleEffect(x: isFrontCameraUsed ? -1 : 1, y: 1, anchor: .center)
//                                        .id(url)
//                                        
//
//                              } else
//                        if let image = cameraModel.selectedImage {
//                              
//                                  Image(uiImage: image)
//                                      .resizable()
//                                      .aspectRatio(contentMode: .fill)
//                                      .clipped()
////                                      .scaleEffect(x: isFrontCameraUsed ? -1 : 1, y: 1, anchor: .center)
//                                      .frame(width: screenWidth, height: videoHeight)
//                              }
//                        
////                        VStack {
////                            HStack {
////                                Spacer() // Pushes the button to the right
////                                Button(action: {
////                                    isMuted.toggle()
////                                    player.isMuted = isMuted
////                                }) {
////                                    Image(systemName: isMuted ? "speaker.minus.fill" : "speaker.wave.2.fill")
////                                        .font(.title)
////                                        .foregroundColor(.white)
////                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
////                                        .font(.system(size: 16))
////                                        .padding()
////                                }
////                                .padding(.top, 44) // Adjust for safe area and desired spacing
////                                .padding(.trailing, 15) // Right padding
////                            }
//                            
//                            // start
//                            
////                                                      Button(action: {
////                                                          //action here
////                                                          cameraModel.toggleRecordingAudio()
////                                                          if cameraModel.isRecordingAudio {
////                                                              cameraModel.recordingTimeElapsed = 0 // Reset the timer when starting
////                                                          }
////                                                      }) {
////                                                        
////                                                          HStack {
////                                                              Spacer() // Pushes the button to the right
////                                                              Image(systemName: "mic.fill")
////                                                                  .font(.title)
////                                                                  .foregroundColor(cameraModel.isRecordingAudio ? Color(red: 230/255, green: 55/255, blue: 67/255) : Color.white)
////                                                                  .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
////                                                                  .overlay(
////                                                                      Text(cameraModel.isRecordingAudio ? cameraModel.formatTime(seconds: Int(cameraModel.recordingTimeElapsed)) : "Add label")
////                                                                          .font(.system(size: 14))
////                                                                          .fontWeight(.semibold)
////                                                                          .foregroundColor(.white)
////                                                                          .opacity(showAddLabel ? 1.0 : 0.0) // Control opacity of the label only
////                                                                          .fixedSize()
////                                                                          .offset(x: cameraModel.isRecordingAudio ? -50 : -68)
////                                                                      , alignment: .leading
////                                                                  )
////                                                                  .font(.system(size: 16))
////                                                          }
////                                                          .background(.blue)
////                                                          .padding(.top, 44) // Adjust for safe area and desired spacing
////                                                          .padding(.trailing, 15) // Right padding
////                                                          
////                                                      }
////                                                      .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
////                                                          if cameraModel.isRecordingAudio {
////                                                              cameraModel.recordingTimeElapsed += 1
////                                                          }
////                                                      }
//                            //end
//                            Spacer() // Pushes everything up
////                        }
////                    
////                    .clipped()
//
//                    Spacer()
//                        VStack {
//                                         Spacer()
//                                         HStack(spacing: 40) {
//                                             // Chevron left with label "Back"
//                                             VStack {
//                                                 Button(action: {
//                                                     DispatchQueue.global(qos: .userInitiated).async {
//                                                         DispatchQueue.main.async {
//                                                             // Action for back
//                                                             if cameraModel.currentPod.items.isEmpty {
//                                                                 // If it's the first item (Pod is empty), just close the preview
//                                                                 // This essentially cancels the recording
//                                                                 showPreview = false
//                                                             } else {
//                                                                 // If Pod has items, prepare to re-record the current item
//                                                                 // This keeps the Pod items intact but allows for re-recording
//                                                                 cameraModel.reRecordCurrentItem()
//                                                                 showPreview = false
//                                                             }
//                                                             
//                                                             cleanUpPlayer()
//                                                         }
//                                                     }
//                                                
////                                                cameraModel.configureSessionFor(mode: .fifteen)
//                                                 }) {
//                                                     Image(systemName: "chevron.left")
//                                                         .foregroundColor(.white)
//                                                         .font(.system(size: 18))
//                                                         .frame(width: 44, height: 44)
//                                                         .background(Color(red: 75/255, green: 75/255, blue: 75/255).opacity(0.4))
//                                                         .clipShape(Circle())
//                                                         
//                                                 }
//                                                 Text("Back")
//                                                     .foregroundColor(.white)
//                                                     .font(.system(size: 12))
//                                                     .fontWeight(.medium)
//                                             }
//                                             
//                                          
//                                                 Button(action: {
//                                                     // Action for checkmark/save
//                                                     
//                                                     DispatchQueue.global(qos: .userInitiated).async {
//                                                         if let _ = cameraModel.previewURL {
//                                                                 // It's a video
//                                                                 cameraModel.confirmVideo()
//                                                     
//                                                             } else if cameraModel.selectedImage != nil {
//                                                                 // It's a photo
//                                                                 cameraModel.confirmPhoto()
//                                                               
//                                                             }
////                                                         
//                                                    cleanUpPlayer()
//                                                         cameraModel.configureSessionFor(mode: cameraModel.selectedCameraMode)
//                                                     }
//                                                    
//                                                 
//                                                    
//                                                 }) {
//                                                     
//                                                     Image(systemName: "checkmark")
//                                                         .foregroundColor(.black)
//                                                         .font(.system(size: 34))
//                                                         .frame(width: 75, height: 75) // Making this larger as specified
//                                                         .background(Color.white)
//                                                         .clipShape(Circle())
//                                                   
//                                                 }
//                                                 .padding(.bottom, 15)
//                                               
//                                             
//                                           
//
//                                             // Chevron right with label "Continue"
//                                             
//                                             
//                                             VStack {
//                                                 Button(action: {
//                                             
//                                                         showCreatePodView = true
//                                                     // Perform the confirmation and cleanup in the background
//                                                             DispatchQueue.global(qos: .userInitiated).async {
//                                                                 if let _ = cameraModel.previewURL {
//                                                                     cameraModel.confirmVideo()
//                                                                 } else if let _ = cameraModel.selectedImage {
//                                                                     cameraModel.confirmPhoto()
//                                                                 }
//
//                                                                 cleanUpPlayer()
//                                                                 cameraModel.configureSessionFor(mode: cameraModel.selectedCameraMode)
//                                                             }
////
////
//
//                                                 }) {
//                                                     Image(systemName: "chevron.right")
//                                                         .foregroundColor(.white)
//                                                         .font(.system(size: 18))
//                                                         .frame(width: 44, height: 44)
//                                                         .background(Color(red: 75/255, green: 75/255, blue: 75/255).opacity(0.4))
//                                                         .clipShape(Circle())
//                                                      
//                                                 }
//                                                 Text("Continue")
//                                                     .foregroundColor(.white)
//                                                     .font(.system(size: 12))
//                                                     .fontWeight(.medium)
//                                             }
//                                         }
//                                         .padding(.bottom, 15) // Adjust this value to position the buttons closer to the bottom edge
//                                     }
//        
//                    }
//                    .clipped()
//                    
//               
//              
//                    VStack {
//                    
//
//                        Spacer()
//                            }
//                    .padding(.top, 25)
//                    .padding(.horizontal, 15)
//                    .frame(height: bottomSegmentHeight)
//                    
//                }
//
//               
//    }
//}
//
////    private func setupPlayer() {
////        DispatchQueue.main.async {
////           
////            if let videoURL = self.url {
////                let playerItem = AVPlayerItem(url: videoURL)
////                self.player.replaceCurrentItem(with: playerItem)
////                self.player.play()
////                // Setup the loop playback observer if needed...
////                self.player.replaceCurrentItem(with: playerItem)
////                self.player.play()
////                
////                // Additional step: Ensure the observer for loop playback is correctly set up
////                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: .main) { [self] _ in
////                    self.player.seek(to: .zero)
////                    self.player.play()
////                }
////
////            }
////
////        }
////    }
//    private func setupPlayer() {
//            if let videoURL = self.url {
//                let playerItem = AVPlayerItem(url: videoURL)
//                self.player.replaceCurrentItem(with: playerItem)
//                self.player.play()
//                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: .main) { [self] _ in
//                    self.player.seek(to: .zero)
//                    self.player.play()
//                }
//            }
//        }
//
//
//
//    private func cleanUpPlayer() {
//           player.pause()
//           player.replaceCurrentItem(with: nil) // Reset the player
//           NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
//       }
//
//
//}
//
//extension Image {
//    func iconStyle() -> some View {
//        self
//            .font(.title)
//            .foregroundColor(.white)
//    }
//}
//#Preview {
//    CameraContainerView()
//}



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






// Create the WheelPicker view
struct WheelPicker: View {
    @Binding var selectedMode: CameraMode
    @ObservedObject var cameraViewModel: CameraViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(CameraMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(self.selectedMode == mode ? Color.white : Color.clear)
                        .foregroundColor(self.selectedMode == mode ? .black : .white)
                        .clipShape(Capsule())
                        .onTapGesture {
                            self.selectedMode = mode
                           self.cameraViewModel.selectedCameraMode = mode
                           // Ensure session is configured for the new mode
                           self.cameraViewModel.configureSessionFor(mode: mode)
                           // Directly use the duration property
                            self.cameraViewModel.maxDuration = CGFloat(mode.duration)
                        }
                        .animation(.easeInOut, value: selectedMode)
                }
            }
            .padding(.horizontal, 5)
        }
    }
}




struct CameraContainerView: View {
    @StateObject var cameraModel = CameraViewModel()
    @State private var showCreatePodView = false
    @State private var isShowingVideoPicker = false
    @State private var selectedVideoURL: URL?
    @State private var isProcessingVideo = false
    @State private var showingVoiceCommandPopup = false
    @State private var voiceCommandPopupMessage: String? = nil
    @Binding var showingVideoCreationScreen: Bool
    @State private var latestPhoto: UIImage? = nil
    @State private var showTranscribeLabel = true
    @State private var showCommandLabel = true
    @Binding var selectedTab: Int
    @State private var navigationPath = NavigationPath()
    
    @EnvironmentObject var uploadViewModel: UploadViewModel

    
    // New state variables
        @State private var cameraViewCreated = false
    var body: some View {
   
            
        ZStack {
            // MARK: Camera View
            Color.black.edgesIgnoringSafeArea(.all)
            
            
            // code starts here
            ZStack {
                AltCameraView()
                    .opacity(cameraModel.showPreview || showCreatePodView ? 0 : 1)
                    .allowsHitTesting(!(cameraModel.showPreview || showCreatePodView))
                
                    .onAppear {
                        
                        //                            cameraModel.checkPermission()
                        // Set labels to disappear after 4 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            showTranscribeLabel = false
                            showCommandLabel = false
                        }
                    }
                    .onDisappear {
                        cameraModel.deactivateAudioSession()
                        //                                    cameraModel.deactivateSpeechService()
                        cameraModel.stopAudioRecorder()
                    }
                    .environmentObject(cameraModel)
                
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
                        if cameraModel.selectedCameraMode == .photo {
                            Button(action: {
                                
                                cameraModel.toggleFlashForPhotoMode()
                                
                                
                            }) {
                                Image(systemName: getFlashIcon())
                                    .font(.title)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                                    .padding()
                            }
                        } else {
                            Button(action: cameraModel.toggleFlash) {
                                Image(systemName: cameraModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                                    .font(.system(size: 16))
                                    .padding()
                            }
                        }
                        
                        
                        
                        Button(action: {
                            
                            //                            cameraModel.isWaveformEnabled.toggle()
                            cameraModel.toggleWaveform()
                            
                            //                        cameraModel.toggleWaveform()
                            // Set the message based on the waveform state
                            print("Waveform Enabled State: \(cameraModel.isWaveformEnabled)")
                            voiceCommandPopupMessage = cameraModel.isWaveformEnabled ? "Video transcription on" : "Video transcription off"
                            
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
                                .overlay(
                                    Text("Transcribe video")
                                        .font(.system(size: 14))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .opacity(showTranscribeLabel ? 1.0 : 0.0) // Control opacity of the label only
                                        .fixedSize()
                                        .offset(x: -120) // Adjust position relative to the icon
                                    , alignment: .leading
                                )
                                .padding()
                            
                        }
                        
                        
                    }
                    .position(x: UIScreen.main.bounds.width - 28, y: 130)
                }
                
                if let message = voiceCommandPopupMessage {
                    VStack {
                        VoiceCommandPopupView(message: message)
                            .padding(.top, 20) // Adjust this value to ensure it doesn't overlap with the notch or status bar
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.easeInOut, value: UUID())
                            .padding(.horizontal, 10)
                        
                        Spacer() // Pushes the popup to the top
                    }
                    .zIndex(1) // Ensure it's above other content
                }
                
                
                VStack(spacing: 10){
                    Spacer()
                    
                    if !cameraModel.isRecording {
                        HStack{
                            Spacer()
                            WheelPicker(selectedMode: $cameraModel.selectedCameraMode, cameraViewModel: cameraModel)
                                .background(Color.clear) // Just to highlight the ScrollView area
                                .frame(width: 200)
                                .zIndex(3)
                            //                                   .frame(maxWidth: .infinity)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    
                    
                    HStack(spacing: 55) { // This HStack contains all main elements
                        
                        if !cameraModel.isRecording {
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
                        
                        ZStack {
                            Button(action: {
                                if cameraModel.selectedCameraMode == .photo {
                                    cameraModel.takePhoto()
                                } else if cameraModel.isRecording {
                                    cameraModel.stopRecording()
                                } else {
                                    cameraModel.startRecordingBasedOnMode()
                                }
                            }) {
                                ZStack {
                                    if cameraModel.selectedCameraMode == .photo {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 65, height: 65)
                                        Circle()
                                            .stroke(Color.white, lineWidth: 4)
                                            .frame(width: 75, height: 75)
                                    } else {
                                        // Background circle (white when recording, clear when not)
                                        Circle()
                                            .fill(cameraModel.isRecording ? Color.white.opacity(0.6) : Color.clear)
                                            .frame(width: 75, height: 75)
                                            .animation(.easeInOut(duration: 0.03), value: cameraModel.isRecording)
                                        
                                        // Stroke (red loop when recording)
                                        if cameraModel.isRecording && (cameraModel.selectedCameraMode == .fifteen || cameraModel.selectedCameraMode == .thirty) {
                                            Circle()
                                                .trim(from: 0.0, to: CGFloat(cameraModel.recordedDuration.truncatingRemainder(dividingBy: cameraModel.maxDuration) / cameraModel.maxDuration))
                                                .stroke(Color(red: 230/255, green: 55/255, blue: 67/255), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                                .rotationEffect(Angle(degrees: -90))
                                                .frame(width: 71, height: 71)
                                                .animation(.linear(duration: 0.1), value: cameraModel.recordedDuration)
                                        }
                                        
                                        // Main circle (red when recording, white stroke when not)
                                        Circle()
                                            .fill(Color(red: 230/255, green: 55/255, blue: 67/255))
                                            .frame(width: cameraModel.isRecording ? 25 : 65, height: cameraModel.isRecording ? 25 : 65)
                                            .animation(.easeInOut(duration: 0.03), value: cameraModel.isRecording)
                                        
                                        Circle()
                                            .stroke(Color.white, lineWidth: 4)
                                            .frame(width: 75, height: 75)
                                            .opacity(cameraModel.isRecording ? 0 : 1)
                                            .animation(.easeInOut(duration: 0.03), value: cameraModel.isRecording)
                                        
                                        // Rectangle for recording state
                                        RoundedRectangle(cornerRadius: cameraModel.isRecording ? 8 : 32)
                                            .fill(Color(red: 230/255, green: 55/255, blue: 67/255))
                                            .frame(width: cameraModel.isRecording ? 25 : 0, height: cameraModel.isRecording ? 25 : 0)
                                            .animation(.easeInOut(duration: 0.03), value: cameraModel.isRecording)
                                    }
                                }
                            }
                        }
                        
                        
                        
                        if !cameraModel.isRecording {
                            
                            VStack {
                                if let latestPhoto = latestPhoto {
                                    Button(action: {
                                        // Trigger upload functionality
                                        isShowingVideoPicker = true
                                        
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
                    
                    .padding(.bottom,15)
                    .padding()
                    
                    //                    .padding(.top)
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                //                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .opacity(cameraModel.showPreview || showCreatePodView ? 0 : 1)
            .allowsHitTesting(!(cameraModel.showPreview || showCreatePodView))
        
            // ends here
            
            if cameraModel.showPreview {
                if let url = cameraModel.previewURL {
                    FinalPreview(
                        url: url,
                        selectedImage: nil,
                        showPreview: $cameraModel.showPreview,
                        cameraModel: cameraModel,
                        isFrontCameraUsed: cameraModel.isFrontCameraUsed,
                        showCreatePodView: $showCreatePodView
                    )
                } else if let selectedImage = cameraModel.selectedImage {
                    FinalPreview(
                        url: nil,
                        selectedImage: selectedImage,
                        showPreview: $cameraModel.showPreview,
                        cameraModel: cameraModel,
                        isFrontCameraUsed: cameraModel.isFrontCameraUsed,
                        showCreatePodView: $showCreatePodView
                    )
                }
            } else if showCreatePodView{
                CreatePodView(pod: $cameraModel.currentPod, showingVideoCreationScreen: $showingVideoCreationScreen, selectedTab: $selectedTab, showCreatePodView: $showCreatePodView, showPreview: $cameraModel.showPreview)
                
            }else {
                EmptyView()
                
            }
        }
   
//        Spacer()
        
        
        if !showCreatePodView {
            if !cameraModel.isRecording && !cameraModel.showPreview  {
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
                        .background(Color.white)
                        .cornerRadius(8) // Rounded corners
                        .fontWeight(.semibold)


                        Button("Next") {
                            // Check if there's either a video URL or a selected image available for preview
                            if cameraModel.previewURL != nil || cameraModel.selectedImage != nil {
                                cameraModel.showPreview = true
                            } else {
                                print("No preview content available")
                         
                            }
                        }
                        .foregroundColor(.white) // Text color for the Next button
                        .padding(.vertical, 15) // Padding for thickness
                        .frame(maxWidth: .infinity) // Make button expand
                        .fontWeight(.semibold)
                        .background(Color(red: 57/255, green: 106/255, blue: 247/255))
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
                    let initialMode: CameraMode = .fifteen
                        
                        // Ensure session is configured for the initial mode
                        cameraModel.configureSessionFor(mode: initialMode)
                        
                        // Update maxDuration based on the initial mode
                        cameraModel.maxDuration = initialMode == .fifteen ? 15.0 : 30.0
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
            else {
    //            HStack { // This empty HStack ensures it covers the same height as the buttons
    //                   Spacer()
    //               }
    //               .frame(height: 60)
                Color.black  // Use Color.black instead of Spacer when recording
                                .frame(height: 60)
                                .edgesIgnoringSafeArea(.bottom)
  
                
            }
        } else {
            EmptyView()
        }

        
    }
    
    
    private func getFlashIcon() -> String {
        if cameraModel.selectedCameraMode == .photo {
            // For photo mode, you might want to check a different property or condition
            // This assumes isFlashIntendedForPhoto exists and is managed accordingly
            return cameraModel.isFlashIntendedForPhoto ? "bolt" : "bolt.slash"
        } else {
            // For video mode, you can use the existing isFlashOn state
            return cameraModel.isFlashOn ? "bolt" : "bolt.slash"
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
            .frame(width: 300)
    }
}



extension View {
    func alignAsFloating() -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}




struct FinalPreview: View {
    
    @State var url: URL?
    @State var selectedImage: UIImage?
    @Binding var showPreview: Bool

//     @State var player = AVPlayer()
//    @StateObject private var playerViewModel = PlayerViewModel()
    @ObservedObject var cameraModel = CameraViewModel()
    var isFrontCameraUsed: Bool
    @Binding var showCreatePodView: Bool
    @State private var isPresentingEditor = false
    @State private var editParameters = VideoEditParameters()
    private let blackSegmentHeight: CGFloat = 100
    var videoAspectRatio: CGFloat = 9 / 16
    @State private var isMuted: Bool = false
    @State private var showAddLabel: Bool = true
    @Environment(\.presentationMode) var presentationMode
//    var player: AVPlayer
    @State private var player: AVPlayer = AVPlayer()

    
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
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
                            CustomVideoPlayer(player: player)
                            
                                .onAppear {
                                    setupPlayer()
                                }
                                .onDisappear {
                                    cleanUpPlayer()
                                }
                                .frame(width: screenWidth, height: videoHeight)
                                .onTapGesture {
                                    // Toggle play/pause directly on the player
                                    if player.timeControlStatus == .playing {
                                        player.pause()
                                    } else {
                                        player.play()
                                    }
                                }
                        
                                .scaleEffect(x: isFrontCameraUsed ? -1 : 1, y: 1, anchor: .center)
                                .id(url)
                            
                            
                        } else
                        if let image = cameraModel.selectedImage {
                            
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                            //                                      .scaleEffect(x: isFrontCameraUsed ? -1 : 1, y: 1, anchor: .center)
                                .frame(width: screenWidth, height: videoHeight)
                        }
                        
                        Spacer() // Pushes everything up
                   
                        Spacer()
                        VStack {
                            Spacer()
                            HStack(spacing: 40) {
                                // Chevron left with label "Back"
                                VStack {
                                    Button(action: {
                                        showPreview = false
                                        
                                        // Perform the other actions in the background
                                        DispatchQueue.global(qos: .userInitiated).async {
                                            if cameraModel.currentPod.items.isEmpty {
                                                // If it's the first item (Pod is empty), we've already closed the preview
                                            } else {
                                                // If Pod has items, prepare to re-record the current item
                                                cameraModel.reRecordCurrentItem()
                                            }
                                        }


                                    }) {
                                        Image(systemName: "chevron.left")
                                            .foregroundColor(.white)
                                            .font(.system(size: 18))
                                            .frame(width: 44, height: 44)
                                            .background(Color(red: 75/255, green: 75/255, blue: 75/255).opacity(0.4))
                                            .clipShape(Circle())
                                        
                                    }
                                    Text("Back")
                                        .foregroundColor(.white)
                                        .font(.system(size: 12))
                                        .fontWeight(.medium)
                                }
                                
                                
                                Button(action: {
                                    // Immediately hide the preview
                                       showPreview = false
                                    
                                    
                                   
                                    
                                    // Perform the confirmation and other actions in the background
                                    DispatchQueue.global(qos: .userInitiated).async {
                                        if let _ = cameraModel.previewURL {
                                            // It's a video
                                            cameraModel.confirmVideo()
                                        } else if cameraModel.selectedImage != nil {
                                            // It's a photo
                                            cameraModel.confirmPhoto()
                                        }
                                        
                                        DispatchQueue.main.async {
                                            cameraModel.configureSessionFor(mode: cameraModel.selectedCameraMode)
                                        }
                                    }

                                }) {
                                    
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.black)
                                        .font(.system(size: 34))
                                        .frame(width: 75, height: 75) // Making this larger as specified
                                        .background(Color.white)
                                        .clipShape(Circle())
                                    
                                }
                                .padding(.bottom, 15)

                                VStack {
                                    Button(action: {
                                        
                                        showCreatePodView = true
                                        // Perform the confirmation and cleanup in the background
                                        DispatchQueue.global(qos: .userInitiated).async {
                                            if let _ = cameraModel.previewURL {
                                                cameraModel.confirmVideo()
                                            } else if let _ = cameraModel.selectedImage {
                                                cameraModel.confirmPhoto()
                                            }
          
                                            cameraModel.configureSessionFor(mode: cameraModel.selectedCameraMode)
                                        }

                                        
                                    }) {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white)
                                            .font(.system(size: 18))
                                            .frame(width: 44, height: 44)
                                            .background(Color(red: 75/255, green: 75/255, blue: 75/255).opacity(0.4))
                                            .clipShape(Circle())
                                        
                                    }
                                    Text("Continue")
                                        .foregroundColor(.white)
                                        .font(.system(size: 12))
                                        .fontWeight(.medium)
                                }
                            }
                            .padding(.bottom, 15)
                        }
                        
                    }
                    .clipped()
                    
                    
                    
                    VStack {
                        
                        
                        Spacer()
                    }
                    .padding(.top, 25)
                    .padding(.horizontal, 15)
                    .frame(height: bottomSegmentHeight)
                  
                    
                }
                .navigationBarHidden(true)
                
                
            }
        }
     
        
    }
    
    private func setupPlayer() {
            if let videoURL = self.url {
                let playerItem = AVPlayerItem(url: videoURL)
                self.player.replaceCurrentItem(with: playerItem)
                self.player.play()
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


}



extension Image {
    func iconStyle() -> some View {
        self
            .font(.title)
            .foregroundColor(.white)
    }
}

//class PlayerViewModel: ObservableObject {
//    @Published var player = AVPlayer()
//    private var timeObserverToken: Any?
//    private var playerItemObserver: NSKeyValueObservation?
//
//    func setupPlayer(with url: URL) {
//        let playerItem = AVPlayerItem(url: url)
//        player.replaceCurrentItem(with: playerItem)
//        addObservers()
//        player.play()
//    }
//
//    private func addObservers() {
//        removeObservers()
//
//        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
//        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
//            if let currentItem = self?.player.currentItem, currentItem.currentTime() >= currentItem.duration {
//                self?.player.seek(to: .zero)
//                self?.player.play()
//            }
//        }
//
//        playerItemObserver = player.currentItem?.observe(\.status, options: [.new, .old], changeHandler: { [weak self] playerItem, _ in
//            if playerItem.status == .readyToPlay {
//                self?.player.play()
//            }
//        })
//    }
//
//    func removeObservers() {
//        if let token = timeObserverToken {
//            player.removeTimeObserver(token)
//            timeObserverToken = nil
//        }
//        playerItemObserver?.invalidate()
//        playerItemObserver = nil
//    }
//
//    func cleanUpPlayer() {
//        removeObservers()
//        player.pause()
//        player.replaceCurrentItem(with: nil)
//    }
//
//    func togglePlayPause() {
//        if player.timeControlStatus == .playing {
//            player.pause()
//        } else {
//            player.play()
//        }
//    }
//
//    deinit {
//        removeObservers()
//    }
//}

//class PlayerViewModel: ObservableObject {
//    @Published var player = AVPlayer()
//    @Published var isPlaying = false
//    private var timeObserverToken: Any?
//    private var playerItemObserver: NSKeyValueObservation?
//
//    func setupPlayer(with url: URL) {
//        let playerItem = AVPlayerItem(url: url)
//        player.replaceCurrentItem(with: playerItem)
//        addObservers()
//        play()
//    }
//
//    private func addObservers() {
//        removeObservers()
//
//        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
//        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
//            if let currentItem = self?.player.currentItem, currentItem.currentTime() >= currentItem.duration {
//                self?.player.seek(to: .zero)
//                self?.play()
//            }
//        }
//
//        playerItemObserver = player.currentItem?.observe(\.status, options: [.new, .old], changeHandler: { [weak self] playerItem, _ in
//            if playerItem.status == .readyToPlay {
//                self?.play()
//            }
//        })
//    }
//
//    func removeObservers() {
//        if let token = timeObserverToken {
//            player.removeTimeObserver(token)
//            timeObserverToken = nil
//        }
//        playerItemObserver?.invalidate()
//        playerItemObserver = nil
//    }
//
//    func cleanUpPlayer() {
//        removeObservers()
//        pause()
//        player.replaceCurrentItem(with: nil)
//    }
//
//    func togglePlayPause() {
//        if isPlaying {
//            pause()
//        } else {
//            play()
//        }
//    }
//
//    func play() {
//        player.play()
//        isPlaying = true
//    }
//
//    func pause() {
//        player.pause()
//        isPlaying = false
//    }
//
//    deinit {
//        removeObservers()
//    }
//}
