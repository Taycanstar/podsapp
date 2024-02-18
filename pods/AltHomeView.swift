import SwiftUI
import AVKit

struct Home: View {
    @StateObject var cameraModel = CameraViewModel()

    var body: some View {
        ZStack {
            // MARK: Camera View
            AltCameraView()
                .environmentObject(cameraModel)

     
            // Add a button to reset the current pod
                      if !cameraModel.currentPod.items.isEmpty {
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
                           .padding(.vertical, 45)
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
                        Image(systemName: "bolt")
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
                
                // Preview Button
                Button {
                    if let _ = cameraModel.previewURL{
                        cameraModel.showPreview.toggle()
                    }
                } label: {
                    Group{
                        if cameraModel.previewURL == nil && !cameraModel.recordedURLs.isEmpty{
                            // Merging Videos
                            ProgressView()
                                .tint(.black)
                        }
                        else{
                            Label {
                                Image(systemName: "chevron.right")
                                    .font(.callout)
                            } icon: {
                                Text("Preview")
                            }
                            .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal,20)
                    .padding(.vertical,8)
                    .background{
                        Capsule()
                            .fill(.white)
                    }
                }
                .frame(maxWidth: .infinity,alignment: .trailing)
                .padding(.trailing)
                .opacity((cameraModel.previewURL == nil && cameraModel.recordedURLs.isEmpty) || cameraModel.isRecording ? 0 : 1)
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
//            .frame(maxWidth: .infinity,maxHeight: .infinity,alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .padding(.top)
            .opacity(!cameraModel.recordedURLs.isEmpty && cameraModel.previewURL != nil && !cameraModel.isRecording ? 1 : 0)
        }
        
       
                  
        
        
        .overlay(content: {
            if let url = cameraModel.previewURL,cameraModel.showPreview{
                
                FinalPreview(url: url, showPreview: $cameraModel.showPreview, cameraModel: cameraModel, isFrontCameraUsed: cameraModel.isFrontCameraUsed)
                    .transition(.move(edge: .trailing))
            }
        })
        .animation(.easeInOut, value: cameraModel.showPreview)
        .preferredColorScheme(.dark)
    }
       
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        Home()
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
                                cameraModel.confirmVideo()
                            }) {
                                ZStack {
                                    Circle()
                                        .foregroundColor(.blue)
                                        .frame(width: 44, height: 44) // Adjust size as needed

                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
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
    Home()
}
