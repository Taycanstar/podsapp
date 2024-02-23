import SwiftUI
import AVKit

struct CameraContainerView: View {
    @StateObject var cameraModel = CameraViewModel()
    @State private var showCreatePodView = false
    
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
                              cameraModel.currentPod = Pod()
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
                                      // TODO: Trigger the video picker
                                  }) {
                                      Image(systemName: "photo")
                                          
                                          .font(.system(size: 18))
                                          .foregroundColor(.white)
                                          .padding(.horizontal, 10)
                                          .padding(.vertical, 10)

                                          .background(Color(red: 0, green: 0, blue: 0, opacity: 0.5)) // Style as needed
                                          .clipShape(Circle())
                                  }
                                  .padding(.bottom, 115)
                                  .frame(width: 60, height: 60) // Example size, adjust as needed

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

                        .padding(.bottom, 115)
                   
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
                           .padding(.vertical, 40)
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
           
            .padding(.bottom,35)
            
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
