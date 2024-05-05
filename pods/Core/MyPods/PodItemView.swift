//
//  PodItemView.swift
//  pods
//
//  Created by Dimi Nunez on 4/1/24.
//

import SwiftUI
import AVKit



struct PodItemView: View {
    var items: [PodItem]
    @State private var scrollPosition: Int?
    @State private var player = AVPlayer()
    @EnvironmentObject var sharedViewModel: SharedViewModel
    var initialIndex: Int?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        
        ZStack(alignment: .topLeading){
            ScrollView {
                LazyVStack(spacing: 0){
                    ForEach(items) { item in

                        if item.videoURL != nil {
                                                  PodItemCell(item: item, player: player)
                                                      .id(item.id)
                                                      .onAppear{
                                                  if item.videoURL != nil {
                                                      playInitialVideoIfNecessary()
                                                      
                                                   
                                                  }
                                            sharedViewModel.isItemViewActive = true
                                              }
                                              .onDisappear {
                                                  sharedViewModel.isItemViewActive = false
                                              }
                                              } else {
                                                  PodItemCellImage(item: item)
                                                      .id(item.id)
                                              }

                            
                    }
                }
                .scrollTargetLayout()
            }
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: backButton)
            .scrollIndicators(.hidden)
            .onAppear {
                player.play()
                if let initialIndex = initialIndex, initialIndex < items.count {
                    scrollPosition = items[initialIndex].id
                    playVideoOnChangeOfScrollPosition(itemId: items[initialIndex].id)
                }
                
            
                sharedViewModel.isItemViewActive = true
            }

            .onDisappear{
            player.pause()
                sharedViewModel.isItemViewActive = false
            
            }
            .scrollPosition(id: $scrollPosition)
            .scrollTargetBehavior(.paging)
            .ignoresSafeArea()
//            .onChange(of: scrollPosition ?? 2) { oldValue, newValue in
//                playVideoOnChangeOfScrollPosition(itemId: newValue)
//            }
            .onChange(of: scrollPosition) { oldValue, newValue in
                guard let newValue = newValue else { return }
                playVideoOnChangeOfScrollPosition(itemId: newValue)
            }
  
       

            
            backButton
                          .padding(.top, 10) // Adjusted to account for the status bar height
                          .padding(.leading, 16)
                          .foregroundColor(.white)
                       
        }

 
        }
    
    func playInitialVideoIfNecessary() {
        guard let initialIndex = initialIndex, initialIndex < items.count else { return }

        let item = items[initialIndex]
        
        // Safely unwrap the `videoURL`
        if let videoURL = item.videoURL {
            let item_ = AVPlayerItem(url: videoURL)
            player.replaceCurrentItem(with: item_)
        } else {
            // Handle the case where there's no video URL
            // This might involve showing a placeholder, logging an error, or simply doing nothing
            print("No video URL available for initial item.")
        }
    }


    

    func playVideoOnChangeOfScrollPosition(itemId: Int) {
        guard let currentItem = items.first(where: { $0.id == itemId }), let videoURL = currentItem.videoURL else {
            print("Item with ID \(itemId) not found or doesn't have a video URL.")
            return
        }

        print("Playing item with ID \(itemId) and URL \(videoURL)")
        let playerItem = AVPlayerItem(url: videoURL)
        player.replaceCurrentItem(with: playerItem)

        // Remove any existing observers to avoid duplicates
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)

        // Add observer to loop video
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
            self.player.seek(to: .zero)
            self.player.play()
        }
    }


 

    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left").foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                .font(.system(size: 24))
        }
    }

}

//#Preview {
//    PodItemView()
//}
