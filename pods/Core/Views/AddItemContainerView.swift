//
//  AddItemContainerView.swift
//  pods
//
//  Created by Dimi Nunez on 6/14/24.
//

import SwiftUI
import AVKit
import PhotosUI
import Photos
import UniformTypeIdentifiers




struct AddItemContainerView: View {
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
    @State var podId: Int 

   
    
    @EnvironmentObject var uploadViewModel: UploadViewModel
    
    
    var body: some View {
        ZStack {
            // MARK: Camera View
            AltCameraView()
                .onAppear {
                                
                                 cameraModel.checkPermission()
//                                cameraModel.setUp()
//                                cameraModel.configureSpeechService()
                    
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
              //                                   .frame(maxWidth: .infinity)
                                      Spacer()
                                  }
                                  .frame(maxWidth: .infinity)
                              }
                
                   
                    
                    HStack(spacing: 55) { // This HStack contains all main elements

                        VStack {
                            Color.clear
                                .frame(width: 40, height: 40)
                            Text(" ")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.clear)
                        }
                   
                      
                        
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
                                        .fill(Color.white) // Inner circle color
                                        .frame(width: 65, height: 65) // Inner circle size

                                    Circle()
                                        .stroke(Color.white, lineWidth: 4) // Outer circle border
                                        .frame(width: 75, height: 75) // Outer circle size (including padding)
                                } else {
                                    Circle()
                                        .fill(Color(red: 230/255, green: 55/255, blue: 67/255)) // Inner circle color
                                        .frame(width: 65, height: 65) // Inner circle size

                                    Circle()
                                        .stroke(cameraModel.isRecording ? Color.clear : Color.white, lineWidth: 4) // Outer circle border
                                        .frame(width: 75, height: 75) // Outer circle size (including padding)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            }
   
        .fullScreenCover(isPresented: $cameraModel.showPreview) {
            if let url = cameraModel.previewURL {
                // Present with video URL
                ItemPreview(url: url, selectedImage: nil, showPreview: $cameraModel.showPreview, cameraModel: cameraModel, isFrontCameraUsed: cameraModel.isFrontCameraUsed, podId: $podId, showAddItemView: $showAddItemView)
                    .background(Color.black.edgesIgnoringSafeArea(.all))
                    .environment(\.colorScheme, .dark)
            } else if let selectedImage = cameraModel.selectedImage {
                // Present with image
               
                ItemPreview(url: nil,  selectedImage: selectedImage, showPreview: $cameraModel.showPreview, cameraModel: cameraModel, isFrontCameraUsed: cameraModel.isFrontCameraUsed, podId: $podId, showAddItemView: $showAddItemView)
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
                .background(Color.white)
                .cornerRadius(8) // Rounded corners
                .fontWeight(.semibold)


                Button("Next") {
                    // Check if there's either a video URL or a selected image available for preview
                    if cameraModel.previewURL != nil || cameraModel.selectedImage != nil {
                        cameraModel.showPreview = true
                    } else {
                        print("No preview content available")
                        print(cameraModel.previewURL, "url")
                 
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
    
    private func getFlashIcon() -> String {
        if cameraModel.selectedCameraMode == .photo {
            // For photo mode, you might want to check a different property or condition
            // This assumes `isFlashIntendedForPhoto` exists and is managed accordingly
            return cameraModel.isFlashIntendedForPhoto ? "bolt" : "bolt.slash"
        } else {
            // For video mode, you can use the existing `isFlashOn` state
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
    
        func setUpAudio() {
            do {
                // Set up the audio session for recording
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker, .allowBluetooth])
                try audioSession.setActive(true)
    
            
            } catch {
                print("Error setting up video/audio input or audio session: \(error)")
            }
        }
       
}


struct ItemPreview: View {
    
    @State var url: URL?
    @State var selectedImage: UIImage?
    @Binding var showPreview: Bool
     var player = AVPlayer()
    @ObservedObject var cameraModel = CameraViewModel()
    var isFrontCameraUsed: Bool
    @State private var isPresentingEditor = false
    @State private var editParameters = VideoEditParameters()
    private let blackSegmentHeight: CGFloat = 100
    var videoAspectRatio: CGFloat = 9 / 16
    @State private var isMuted: Bool = false
    @State private var showAddLabel: Bool = true
    @Binding var podId: Int
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Binding var showAddItemView: Bool

    
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

                            CustomVideoPlayer(player: player)
                                        .frame(width: screenWidth, height: videoHeight)
//                                        .offset(y: -30)
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
                                        .onAppear {
                                            setupPlayer()
                                        }
                                        .onDisappear {
                                            cleanUpPlayer()
                                        }

                              } else
                        if let image = cameraModel.selectedImage {
                              
                                  Image(uiImage: image)
                                      .resizable()
                                      .aspectRatio(contentMode: .fill)
                                      .clipped()
//                                      .scaleEffect(x: isFrontCameraUsed ? -1 : 1, y: 1, anchor: .center)
                                      .frame(width: screenWidth, height: videoHeight)
                              }
                        
                            Spacer()


                    Spacer()
                        VStack {
                                         Spacer()
                                         HStack(spacing: 40) {
                                             // Chevron left with label "Back"
                                             VStack {
                                                 Button(action: {
                                                     // Action for back
                                              showPreview = false
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
                                                     if let _ = cameraModel.previewURL {
                                                                                       cameraModel.addVideoItem(podId: podId, email: viewModel.email) { success, message in
                                                                                           if success {
                                                                                               showPreview = false
                                                                                           } else {
                                                                                               print("Failed to add video item: \(message ?? "Unknown error")")
                                                                                           }
                                                                                       }
                                                                                   } else if cameraModel.selectedImage != nil {
                                                                                       cameraModel.addPhotoItem(podId: podId, email: viewModel.email) { success, message in
                                                                                           if success {
                                                                                               showPreview = false
                                                                                           } else {
                                                                                               print("Failed to add photo item: \(message ?? "Unknown error")")
                                                                                           }
                                                                                       }
                                                                                   }
                                                                                showAddItemView = false
                                                                               cleanUpPlayer()
                                                                               cameraModel.configureSessionFor(mode: .fifteen)
                                                     
                                                    
                                                 }) {
                                                     
                                                     Image(systemName: "checkmark")
                                                         .foregroundColor(.black)
                                                         .font(.system(size: 34))
                                                         .frame(width: 75, height: 75) // Making this larger as specified
                                                         .background(Color.white)
                                                         .clipShape(Circle())
                                                   
                                                 }
                                                 .padding(.bottom, 15)
                                               
                                             
                                           

                                             // Chevron right with label "Continue"
                                             
                                             
                                             // Empty space placeholder
                                             VStack {
                                                 Spacer()
                                                     .frame(width: 44, height: 44) // Size of the continue button
                                                     .background(Color.clear) // Transparent background
                                                 Text(" ")
                                                     .foregroundColor(.clear) // Hidden text
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


}


