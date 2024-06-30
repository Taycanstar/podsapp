//
//  AddItemView.swift
//  Podstack
//
//  Created by Dimi Nunez on 6/29/24.
//
import SwiftUI
import AVKit
import PhotosUI
import Photos
import UniformTypeIdentifiers

struct AddItemView: View {
    @StateObject var cameraModel = CameraViewModel()
    @State private var isShowingVideoPicker = false
    @State private var selectedVideoURL: URL?
    @State private var isProcessingVideo = false
    @State private var showingVoiceCommandPopup = false
    @State private var voiceCommandPopupMessage: String? = nil
    @Binding var showAddItemView: Bool
    @State private var latestPhoto: UIImage? = nil
    @State private var showTranscribeLabel = true
    @State private var showCommandLabel = true
    @State private var navigationPath = NavigationPath()
    @State var podId: Int 
    @State var podName: String
    @EnvironmentObject var uploadViewModel: UploadViewModel
    
    @StateObject private var playerViewModel = PlayerViewModel()
    
    // New state variables
        @State private var cameraViewCreated = false
    var body: some View {
   
            
        ZStack {
            // MARK: Camera View
            Color.black.edgesIgnoringSafeArea(.all)
            
            
            // code starts here
            ZStack {
                AltCameraView()
                    .opacity(cameraModel.showPreview ? 0 : 1)
                    .allowsHitTesting(!(cameraModel.showPreview))
                
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
       
                        showAddItemView = false
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
            .opacity(cameraModel.showPreview ? 0 : 1)
            .allowsHitTesting(!(cameraModel.showPreview))
        
            // ends here
            
            if cameraModel.showPreview {
                if let url = cameraModel.previewURL {
                    AddItemPreview(
                        url: url,
                        selectedImage: nil,
                        showPreview: $cameraModel.showPreview,
                        cameraModel: cameraModel,
                        isFrontCameraUsed: cameraModel.isFrontCameraUsed, podId: $podId, podName: $podName,
                        showAddItemView: $showAddItemView
                    )
                } else if let selectedImage = cameraModel.selectedImage {
                    AddItemPreview(
                        url: nil,
                        selectedImage: selectedImage,
                        showPreview: $cameraModel.showPreview,
                        cameraModel: cameraModel,
                        isFrontCameraUsed: cameraModel.isFrontCameraUsed,
                        podId: $podId, podName: $podName,
                        showAddItemView: $showAddItemView
                    )
                }
            }else {
                EmptyView()
                
            }
        }
   
        Spacer() // Pushes the bar to the bottom
        
      
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
            } else {
    //            HStack { // This empty HStack ensures it covers the same height as the buttons
    //                   Spacer()
    //               }
    //               .frame(height: 60)
                Color.black  // Use Color.black instead of Spacer when recording
                                .frame(height: 60)
                                .edgesIgnoringSafeArea(.bottom)
                
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






struct AddItemPreview: View {
    
    @State var url: URL?
    @State var selectedImage: UIImage?
    @Binding var showPreview: Bool

//    var player: AVPlayer
//     @State var player = AVPlayer()
    @StateObject private var playerViewModel = PlayerViewModel()
    @ObservedObject var cameraModel = CameraViewModel()
    var isFrontCameraUsed: Bool
    @State private var isPresentingEditor = false
    @State private var editParameters = VideoEditParameters()
    private let blackSegmentHeight: CGFloat = 100
    var videoAspectRatio: CGFloat = 9 / 16
    @State private var isMuted: Bool = false
    @State private var showAddLabel: Bool = true
    @Environment(\.presentationMode) var presentationMode
    @Binding var podId: Int
    @Binding var podName: String
    @State private var showAddItemSheet = false
    @State private var itemLabel = ""
    @Binding var showAddItemView: Bool
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @State private var wasPlayingBeforeSheet = false
    
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
                            CustomVideoPlayer(player: playerViewModel.player)

                                .onAppear {
                                                       playerViewModel.setupPlayer(with: url)
                                                   }
                                                   .onDisappear {
                                                       playerViewModel.cleanUpPlayer()
                                                   }
                                                            .frame(width: screenWidth, height: videoHeight)
                                                            .onTapGesture {
                                                                playerViewModel.togglePlayPause()
                                               
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
                                
                                VStack {
                                    Spacer()
                                        .frame(width: 44, height: 44) // Size of the continue button
                                        .background(Color.clear) // Transparent background
                                    Text(" ")
                                        .foregroundColor(.clear) // Hidden text
                                        .font(.system(size: 12))
                                        .fontWeight(.medium)
                                }
                                .padding(.bottom, 15)

                              
                                
                                VStack {
                                    Button(action: {
                                        wasPlayingBeforeSheet = playerViewModel.isPlaying
                                              if wasPlayingBeforeSheet {
                                                  playerViewModel.pause()
                                              }
                                        showAddItemSheet = true
                                        
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
                            .padding(.bottom, 15) // Adjust this value to position the buttons closer to the bottom edge
                        }
                        
                    }
                    .clipped()
                    
                    
                    
                    VStack {
                        
                        
                        Spacer()
                    }
                    .padding(.top, 25)
                    .padding(.horizontal, 15)
                    .frame(height: bottomSegmentHeight)
                    
//                    .sheet(isPresented: $showAddItemSheet) {
//                        AddItemSheet(
//                            showSheet: $showAddItemSheet,
//                            podId: podId,
//                            podName: podName,
//                            showPreview: $showPreview,
//                            showAddItemView: $showAddItemView
//                            
//                        )
//                        .environmentObject(uploadViewModel)
//                           .environmentObject(cameraModel)
//                           .presentationDetents([.height(UIScreen.main.bounds.height / 3.5)])
//                    }
                    .sheet(isPresented: $showAddItemSheet, onDismiss: {
                        if wasPlayingBeforeSheet {
                            playerViewModel.play()
                        }
                    }) {
                        AddItemSheet(
                            showSheet: $showAddItemSheet,
                            podId: podId,
                            podName: podName,
                            showPreview: $showPreview,
                            showAddItemView: $showAddItemView
                        )
                        .environmentObject(uploadViewModel)
                        .environmentObject(cameraModel)
                        .presentationDetents([.height(UIScreen.main.bounds.height / 3.5)])
                    }
                }
                .navigationBarHidden(true)
                
                
            }
        }
     
        
    }
    


}

struct AddItemSheet: View {
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var cameraModel: CameraViewModel
    @Binding var showSheet: Bool
    let podId: Int
    let podName: String
    @State private var itemLabel: String = ""
    @State private var isLoading = false
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Binding var showPreview: Bool
    @Binding var showAddItemView: Bool
    
