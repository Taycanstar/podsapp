//
//  PlayerPageView.swift
//  pods
//
//  Created by Dimi Nunez on 4/28/24.


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

struct PlayerView : View {
//    @Binding var videos : [Video]
    @Environment(\.presentationMode) var presentationMode

    @Binding var items: [PodItem]
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
//
//            .navigationBarHidden(true)
//            .navigationBarBackButtonHidden(true)
//            .navigationBarItems(leading: backButton)
//            .scrollIndicators(.hidden)


            
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
        return PlayerPageView.Coordinator(parent1: self)
    }
    

    @Binding var items: [PodItem]
    @Binding var currentIndex: Int
    func makeUIView(context: Context) -> UIScrollView{
        
        let view = UIScrollView()
        
        let childView = UIHostingController(rootView: PlayerView(items: self.$items, lifecycleDelegate: context.coordinator))
        childView.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat((items.count)))
//        view.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat((items.count)))
//        
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
        context.coordinator.setupInitialVideo()
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
    
    
    

    
    class Coordinator : NSObject, UIScrollViewDelegate, ViewLifecycleDelegate{
        
        var parent : PlayerPageView
        var index = 0
        init(parent1 : PlayerPageView) {
            parent = parent1
        }
        
        func setupInitialVideo() {
               let player = parent.items[index].player
               player?.seek(to: .zero)
               player?.play()
               NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] _ in
                   guard let self = self else { return }
                   player?.seek(to: .zero)
                   player?.play()
               }
           }


        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let currentindex = Int(scrollView.contentOffset.y / UIScreen.main.bounds.height)
            parent.currentIndex = currentindex
            
            if index != currentindex{
                parent.items[index].player?.seek(to: .zero)
                parent.items[index].player?.pause()
                index = currentindex
                parent.currentIndex = index
                parent.items[index].player?.play()
                parent.items[index].player?.actionAtItemEnd = .none
                NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: parent.items[index].player?.currentItem, queue: .main) { (_) in
                    self.parent.items[self.index].player?.seek(to: .zero)
                    self.parent.items[self.index].player?.play()
                }
            }
        }
        
        func onAppear() {
            parent.items[self.index].player?.seek(to: .zero)
            parent.items[self.index].player?.play()
        }
        
        func onDisappear() {
            parent.items[self.index].player?.seek(to: .zero)
            parent.items[self.index].player?.pause()
        }

    }

}



