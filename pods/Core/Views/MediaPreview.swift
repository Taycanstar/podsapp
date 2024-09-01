//
//  MediaPreview.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/31/24.
//

import SwiftUI
import AVKit

struct MediaPreview: View {
    
    @State var url: URL?
    @State var selectedImage: UIImage?
    @Binding var showPreview: Bool
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
    @State private var player: AVPlayer = AVPlayer()
    @State private var showCheckmarkLabel: Bool = true
    let itemId: Int
    let podId: Int
    
    var onMediaAdded: ((Int) -> Void)?
    @Binding var showingVideoCreationScreen: Bool

    
    
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
               
                        // New circular left arrow button in top left
                        Button(action: {
                                             showPreview = false
                                             DispatchQueue.global(qos: .userInitiated).async {
                                                 if cameraModel.currentPod.items.isEmpty {
                                                     // If it's the first item (Pod is empty), we've already closed the preview
                                                 } else {
                                                     // If Pod has items, prepare to re-record the current item
                                                     DispatchQueue.main.async {
                                                         cameraModel.reRecordCurrentItem()
                                                     }
                                                 }
                                             }
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

                              // Checkmark button at the bottom
                              VStack {
                                  Spacer()
                                  if showCheckmarkLabel {
                                      Text("Tap below to confirm and save media to item")
                                          .font(.system(size: 14))
                                          .fontWeight(.semibold)
                                          .foregroundColor(.white)
                                          .shadow(radius: 5)
                                          .padding(.bottom, 10)
                                          .frame(maxWidth: 175)
                                          .multilineTextAlignment(.center)
                                          .onAppear {
                                              DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                                  withAnimation {
                                                      showCheckmarkLabel = false
                                                  }
                                              }
                                          }
                                  }
                                  Button(action: {
                                      showPreview = false
                                              if let videoURL = cameraModel.previewURL {
                                                  NetworkManager().addMediaToItem(podId: podId, itemId: itemId, mediaType: "video", mediaURL: videoURL) { success, error in
                                                      DispatchQueue.main.async {
                                                          if success {
                                                              print("Video added successfully")
                                                              showingVideoCreationScreen = false // Close the CameraView
                                                              onMediaAdded?(itemId) // Notify PodView to refresh this item
                                                          } else {
                                                              print("Failed to add video: \(error?.localizedDescription ?? "Unknown error")")
                                                              // Handle error (e.g., show an error message)
                                                          }
                                                      }
                                                  }
                                              } else if let image = cameraModel.selectedImage {
                                                  NetworkManager().addMediaToItem(podId: podId, itemId: itemId, mediaType: "image", image: image) { success, error in
                                                      DispatchQueue.main.async {
                                                          if success {
                                                              print("Image added successfully")
                                                              showingVideoCreationScreen = false // Close the CameraView
                                                              onMediaAdded?(itemId) // Notify PodView to refresh this item
                                                          } else {
                                                              print("Failed to add image: \(error?.localizedDescription ?? "Unknown error")")
                                                              // Handle error (e.g., show an error message)
                                                          }
                                                      }
                                                  }
                                              }
                                              DispatchQueue.main.async {
                                                  cameraModel.configureSessionFor(mode: cameraModel.selectedCameraMode)
                                              }
                                  }) {
                                      Image(systemName: "checkmark")
                                          .foregroundColor(.black)
                                          .font(.system(size: 34))
                                          .frame(width: 75, height: 75)
                                          .background(Color.white)
                                          .clipShape(Circle())
                                  }
                                  .padding(.bottom, 30)
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