    var body: some View {

        VStack {
            Text("Add to \(podName)")
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 20)
            Divider()
            .padding(.bottom, 15)
            ZStack(alignment: .leading) {
                CustomTextField2(placeholder: "Item label", text: $itemLabel)
                    .autocapitalization(.none)
                    .keyboardType(.default)
                  
                
            }
            .padding(.horizontal, 25)
//            .padding(.bottom, 15)
//            Spacer()
            addButton
                .padding(.horizontal, 10)
                .padding(.top, 20) // 30 pixels distance from the input
//                .padding(.bottom, 20)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
    }

    private func addItemToPod() {
        isLoading = true // Show loading indicator
        
        let addItem = { (success: Bool, message: String?) in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.showSheet = false // Close the sheet
                    self.showPreview = false // Close the ItemPreview
                    self.showAddItemView = false // Close the AddItemView
                    self.uploadViewModel.addItemCompleted()
                } else {
                    print("Failed to add item: \(message ?? "Unknown error")")
                    // Optionally show an error message to the user
                }
            }
        }

        if let _ = cameraModel.previewURL {
            cameraModel.addVideoItem(podId: podId, email: viewModel.email, label: itemLabel, completion: addItem)
        } else if cameraModel.selectedImage != nil {
            cameraModel.addPhotoItem(podId: podId, email: viewModel.email, label: itemLabel, completion: addItem)
        }
    }
    
    private var addButton: some View {
        Button(action: addItemToPod) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Add")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                       
                }
                
            }
            .frame(maxWidth: .infinity)
            .padding()
            .frame(height: 52)
            .background(Color(red: 70/255, green: 87/255, blue: 245/255))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
}


struct CustomTextField2: View {
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var showPassword: Bool = false
    
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(colorScheme == .dark ? Color(red: 161/255, green: 168/255, blue: 179/255) : Color(red: 111/255, green: 117/255, blue: 127/255)) // Adjust opacity for better visibility
//                    .padding(.leading, 10)
                    .padding()
            }
            if isSecure && !showPassword {
                SecureField("", text: $text)
                    .foregroundColor(.black)
                    .padding()
            } else {
                TextField("", text: $text)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding()
            }
        }
        .frame(height: 52)
        .background(colorScheme == .dark ? Color(red: 33/255, green: 35/255, blue: 40/255) : Color(red: 246/255, green: 246/255, blue: 248/255))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray, lineWidth: 0.2)
        )
    }
}
