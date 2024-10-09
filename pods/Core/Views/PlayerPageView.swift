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

//struct PlayerView: View {
//    var items: [PodItem]
//    let lifecycleDelegate: ViewLifecycleDelegate?
//    @Binding var currentIndex: Int
//    @State private var players: [Int: AVPlayer] = [:]
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ForEach(items.indices, id: \.self) { index in
//                let item = items[index]
//                ZStack {
//                    Color.black.edgesIgnoringSafeArea(.all)
//                    
//                    if let url = item.videoURL {
//                        GeometryReader { geometry in
//                            CustomVideoPlayer2(
//                                url: url,
//                                player: Binding(
//                                    get: { self.players[index] },
//                                    set: { self.players[index] = $0 }
//                                ),
//                                isCurrentVideo: index == currentIndex
//                            )
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: geometry.size.width, height: geometry.size.height)
//                            .onTapGesture {
//                                if let player = players[index] {
//                                    if player.timeControlStatus == .playing {
//                                        player.pause()
//                                    } else if index == currentIndex {
//                                        player.play()
//                                    }
//                                }
//                            }
//                        }
//                    } else {
//                        PodItemCellImage(item: item)
//                            .id(item.id)
//                    }
//
//                    VStack {
//                        Spacer()
//                        HStack(alignment: .bottom) {
//                            VStack(alignment: .leading) {
//                                Text(item.notes)
//                            }
//                            .foregroundStyle(.white)
//                            .font(.body)
//                            Spacer()
//                        }
//                        .padding(.bottom, 80)
//                    }
//                    .padding()
//                }
//                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//            }
//        }
//        .background(Color.black)
//        .onAppear {
//            self.lifecycleDelegate?.onAppear()
//            if let player = players[currentIndex] {
//                player.play()
//            }
//        }
//        .onDisappear {
//            self.lifecycleDelegate?.onDisappear()
//            for player in players.values {
//                player.pause()
//            }
//        }
//        .onChange(of: currentIndex) { oldIndex, newIndex in
//            players[oldIndex]?.pause()
//            players[newIndex]?.seek(to: .zero)
//            players[newIndex]?.play()
//        }
//    }
//}
struct PlayerView: View {
    var items: [PodItem]
    let lifecycleDelegate: ViewLifecycleDelegate?
    @Binding var currentIndex: Int
    var videoPreloader: VideoPreloader

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    if let url = item.videoURL {
                        GeometryReader { geometry in
                            CustomVideoPlayer2(
                                url: url,
                                player: Binding(
                                    get: { self.videoPreloader.getPlayer(for: item.id) },
                                    set: { self.videoPreloader.setPlayer(for: item.id, player: $0) }
                                ),
                                isCurrentVideo: index == currentIndex
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .edgesIgnoringSafeArea(.all)
                        }
                    } else {
                        PodItemCellImage(item: item)
                            .id(item.id)
                    }

                    VStack {
                        Spacer()
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading) {
                                Text(item.notes)
                            }
                            .foregroundStyle(.white)
                            .font(.body)
                            Spacer()
                        }
                        .padding(.bottom, 80)
                    }
                    .padding()
                }
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            }
        }
        .background(Color.black)
        .onChange(of: currentIndex) { oldValue, newValue in
            videoPreloader.updatePreloadedVideos(currentIndex: newValue, items: items)
        }
    }
}
//struct PlayerView: View {
//    var items: [PodItem]
//    let lifecycleDelegate: ViewLifecycleDelegate?
//    @Binding var currentIndex: Int
////    @State private var players: [Int: AVPlayer] = [:]
//    var videoPreloader: VideoPreloader
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ForEach(items.indices, id: \.self) { index in
//                let item = items[index]
//                ZStack {
//                    Color.black.edgesIgnoringSafeArea(.all) // Black background to match video layout
//                    
//                    if let url = item.videoURL {
//                        GeometryReader { geometry in
//                            CustomVideoPlayer2(
//                                url: url,
////                                player: Binding(
////                                    get: { self.players[index] },
////                                    set: { self.players[index] = $0 }
////                                ),
//                                player: Binding(
//                                                              get: { self.videoPreloader.getPlayer(for: item.id) },
//                                                              set: { _ in }
//                                                          ),
//                                isCurrentVideo: index == currentIndex
//                            )
//                            .frame(width: geometry.size.width, height: geometry.size.height) // Use full width and height
//                            .clipped() // Ensure no overflow
//                            .edgesIgnoringSafeArea(.all)
////                            .onTapGesture {
////                                if let player = players[index] {
////                                    if player.timeControlStatus == .playing {
////                                        player.pause()
////                                    } else if index == currentIndex {
////                                        player.play()
////                                    }
////                                }
////                            }
//                            .onTapGesture {
//                                                           if let player = videoPreloader.getPlayer(for: item.id) {
//                                                               if player.timeControlStatus == .playing {
//                                                                   player.pause()
//                                                               } else if index == currentIndex {
//                                                                   player.play()
//                                                               }
//                                                           }
//                                                       }
//                        }
//                    } else {
//                        PodItemCellImage(item: item)
//                            .id(item.id)
//                    }
//
//                    VStack {
//                        Spacer()
//                        HStack(alignment: .bottom) {
//                            VStack(alignment: .leading) {
//                                Text(item.notes)
//                            }
//                            .foregroundStyle(.white)
//                            .font(.body)
//                            Spacer()
//                        }
//                        .padding(.bottom, 80)
//                    }
//                    .padding()
//                }
//                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//            }
//        }
//        .background(Color.black)
////        .onAppear {
////            self.lifecycleDelegate?.onAppear()
////            if let player = players[currentIndex] {
////                player.play()
////            }
////        }
////        .onDisappear {
////            self.lifecycleDelegate?.onDisappear()
////            for player in players.values {
////                player.pause()
////            }
////        }
////        .onChange(of: currentIndex) { oldIndex, newIndex in
////            players[oldIndex]?.pause()
////            players[newIndex]?.seek(to: .zero)
////            players[newIndex]?.play()
////        }
//        .onAppear {
//                  self.lifecycleDelegate?.onAppear()
//                  if let player = videoPreloader.getPlayer(for: items[currentIndex].id) {
//                      player.play()
//                  }
//              }
//              .onDisappear {
//                  self.lifecycleDelegate?.onDisappear()
//                  for item in items {
//                      videoPreloader.getPlayer(for: item.id)?.pause()
//                  }
//              }
//              .onChange(of: currentIndex) { oldValue, newValue in
//                          videoPreloader.updatePreloadedVideos(currentIndex: newValue, items: items)
//                      }
////              .onChange(of: currentIndex) { oldIndex, newIndex in
////                  videoPreloader.getPlayer(for: items[oldIndex].id)?.pause()
////                  if let player = videoPreloader.getPlayer(for: items[newIndex].id) {
////                      player.seek(to: .zero)
////                      player.play()
////                  }
////              }
//    }
//}
struct PlayerPageView: UIViewRepresentable {
    var items: [PodItem]
    @Binding var currentIndex: Int
    var videoPreloader: VideoPreloader

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let view = UIScrollView()
        
        let childView = UIHostingController(rootView: PlayerView(items: self.items, lifecycleDelegate: context.coordinator, currentIndex: $currentIndex, videoPreloader: videoPreloader))
        childView.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))
        
        view.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))

        view.addSubview(childView.view)
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.isPagingEnabled = true
        view.delegate = context.coordinator

        view.bounces = false
        context.coordinator.setupInitialVideo(view: view)
        return view
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        uiView.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))

        for i in 0..<uiView.subviews.count {
            uiView.subviews[i].frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate, ViewLifecycleDelegate {
        var parent: PlayerPageView

        init(parent: PlayerPageView) {
            self.parent = parent
        }

        func setupInitialVideo(view: UIScrollView) {
            let yOffset = CGFloat(parent.currentIndex) * UIScreen.main.bounds.height
            view.setContentOffset(CGPoint(x: 0, y: yOffset), animated: false)
            playVideoAtCurrentIndex()
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let currentIndex = Int(scrollView.contentOffset.y / UIScreen.main.bounds.height)
            parent.currentIndex = currentIndex
            playVideoAtCurrentIndex()
        }

        func onAppear() {
            playVideoAtCurrentIndex()
        }
        
        func onDisappear() {
            pauseAllVideos()
        }

        private func playVideoAtCurrentIndex() {
            pauseAllVideos()
            if parent.currentIndex >= 0 && parent.currentIndex < parent.items.count {
                if let player = parent.videoPreloader.getPlayer(for: parent.items[parent.currentIndex].id) {
                    player.seek(to: .zero)
                    player.play()
                }
            }
        }

        private func pauseAllVideos() {
            for item in parent.items {
                parent.videoPreloader.getPlayer(for: item.id)?.pause()
            }
        }
    }
}

