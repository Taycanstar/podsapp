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
                        PodItemCell(item: item, player: player)
                            .id(item.id)
                            .onAppear{
                                playInitialVideoIfNecessary()
                                sharedViewModel.isItemViewActive = true

                            }
                            .onDisappear {
                                sharedViewModel.isItemViewActive = false
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
                if let initialIndex = initialIndex, initialIndex < items.count {
                    scrollPosition = items[initialIndex].id
                    playVideoOnChangeOfScrollPosition(itemId: items[initialIndex].id)
                }
                player.play()
                sharedViewModel.isItemViewActive = true
            }

            .onDisappear{
            player.pause()
                sharedViewModel.isItemViewActive = false
            }
            .scrollPosition(id: $scrollPosition)
            .scrollTargetBehavior(.paging)
            .ignoresSafeArea()
            .onChange(of: scrollPosition ?? 2) { oldValue, newValue in
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
        let item_ = AVPlayerItem(url: item.videoURL)
        player.replaceCurrentItem(with: item_)
    }

    
    func playVideoOnChangeOfScrollPosition(itemId: Int) {
        guard let currentItem = items.first(where: { $0.id == itemId }) else {
            print("Item with ID \(itemId) not found.")
            return
        }

        print("Playing item with ID \(itemId) and URL \(currentItem.videoURL)")
        let playerItem = AVPlayerItem(url: currentItem.videoURL)
        player.replaceCurrentItem(with: playerItem)

        // Remove any existing observers to avoid duplicates
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        
        // Add observer to loop video
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [ self] _ in
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
