////
////  PlayerPageView.swift
////  pods
////
////  Created by Dimi Nunez on 4/28/24.
//

import SwiftUI
import AVKit

protocol ViewLifecycleDelegate {
    func onAppear()
    func onDisappear()
}

struct Player : UIViewControllerRepresentable {
    
    var player : AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController{
        let view = AVPlayerViewController()
        view.player = player
        view.showsPlaybackControls = false
        view.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        
    }
}
//
struct PlayerView : View {
//    @Binding var videos : [Video]
    @Environment(\.presentationMode) var presentationMode

     var items: [PodItem]
    let lifecycleDelegate: ViewLifecycleDelegate?
    
    var body: some View{
      
            
            
            VStack(spacing: 0) {
                
                ForEach(items) { item in  // Direct iteration over items
                    
                    ZStack {
                  
                            if item.videoURL != nil {
                                if let player = item.player {
                            CustomVideoPlayer(player: player)
                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                                .offset(y: -30)
                                .onTapGesture {
                                    // Toggle play/pause directly on the player
                                    if player.timeControlStatus == .playing {
                                        player.pause()
                                    } else {
                                        player.play()
                                    }
                                }
                                              } else {
                                                  Text("Video unavailable")
                                                      .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                                                      .background(Color.gray)
                                              }
                          
                    }else {
                        PodItemCellImage(item: item)
                            .id(item.id)
                            
                        }
      
                    //Vstack goes here
                        
                                                VStack{
                                                    Spacer()
                        
                                                    HStack(alignment: .bottom){
                                                        VStack(alignment: .leading) {
//                                                            Text("Lewis Hamilton")
//                                                                .fontWeight(.semibold)
                                                          
                                                            
                                                            Text(item.notes)}
                                                        .foregroundStyle(.white)
                                                        .font(.body)
                        
                                                        Spacer()
                        
//                                                        VStack(spacing: 28){
//                                                            Circle()
//                                                                .frame(width: 48, height: 48)
//                                                                .foregroundStyle(.gray)
//                                                            Button{
//                                                            } label:{
//                                                                VStack{
//                                                                    Image(systemName: "heart.fill")
//                                                                        .resizable()
//                                                                        .frame(width: 28, height: 28)
//                                                                        .foregroundStyle(.white)
//                                                                    Text("27")
//                                                                        .font(.caption)
//                                                                        .foregroundStyle(.white)
//                                                                    .bold()}}
//                                                            Button{
//                                                            } label:{
//                                                                VStack{
//                                                                    Image(systemName: "ellipsis.bubble.fill")
//                                                                        .resizable()
//                                                                        .frame(width: 28, height: 28)
//                                                                        .foregroundStyle(.white)
//                                                                    Text("27")
//                                                                        .font(.caption)
//                                                                        .foregroundStyle(.white)
//                                                                    .bold()}}
//                                                            Button{
//                                                            } label:{
//                                                                VStack{
//                                                                    Image(systemName: "bookmark.fill")
//                                                                        .resizable()
//                                                                        .frame(width: 22, height: 28)
//                                                                        .foregroundStyle(.white)
//                                                                    Text("27")
//                                                                        .font(.caption)
//                                                                        .foregroundStyle(.white)
//                                                                    .bold()}}
//                                                            Button{
//                                                            } label:{
//                                                                VStack{
//                                                                    Image(systemName: "arrowshape.turn.up.right.fill")
//                                                                        .resizable()
//                                                                        .frame(width: 28, height: 28)
//                                                                        .foregroundStyle(.white)
//                        
//                                                                    Text("27")
//                                                                        .font(.caption)
//                                                                        .foregroundStyle(.white)
//                                                                        .bold()
//                                                                }
//                                                            }
//                                                        }
                                                    }
                                                    .padding(.bottom,80)
                                                }
                                                .padding()
                        
                        //VStack end

                        
                        
                    }
                    
                }
         
                
              
            }
            .onAppear {
                self.lifecycleDelegate?.onAppear()
            }
            .onDisappear {
                self.lifecycleDelegate?.onDisappear()
            }
            .padding(.bottom,80)
            
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


struct PlayerPageView : UIViewRepresentable {
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    
    var items: [PodItem]
    @Binding var currentIndex: Int
    func makeUIView(context: Context) -> UIScrollView{
        
        let view = UIScrollView()
        
        let childView = UIHostingController(rootView: PlayerView(items: self.items, lifecycleDelegate: context.coordinator))
        childView.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat((items.count)))
        let tabBarHeight: CGFloat = 55
        let totalHeight = (UIScreen.main.bounds.height + tabBarHeight) * CGFloat(items.count)
        view.contentSize = CGSize(width: UIScreen.main.bounds.width, height: totalHeight)
        
        view.addSubview(childView.view)
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.isPagingEnabled = true
        view.delegate = context.coordinator
        
        view.contentInsetAdjustmentBehavior = .never
        view.bounces = false  // Disable bouncing
        context.coordinator.setupInitialVideo(view: view)
        return view
        
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        let tabBarHeight: CGFloat = 55
        //        let childHeight = UIScreen.main.bounds.height - tabBarHeight
        uiView.contentSize = CGSize(width: UIScreen.main.bounds.width, height: (UIScreen.main.bounds.height + tabBarHeight) * CGFloat((items.count)))
        
        for i in 0..<uiView.subviews.count{
            uiView.subviews[i].frame = CGRect(x: 0, y: 0,width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat((items.count)))
        }
        
        
        
    }
    
    
    class Coordinator: NSObject, UIScrollViewDelegate, ViewLifecycleDelegate {
        var parent: PlayerPageView
        var index = 0
        
        init(parent: PlayerPageView) {
            self.parent = parent
            self.index = parent.currentIndex
        }
        
        func setupInitialVideo(view: UIScrollView) {
            let yOffset = CGFloat(parent.currentIndex) * UIScreen.main.bounds.height
            view.setContentOffset(CGPoint(x: 0, y: yOffset), animated: false)
            
            prepareAndPlayVideo(at: parent.currentIndex)
            preloadAdjacentVideos(currentIndex: parent.currentIndex)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let currentIndex = Int(scrollView.contentOffset.y / UIScreen.main.bounds.height)
            parent.currentIndex = currentIndex
            
            if index != currentIndex {
                parent.items[index].player?.pause()
                
                index = currentIndex
                parent.currentIndex = index
                DispatchQueue.global(qos: .userInitiated).async {
                    self.preloadAdjacentVideos(currentIndex: self.index)
                    DispatchQueue.main.async {
                        self.prepareAndPlayVideo(at: self.index)
                    }
                }
            }
        }

        func prepareAndPlayVideo(at index: Int) {
            DispatchQueue.main.async {
                if self.parent.items[index].player == nil {
                    self.parent.items[index].preparePlayer()
                }
                self.parent.items[index].player?.seek(to: .zero)
                self.parent.items[index].player?.play()
                self.setupPlayerObserver(for: index)
            }
        }

        func preloadAdjacentVideos(currentIndex: Int) {
            let indicesToPreload = [currentIndex - 1, currentIndex, currentIndex + 1]
            for index in indicesToPreload where index >= 0 && index < parent.items.count {
                if parent.items[index].player == nil {
                    DispatchQueue.global(qos: .userInitiated).async {
                        // Prepare assets in background
                        guard let url = self.parent.items[index].videoURL else { return }
                        let asset = AVAsset(url: url)
                        let playerItem = AVPlayerItem(asset: asset)
                        
                        // Create player on main thread
                        DispatchQueue.main.async {
                            self.parent.items[index].player = AVPlayer(playerItem: playerItem)
                        }
                    }
                }
            }
        }

        func setupPlayerObserver(for index: Int) {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: parent.items[index].player?.currentItem, queue: .main) { [weak self] _ in
                self?.parent.items[index].player?.seek(to: .zero)
                self?.parent.items[index].player?.play()
            }
        }
        
        func onAppear() {
            prepareAndPlayVideo(at: index)
            preloadAdjacentVideos(currentIndex: index)
        }
        
        func onDisappear() {
            parent.items[index].player?.pause()
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        }
    }
}