//import SwiftUI
//import AVKit
//
//protocol ViewLifecycleDelegate {
//    func onAppear()
//    func onDisappear()
//}
//
//struct PlayerView: View {
//    @Environment(\.presentationMode) var presentationMode
//    @Binding var items: [PodItem]
//    let lifecycleDelegate: ViewLifecycleDelegate?
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            ForEach(items) { item in
//                ZStack {
//                    if let player = item.player {
//                        CustomVideoPlayer(player: player)
//                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//                            .offset(y: -30)
//                            .onTapGesture {
//                                if player.timeControlStatus == .playing {
//                                    player.pause()
//                                } else {
//                                    player.play()
//                                }
//                            }
//                    } else {
//                        Text("Video unavailable")
//                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//                            .background(Color.gray)
//                    }
//                }
//            }
//        }
//        .onAppear {
//            self.lifecycleDelegate?.onAppear()
//        }
//        .onDisappear {
//            self.lifecycleDelegate?.onDisappear()
//        }
//        .padding(.bottom, 80)
//    }
//    
//    private var backButton: some View {
//        Button(action: {
//            presentationMode.wrappedValue.dismiss()
//        }) {
//            Image(systemName: "chevron.left")
//                .foregroundColor(.white)
//                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
//                .font(.system(size: 24))
//        }
//    }
//}
//
//
//
//struct PlayerPageView : UIViewRepresentable {
//
//    func makeCoordinator() -> Coordinator {
//        return PlayerPageView.Coordinator(parent: self)
//    }
//    
//    @Binding var items: [PodItem]
//    @Binding var currentIndex: Int
//    
//    func makeUIView(context: Context) -> UIScrollView {
//        let view = UIScrollView()
//        let childView = UIHostingController(rootView: PlayerView(items: self.$items, lifecycleDelegate: context.coordinator))
//        childView.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))
//        let tabBarHeight: CGFloat = 55
//        let totalHeight = (UIScreen.main.bounds.height + tabBarHeight) * CGFloat(items.count)
//        view.contentSize = CGSize(width: UIScreen.main.bounds.width, height: totalHeight)
//        view.addSubview(childView.view)
//        view.showsVerticalScrollIndicator = false
//        view.showsHorizontalScrollIndicator = false
//        view.contentInsetAdjustmentBehavior = .never
//        view.isPagingEnabled = true
//        view.delegate = context.coordinator
//        view.bounces = false
//        context.coordinator.setupInitialVideo()
//        return view
//    }
//    
//    func updateUIView(_ uiView: UIScrollView, context: Context) {
//        let tabBarHeight: CGFloat = 55
//        uiView.contentSize = CGSize(width: UIScreen.main.bounds.width, height: (UIScreen.main.bounds.height + tabBarHeight) * CGFloat(items.count))
//        for i in 0..<uiView.subviews.count {
//            uiView.subviews[i].frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))
//        }
//    }
//    
//    class Coordinator : NSObject, UIScrollViewDelegate, ViewLifecycleDelegate {
//        
//        var parent: PlayerPageView
//        var index = 0
//        
//        init(parent: PlayerPageView) {
//            self.parent = parent
//        }
//        
//        func setupInitialVideo() {
//            preloadVideo(at: index)
//        }
//        
//        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//            let currentIndex = Int(scrollView.contentOffset.y / UIScreen.main.bounds.height)
//            parent.currentIndex = currentIndex
//            
//            if index != currentIndex {
//                stopVideo(at: index) // Stop the previous video
//                index = currentIndex
//                parent.currentIndex = index
//                preloadVideo(at: index)
//            }
//        }
//        
//        func onAppear() {
//            preloadVideo(at: index)
//        }
//        
//        func onDisappear() {
//            stopVideo(at: index) // Stop the current video
//        }
//        
//        private func preloadVideo(at index: Int) {
//            guard parent.items.indices.contains(index) else { return }
//            guard let url = parent.items[index].videoURL else { return }
//            
//            let cacheURL = VideoCacheManager.shared.cachedURL(for: url)
//            if FileManager.default.fileExists(atPath: cacheURL.path) {
//                playVideo(from: cacheURL, at: index)
//            } else {
//                let asset = AVURLAsset(url: url)
//                asset.resourceLoader.setDelegate(VideoCacheManager.shared, queue: DispatchQueue.global())
//                let playerItem = AVPlayerItem(asset: asset)
//                let player = AVPlayer(playerItem: playerItem)
//                DispatchQueue.main.async {
//                    self.parent.items[index].player = player
//                    player.play()
//                    self.loopVideo(player: player)
//                    self.cacheVideo(from: url, to: cacheURL, asset: asset)
//                }
//            }
//        }
//        
//        private func playVideo(from url: URL, at index: Int) {
//            let asset = AVAsset(url: url)
//            let playerItem = AVPlayerItem(asset: asset)
//            let player = AVPlayer(playerItem: playerItem)
//            DispatchQueue.main.async {
//                self.parent.items[index].player = player
//                player.play()
//                self.loopVideo(player: player)
//            }
//        }
//        
//        private func cacheVideo(from originalURL: URL, to cacheURL: URL, asset: AVURLAsset) {
//            let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
//            exportSession?.outputURL = cacheURL
//            exportSession?.outputFileType = .mp4
//            exportSession?.exportAsynchronously {
//                if exportSession?.status == .completed {
//                    print("Video cached successfully at \(cacheURL)")
//                } else {
//                    print("Failed to cache video: \(exportSession?.error?.localizedDescription ?? "Unknown error")")
//                }
//            }
//        }
//        
//        private func loopVideo(player: AVPlayer) {
//            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
//                player.seek(to: .zero)
//                player.play()
//            }
//        }
//
//        private func stopVideo(at index: Int) {
//            guard parent.items.indices.contains(index) else { return }
//            if let player = parent.items[index].player {
//                player.pause()
//                player.seek(to: .zero)
//                parent.items[index].player = nil
//            }
//        }
//    }
//}


//                        VStack{
//                            Spacer()
//
//                            HStack(alignment: .bottom){
//                                VStack(alignment: .leading) {
//                                    Text("Lewis Hamilton")
//                                        .fontWeight(.semibold)
//                                    Text("Still we raise")}
//                                .foregroundStyle(.white)
//                                .font(.subheadline)
//
//                                Spacer()
//
//                                VStack(spacing: 28){
//                                    Circle()
//                                        .frame(width: 48, height: 48)
//                                        .foregroundStyle(.gray)
//                                    Button{
//                                    } label:{
//                                        VStack{
//                                            Image(systemName: "heart.fill")
//                                                .resizable()
//                                                .frame(width: 28, height: 28)
//                                                .foregroundStyle(.white)
//                                            Text("27")
//                                                .font(.caption)
//                                                .foregroundStyle(.white)
//                                            .bold()}}
//                                    Button{
//                                    } label:{
//                                        VStack{
//                                            Image(systemName: "ellipsis.bubble.fill")
//                                                .resizable()
//                                                .frame(width: 28, height: 28)
//                                                .foregroundStyle(.white)
//                                            Text("27")
//                                                .font(.caption)
//                                                .foregroundStyle(.white)
//                                            .bold()}}
//                                    Button{
//                                    } label:{
//                                        VStack{
//                                            Image(systemName: "bookmark.fill")
//                                                .resizable()
//                                                .frame(width: 22, height: 28)
//                                                .foregroundStyle(.white)
//                                            Text("27")
//                                                .font(.caption)
//                                                .foregroundStyle(.white)
//                                            .bold()}}
//                                    Button{
//                                    } label:{
//                                        VStack{
//                                            Image(systemName: "arrowshape.turn.up.right.fill")
//                                                .resizable()
//                                                .frame(width: 28, height: 28)
//                                                .foregroundStyle(.white)
//
//                                            Text("27")
//                                                .font(.caption)
//                                                .foregroundStyle(.white)
//                                                .bold()
//                                        }
//                                    }
//                                }
//                            }
//                            .padding(.bottom,80)
//                        }
//                        .padding()