//
//struct PlayerPageView: UIViewRepresentable {
//    var items: [PodItem]
//    @Binding var currentIndex: Int
//    var videoPreloader: VideoPreloader
//
//    func makeCoordinator() -> Coordinator {
//        return Coordinator(parent: self)
//    }
//
//    func makeUIView(context: Context) -> UIScrollView {
//        let view = UIScrollView()
//        
//        let childView = UIHostingController(rootView: PlayerView(items: self.items, lifecycleDelegate: context.coordinator, currentIndex: $currentIndex, videoPreloader: videoPreloader))
//        childView.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))
//        
//        view.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))
//
//        view.addSubview(childView.view)
//        view.showsVerticalScrollIndicator = false
//        view.showsHorizontalScrollIndicator = false
//        view.contentInsetAdjustmentBehavior = .never
//        view.isPagingEnabled = true
//        view.delegate = context.coordinator
//
//        view.bounces = false
//        context.coordinator.setupInitialVideo(view: view)
//        return view
//    }
//
//    func updateUIView(_ uiView: UIScrollView, context: Context) {
//        uiView.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))
//
//        for i in 0..<uiView.subviews.count {
//            uiView.subviews[i].frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))
//        }
//    }
//
//    class Coordinator: NSObject, UIScrollViewDelegate, ViewLifecycleDelegate {
//        var parent: PlayerPageView
//        var index = 0
//
//        init(parent: PlayerPageView) {
//            self.parent = parent
//            self.index = parent.currentIndex
//        }
//
//        func setupInitialVideo(view: UIScrollView) {
//            let yOffset = CGFloat(parent.currentIndex) * UIScreen.main.bounds.height
//            view.setContentOffset(CGPoint(x: 0, y: yOffset), animated: false)
//        }
//
//        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//            let currentIndex = Int(scrollView.contentOffset.y / UIScreen.main.bounds.height)
//            parent.currentIndex = currentIndex
//        }
//
//
//        func onAppear() {
//            // Play the initial video
//            if index >= 0 && index < parent.items.count {
//                parent.items[index].player?.play()
//            }
//        }
//        
//        func onDisappear() {
//            // Pause all videos
//            for item in parent.items {
//                item.player?.pause()
//            }
//        }
//   
//    }
//}

