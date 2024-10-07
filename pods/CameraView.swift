import SwiftUI
import Photos
import AVFoundation




struct CameraView: View {
    @StateObject var cameraModel = CameraViewModel()
    @State private var showCreatePodView = false
    @State private var isShowingVideoPicker = false
    @State private var selectedVideoURL: URL?
    @State private var isProcessingVideo = false
    @State private var showingVoiceCommandPopup = false
    @State private var showingSummarizationPopup = false
    @State private var voiceCommandPopupMessage: String? = nil
    @State private var summarizationMessage: String? = nil
    @Binding var showingVideoCreationScreen: Bool
    @State private var latestPhoto: UIImage? = nil
    @State private var showTranscribeLabel = true
    @State private var showSummarizationLabel = true
    @State private var showCommandLabel = true
    @Binding var selectedTab: Int
    @State private var navigationPath = NavigationPath()
    var onMediaAdded: ((Int) -> Void)?
    
   
    let itemId: Int
    let podId: Int
    
    @EnvironmentObject var uploadViewModel: UploadViewModel

    
    // New state variables
        @State private var cameraViewCreated = false
    
    init(showingVideoCreationScreen: Binding<Bool>, selectedTab: Binding<Int>, podId: Int, itemId: Int, onMediaAdded: ((Int) -> Void)? = nil) {
          self._showingVideoCreationScreen = showingVideoCreationScreen
          self._selectedTab = selectedTab
          self.podId = podId
          self.itemId = itemId
          self.onMediaAdded = onMediaAdded
      }

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
                        
                        if !cameraModel.hasCheckedPermission {
                                cameraModel.checkPermission()
                            }
                            if cameraModel.permissionGranted {
                                cameraModel.setUp()
                            }
                        // Set labels to disappear after 4 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            showTranscribeLabel = false
                            showCommandLabel = false
                            showSummarizationLabel = false
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
                        
                    }
                    .position(x: UIScreen.main.bounds.width - 28, y: 130)
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
                                        isShowingVideoPicker = true
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
                    
                    .padding(.bottom,100)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
         
            }
            .opacity(cameraModel.showPreview || showCreatePodView ? 0 : 1)
            .allowsHitTesting(!(cameraModel.showPreview || showCreatePodView))
        
            // ends here
            
            if cameraModel.showPreview {
                if let url = cameraModel.previewURL {
                    MediaPreview(
                        url: url,
                        selectedImage: nil,
                        showPreview: $cameraModel.showPreview,
                        cameraModel: cameraModel,
                        isFrontCameraUsed: cameraModel.isFrontCameraUsed,
                        showCreatePodView: $showCreatePodView, itemId: itemId, podId: podId, onMediaAdded: onMediaAdded, showingVideoCreationScreen: $showingVideoCreationScreen
                    )
                    .onDisappear {
                              DispatchQueue.main.async {
                                  cameraModel.configureSessionFor(mode: cameraModel.selectedCameraMode)
                              }
                          }
                } else if let selectedImage = cameraModel.selectedImage {
                    MediaPreview(
                        url: nil,
                        selectedImage: selectedImage,
                        showPreview: $cameraModel.showPreview,
                        cameraModel: cameraModel,
                        isFrontCameraUsed: cameraModel.isFrontCameraUsed,
                        showCreatePodView: $showCreatePodView,
                        itemId: itemId, podId: podId, onMediaAdded: onMediaAdded, showingVideoCreationScreen: $showingVideoCreationScreen
                    )
                    .onDisappear {
                              DispatchQueue.main.async {
                                  cameraModel.configureSessionFor(mode: cameraModel.selectedCameraMode)
                              }
                          }
                }
            } else {
                EmptyView()
                
            }
            
//            
//            VStack {
//                Spacer()
//                if !showCreatePodView {
//                    if !cameraModel.isRecording && !cameraModel.showPreview  {
//                        HStack(spacing: 10) { // Spacing between buttons is 10
//                            if !cameraModel.currentPod.items.isEmpty {
//                                Button("Start over") {
//                                    // Action for Start Over
//                                    cameraModel.currentPod = Pod(id: -1, items:[],title: "")
//                                    cameraModel.recordedDuration = 0
//                                    cameraModel.previewURL = nil
//                                }
//                                .foregroundColor(.black) // Text color
//                                .padding(.vertical, 15) // Padding for thickness
//                                .frame(maxWidth: .infinity) // Make button expand
//                                .background(Color.white)
//                                .cornerRadius(8) // Rounded corners
//                                .fontWeight(.semibold)
//                                Button("Next") {
//                                    // Check if there's either a video URL or a selected image available for preview
//                                    if cameraModel.previewURL != nil || cameraModel.selectedImage != nil {
//                                        cameraModel.showPreview = true
//                                    } else {
//                                        print("No preview content available")
//                                    }
//                                }
//                                .foregroundColor(.white) // Text color for the Next button
//                                .padding(.vertical, 15) // Padding for thickness
//                                .frame(maxWidth: .infinity) // Make button expand
//                                .fontWeight(.semibold)
//                                .background(Color(red: 35/255, green: 108/255, blue: 255/255))
//                                .cornerRadius(8) // Rounded corners
//                            } else{
//                                Rectangle()
//                                .foregroundColor(.black)   }}
//                        .padding(.horizontal, 10) // Horizontal padding from the screen edges, 10 points on each
//                        .frame(height: 60) // Set the height of the bottom bar
//                        .background(Color.black) // Set the color to black
//                        .edgesIgnoringSafeArea(.bottom) // Ensures it goes to the edge of the screen
//                        .onAppear {
//                            let initialMode: CameraMode = .fifteen
//                            
//                            // Ensure session is configured for the initial mode
//                            cameraModel.configureSessionFor(mode: initialMode)
//                            
//                            // Update maxDuration based on the initial mode
//                            cameraModel.maxDuration = initialMode == .fifteen ? 15.0 : 30.0
//                            // Request authorization and fetch latest photo
//                            PHPhotoLibrary.requestAuthorization { status in
//                                if status == .authorized {
//                                    self.fetchLatestPhoto { photo in
//                                        self.latestPhoto = photo
//                                    }
//                                }
//                            }
//                        }
//                    }
//                    else {
//                        
//                        Color.black  // Use Color.black instead of Spacer when recording
//                            .frame(height: 60)
//                            .edgesIgnoringSafeArea(.bottom)
//
//                    }
//                } else {
//                    EmptyView()
//                }
//            }

        }
        .onAppear{
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    self.fetchLatestPhoto { photo in
                        self.latestPhoto = photo
                    }
                }
            }
        }
        .increaseBottomSafeArea(by: 75)

   



        
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


struct IncreaseBottomSafeArea: ViewModifier {
    let additionalHeight: CGFloat
    
    func body(content: Content) -> some View {
        ZStack {
            content
            VStack {
                Spacer()
                Color.black
                    .frame(height: additionalHeight)
                    .edgesIgnoringSafeArea(.bottom)
            }
        }
    }
}

extension View {
    func increaseBottomSafeArea(by height: CGFloat) -> some View {
        self.modifier(IncreaseBottomSafeArea(additionalHeight: height))
    }
}
