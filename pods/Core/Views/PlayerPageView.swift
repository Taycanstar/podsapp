////
////  PlayerPageView.swift
////  pods
////
////  Created by Dimi Nunez on 4/28/24.
//
//
//import SwiftUI
//import AVKit
//
//protocol ViewLifecycleDelegate {
//    func onAppear()
//    func onDisappear()
//}
//
//struct Player : UIViewControllerRepresentable {
//    
//    var player : AVPlayer
//    
//    func makeUIViewController(context: Context) -> AVPlayerViewController{
//        let view = AVPlayerViewController()
//        view.player = player
//        view.showsPlaybackControls = false
//        view.videoGravity = .resizeAspectFill
//        return view
//    }
//    
//    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
//        
//    }
//}
//
//struct PlayerView : View {
////    @Binding var videos : [Video]
//    @Environment(\.presentationMode) var presentationMode
//
//     var items: [PodItem]
//    let lifecycleDelegate: ViewLifecycleDelegate?
//    
//    var body: some View{
//      
//            
//            
//            VStack(spacing: 0) {
//                
//                ForEach(items) { item in  // Direct iteration over items
//                    
//                    ZStack {
//                  
//                            if item.videoURL != nil {
//                                if let player = item.player {
//                            CustomVideoPlayer(player: player)
//                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//                                .offset(y: -30)
//                                .onTapGesture {
//                                    // Toggle play/pause directly on the player
//                                    if player.timeControlStatus == .playing {
//                                        player.pause()
//                                    } else {
//                                        player.play()
//                                    }
//                                }
//                                              } else {
//                                                  Text("Video unavailable")
//                                                      .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//                                                      .background(Color.gray)
//                                              }
//                          
//                    }else {
//                        PodItemCellImage(item: item)
//                            .id(item.id)
//                            
//                        }
//      
//                    //Vstack goes here
//                        
//                                                VStack{
//                                                    Spacer()
//                        
//                                                    HStack(alignment: .bottom){
//                                                        VStack(alignment: .leading) {
////                                                            Text("Lewis Hamilton")
////                                                                .fontWeight(.semibold)
//                                                          
//                                                            
//                                                            Text(item.notes)}
//                                                        .foregroundStyle(.white)
//                                                        .font(.body)
//                        
//                                                        Spacer()
//                        
////                                                        VStack(spacing: 28){
////                                                            Circle()
////                                                                .frame(width: 48, height: 48)
////                                                                .foregroundStyle(.gray)
////                                                            Button{
////                                                            } label:{
////                                                                VStack{
////                                                                    Image(systemName: "heart.fill")
////                                                                        .resizable()
////                                                                        .frame(width: 28, height: 28)
////                                                                        .foregroundStyle(.white)
////                                                                    Text("27")
////                                                                        .font(.caption)
////                                                                        .foregroundStyle(.white)
////                                                                    .bold()}}
////                                                            Button{
////                                                            } label:{
////                                                                VStack{
////                                                                    Image(systemName: "ellipsis.bubble.fill")
////                                                                        .resizable()
////                                                                        .frame(width: 28, height: 28)
////                                                                        .foregroundStyle(.white)
////                                                                    Text("27")
////                                                                        .font(.caption)
////                                                                        .foregroundStyle(.white)
////                                                                    .bold()}}
////                                                            Button{
////                                                            } label:{
////                                                                VStack{
////                                                                    Image(systemName: "bookmark.fill")
////                                                                        .resizable()
////                                                                        .frame(width: 22, height: 28)
////                                                                        .foregroundStyle(.white)
////                                                                    Text("27")
////                                                                        .font(.caption)
////                                                                        .foregroundStyle(.white)
////                                                                    .bold()}}
////                                                            Button{
////                                                            } label:{
////                                                                VStack{
////                                                                    Image(systemName: "arrowshape.turn.up.right.fill")
////                                                                        .resizable()
////                                                                        .frame(width: 28, height: 28)
////                                                                        .foregroundStyle(.white)
////                        
////                                                                    Text("27")
////                                                                        .font(.caption)
////                                                                        .foregroundStyle(.white)
////                                                                        .bold()
////                                                                }
////                                                            }
////                                                        }
//                                                    }
//                                                    .padding(.bottom,80)
//                                                }
//                                                .padding()
//                        
//                        //VStack end
//
//                        
//                        
//                    }
//                    
//                }
//         
//                
//              
//            }
//            .onAppear {
//                self.lifecycleDelegate?.onAppear()
//            }
//            .onDisappear {
//                self.lifecycleDelegate?.onDisappear()
//            }
//            .padding(.bottom,80)
////
////            .navigationBarHidden(true)
////            .navigationBarBackButtonHidden(true)
////            .navigationBarItems(leading: backButton)
////            .scrollIndicators(.hidden)
//
//
//            
//        }
//    
//    private var backButton: some View {
//        
//        Button(action: {
//            presentationMode.wrappedValue.dismiss()
//        }) {
//            Image(systemName: "chevron.left").foregroundColor(.white)
//                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
//                .font(.system(size: 24))
//        }
//        
//        
//    }
//
//}

//
//struct PlayerPageView : UIViewRepresentable {
//    
//    //    func makeCoordinator() -> Coordinator {
//    //        return PlayerPageView.Coordinator(parent1: self)
//    //    }
//    func makeCoordinator() -> Coordinator {
//        return Coordinator(parent: self)
//    }
//    
//    
//    var items: [PodItem]
//    @Binding var currentIndex: Int
//    func makeUIView(context: Context) -> UIScrollView{
//        
//        let view = UIScrollView()
//        
//        let childView = UIHostingController(rootView: PlayerView(items: self.items, lifecycleDelegate: context.coordinator))
//        childView.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat((items.count)))
//        //        view.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat((items.count)))
//        //        
//        let tabBarHeight: CGFloat = 55
//        let totalHeight = (UIScreen.main.bounds.height + tabBarHeight) * CGFloat(items.count)
//        view.contentSize = CGSize(width: UIScreen.main.bounds.width, height: totalHeight)
//        
//        view.addSubview(childView.view)
//        view.showsVerticalScrollIndicator = false
//        view.showsHorizontalScrollIndicator = false
//        view.contentInsetAdjustmentBehavior = .never
//        view.isPagingEnabled = true
//        view.delegate = context.coordinator
//        
//        view.contentInsetAdjustmentBehavior = .never
//        view.bounces = false  // Disable bouncing
//        context.coordinator.setupInitialVideo(view: view)
//        return view
//        
//    }
//    
//    func updateUIView(_ uiView: UIScrollView, context: Context) {
//        let tabBarHeight: CGFloat = 55
//        //        let childHeight = UIScreen.main.bounds.height - tabBarHeight
//        uiView.contentSize = CGSize(width: UIScreen.main.bounds.width, height: (UIScreen.main.bounds.height + tabBarHeight) * CGFloat((items.count)))
//        
//        for i in 0..<uiView.subviews.count{
//            uiView.subviews[i].frame = CGRect(x: 0, y: 0,width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat((items.count)))
//        }
//        
//        
//        
//    }
//    
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
//            
//            prepareAndPlayVideo(at: parent.currentIndex)
//            preloadAdjacentVideos(currentIndex: parent.currentIndex)
//        }
//        
////        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
////            let currentIndex = Int(scrollView.contentOffset.y / UIScreen.main.bounds.height)
////            parent.currentIndex = currentIndex
////            
////            if index != currentIndex {
////                parent.items[index].player?.pause()
////                
////                index = currentIndex
////                parent.currentIndex = index
////                prepareAndPlayVideo(at: index)
////                preloadAdjacentVideos(currentIndex: index)
////            }
////        }
//        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//            let currentIndex = Int(scrollView.contentOffset.y / UIScreen.main.bounds.height)
//            parent.currentIndex = currentIndex
//            
//            if index != currentIndex {
//                parent.items[index].player?.pause()
//                
//                index = currentIndex
//                parent.currentIndex = index
//                DispatchQueue.global(qos: .userInitiated).async {
//                    self.preloadAdjacentVideos(currentIndex: self.index)
//                    DispatchQueue.main.async {
//                        self.prepareAndPlayVideo(at: self.index)
//                    }
//                }
//            }
//        }
//
//        func prepareAndPlayVideo(at index: Int) {
//            DispatchQueue.main.async {
//                if self.parent.items[index].player == nil {
//                    self.parent.items[index].preparePlayer()
//                }
//                self.parent.items[index].player?.seek(to: .zero)
//                self.parent.items[index].player?.play()
//                self.setupPlayerObserver(for: index)
//            }
//        }
////        
////        func preloadAdjacentVideos(currentIndex: Int) {
////            let indicesToPreload = [currentIndex - 1, currentIndex + 1]
////            for index in indicesToPreload where index >= 0 && index < parent.items.count {
////                if parent.items[index].player == nil {
////                    parent.items[index].preparePlayer()
////                }
////            }
////        }
//        func preloadAdjacentVideos(currentIndex: Int) {
//            let indicesToPreload = [currentIndex - 1, currentIndex, currentIndex + 1]
//            for index in indicesToPreload where index >= 0 && index < parent.items.count {
//                if parent.items[index].player == nil {
//                    DispatchQueue.global(qos: .userInitiated).async {
//                        // Prepare assets in background
//                        guard let url = self.parent.items[index].videoURL else { return }
//                        let asset = AVAsset(url: url)
//                        let playerItem = AVPlayerItem(asset: asset)
//                        
//                        // Create player on main thread
//                        DispatchQueue.main.async {
//                            self.parent.items[index].player = AVPlayer(playerItem: playerItem)
//                        }
//                    }
//                }
//            }
//        }
//
//        func setupPlayerObserver(for index: Int) {
//            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
//            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: parent.items[index].player?.currentItem, queue: .main) { [weak self] _ in
//                self?.parent.items[index].player?.seek(to: .zero)
//                self?.parent.items[index].player?.play()
//            }
//        }
//        
//        func onAppear() {
//            prepareAndPlayVideo(at: index)
//            preloadAdjacentVideos(currentIndex: index)
//        }
//        
//        func onDisappear() {
//            parent.items[index].player?.pause()
//            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
//        }
//    }
//}
//Fav version start
import SwiftUI
import AVKit
import UIKit
import AVFoundation
import Combine



protocol ViewLifecycleDelegate {
    func onAppear()
    func onDisappear()
}

struct Player: UIViewControllerRepresentable {
    var player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let view = AVPlayerViewController()
        view.player = player
        view.showsPlaybackControls = false
        view.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
//working start
//struct PlayerView: View {
//    @Environment(\.presentationMode) var presentationMode
//    @State private var items: [PodItem]
//    let lifecycleDelegate: ViewLifecycleDelegate?
//    @State private var isLoading: [Bool]
//    @State private var errorMessage: [String?]
//    
//    init(items: [PodItem], lifecycleDelegate: ViewLifecycleDelegate?) {
//        self._items = State(initialValue: items)
//        self.lifecycleDelegate = lifecycleDelegate
//        self._isLoading = State(initialValue: Array(repeating: false, count: items.count))
//        self._errorMessage = State(initialValue: Array(repeating: nil, count: items.count))
//    }
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            ForEach(Array(items.enumerated()), id: \.element.id) { (index, item) in
//                ZStack {
//                    if isLoading[index] {
//                        ProgressView()
//                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//                            .background(Color.black.opacity(0.5))
//                    } else if let error = errorMessage[index] {
//                        VStack {
//                            Text(error)
//                            Button("Retry") {
//                                loadVideo(for: item, at: index)
//                            }
//                        }
//                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//                        .background(Color.black.opacity(0.5))
//                    } else if item.videoURL != nil {
//                        if let player = item.player {
//                            CustomVideoPlayer(player: player)
//                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//                                .offset(y: -30)
//                                .onTapGesture {
//                                    if player.timeControlStatus == .playing {
//                                        player.pause()
//                                    } else {
//                                        player.play()
//                                    }
//                                }
//                        } else {
//                            Text("Video unavailable")
//                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//                                .background(Color.gray)
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
//    func loadVideo(for item: PodItem, at index: Int) {
//        guard let url = item.videoURL else {
//            errorMessage[index] = "Invalid URL"
//            return
//        }
//        
//        isLoading[index] = true
//        errorMessage[index] = nil
//        
//        let asset = AVAsset(url: url)
//        let playerItem = AVPlayerItem(asset: asset)
//        
//        asset.loadValuesAsynchronously(forKeys: ["playable"]) {
//            DispatchQueue.main.async {
//                var error: NSError?
//                let status = asset.statusOfValue(forKey: "playable", error: &error)
//                
//                switch status {
//                case .loaded:
//                    self.items[index].player = AVPlayer(playerItem: playerItem)
//                    self.items[index].player?.play()
//                    self.isLoading[index] = false
//                case .failed:
//                    self.errorMessage[index] = error?.localizedDescription ?? "Failed to load video"
//                    self.isLoading[index] = false
//                default:
//                    break
//                }
//            }
//        }
//    }
//}
//working end
struct PlayerView: View {
    @State private var items: [PodItem]
    @Binding var currentIndex: Int
    var videoLoader: VideoLoader
    let lifecycleDelegate: ViewLifecycleDelegate?
    @State private var isLoading: [Bool]
    @State private var errorMessage: [String?]
    @State private var players: [AVPlayer?]
    
    init(items: [PodItem], currentIndex: Binding<Int>, videoLoader: VideoLoader, lifecycleDelegate: ViewLifecycleDelegate?) {
        self._items = State(initialValue: items)
        self._currentIndex = currentIndex
        self.videoLoader = videoLoader
        self.lifecycleDelegate = lifecycleDelegate
        self._isLoading = State(initialValue: Array(repeating: false, count: items.count))
        self._errorMessage = State(initialValue: Array(repeating: nil, count: items.count))
        self._players = State(initialValue: Array(repeating: nil, count: items.count))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { (index, item) in
                
                if item.videoURL != nil {
                    VideoPlayerView(item: item,
                                    videoLoader: videoLoader,
                                    isLoading: $isLoading[index],
                                    errorMessage: $errorMessage[index],
                                    player: $players[index],
                                    isCurrentlyPlaying: index == currentIndex)
                    .overlay(
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
                    )
              
        }else {
            PodItemCellImage(item: item)
                .id(item.id)
                .overlay(
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
                )
                
            }
             
            }
        }
        .onAppear {
            self.lifecycleDelegate?.onAppear()
            loadCurrentAndAdjacentVideos()
        }
        .onDisappear {
            self.lifecycleDelegate?.onDisappear()
        }
        .onChange(of: currentIndex) { _ in
            loadCurrentAndAdjacentVideos()
            pauseAllVideosExcept(currentIndex)
        }
        .padding(.bottom, 80)
    }
    
    private func loadCurrentAndAdjacentVideos() {
        let indicesToLoad = [currentIndex - 1, currentIndex, currentIndex + 1]
        for index in indicesToLoad where index >= 0 && index < items.count {
            loadVideo(for: items[index], at: index)
        }
    }
    
    private func loadVideo(for item: PodItem, at index: Int) {
        if players[index] == nil {
            isLoading[index] = true
            errorMessage[index] = nil
            
            videoLoader.loadVideo(for: item) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let player):
                        self.players[index] = player
                        self.isLoading[index] = false
                        if index == self.currentIndex {
                            player.play()
                        }
                    case .failure(let error):
                        self.errorMessage[index] = error.localizedDescription
                        self.isLoading[index] = false
                    }
                }
            }
        }
    }
    
    private func pauseAllVideosExcept(_ index: Int) {
        for (idx, player) in players.enumerated() {
            if idx != index {
                player?.pause()
            } else {
                player?.play()
            }
        }
    }
}

//
//struct PlayerPageView: UIViewRepresentable {
//    @State var items: [PodItem]
//    @Binding var currentIndex: Int
//    
//    func makeCoordinator() -> Coordinator {
//        return Coordinator(parent: self)
//    }
//    
//    func makeUIView(context: Context) -> UIScrollView {
//        let view = UIScrollView()
//        
//        let childView = UIHostingController(rootView: PlayerView(items: items, lifecycleDelegate: context.coordinator))
//        childView.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))
//        
//        let tabBarHeight: CGFloat = 55
//        let totalHeight = (UIScreen.main.bounds.height + tabBarHeight) * CGFloat(items.count)
//        view.contentSize = CGSize(width: UIScreen.main.bounds.width, height: totalHeight)
//        
//        view.addSubview(childView.view)
//        view.showsVerticalScrollIndicator = false
//        view.showsHorizontalScrollIndicator = false
//        view.contentInsetAdjustmentBehavior = .never
//        view.isPagingEnabled = true
//        view.delegate = context.coordinator
//        
//        view.bounces = false  // Disable bouncing
//        context.coordinator.setupInitialVideo(view: view)
//        return view
//    }
//    
//    func updateUIView(_ uiView: UIScrollView, context: Context) {
//        let tabBarHeight: CGFloat = 55
//        uiView.contentSize = CGSize(width: UIScreen.main.bounds.width, height: (UIScreen.main.bounds.height + tabBarHeight) * CGFloat(items.count))
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
//            
//            prepareAndPlayVideo(at: parent.currentIndex)
//            preloadAdjacentVideos(currentIndex: parent.currentIndex)
//        }
//        
//        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//            let currentIndex = Int(scrollView.contentOffset.y / UIScreen.main.bounds.height)
//            parent.currentIndex = currentIndex
//            
//            if index != currentIndex {
//                parent.items[index].player?.pause()
//                
//                index = currentIndex
//                parent.currentIndex = index
//                DispatchQueue.global(qos: .userInitiated).async {
//                    self.preloadAdjacentVideos(currentIndex: self.index)
//                    DispatchQueue.main.async {
//                        self.prepareAndPlayVideo(at: self.index)
//                    }
//                }
//            }
//        }
//        
//        func prepareAndPlayVideo(at index: Int) {
//            if parent.items[index].player == nil {
//                loadVideo(at: index)
//            } else {
//                parent.items[index].player?.seek(to: .zero)
//                parent.items[index].player?.play()
//            }
//            setupPlayerObserver(for: index)
//        }
//        
//        func loadVideo(at index: Int) {
//            guard index >= 0 && index < parent.items.count,
//                  let url = parent.items[index].videoURL else { return }
//            
//            let asset = AVAsset(url: url)
//            let playerItem = AVPlayerItem(asset: asset)
//            
//            asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
//                DispatchQueue.main.async {
//                    var error: NSError?
//                    let status = asset.statusOfValue(forKey: "playable", error: &error)
//                    
//                    if status == .loaded {
//                        self?.parent.items[index].player = AVPlayer(playerItem: playerItem)
//                        self?.parent.items[index].player?.play()
//                    }
//                }
//            }
//        }
//        
//        func preloadAdjacentVideos(currentIndex: Int) {
//            let indicesToPreload = [currentIndex - 1, currentIndex + 1]
//            for index in indicesToPreload where index >= 0 && index < parent.items.count {
//                if parent.items[index].player == nil {
//                    loadVideo(at: index)
//                }
//            }
//        }
//        
//        func setupPlayerObserver(for index: Int) {
//            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
//            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: parent.items[index].player?.currentItem, queue: .main) { [weak self] _ in
//                self?.parent.items[index].player?.seek(to: .zero)
//                self?.parent.items[index].player?.play()
//            }
//        }
//        
//        func onAppear() {
//            prepareAndPlayVideo(at: index)
//            preloadAdjacentVideos(currentIndex: index)
//        }
//        
//        func onDisappear() {
//            parent.items[index].player?.pause()
//            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
//        }
//    }
//}

//old version end

struct PlayerPageView: UIViewRepresentable {
    @State var items: [PodItem]
    @Binding var currentIndex: Int
    var videoLoader: VideoLoader
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let view = UIScrollView()
        
        let childView = UIHostingController(rootView: PlayerView(items: items, currentIndex: $currentIndex, videoLoader: videoLoader, lifecycleDelegate: context.coordinator))
        childView.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))
        
        let tabBarHeight: CGFloat = 55
        let totalHeight = (UIScreen.main.bounds.height + tabBarHeight) * CGFloat(items.count)
        view.contentSize = CGSize(width: UIScreen.main.bounds.width, height: totalHeight)
        
        view.addSubview(childView.view)
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.isPagingEnabled = true
        view.delegate = context.coordinator
        
        view.bounces = false  // Disable bouncing
        DispatchQueue.main.async {
            context.coordinator.setupInitialVideo(view: view)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        let tabBarHeight: CGFloat = 55
        uiView.contentSize = CGSize(width: UIScreen.main.bounds.width, height: (UIScreen.main.bounds.height + tabBarHeight) * CGFloat(items.count))
        
        for i in 0..<uiView.subviews.count {
            uiView.subviews[i].frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * CGFloat(items.count))
        }
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate, ViewLifecycleDelegate {
        var parent: PlayerPageView
        var index: Int
        
        init(parent: PlayerPageView) {
            self.parent = parent
            self.index = parent.currentIndex
        }
        
        func setupInitialVideo(view: UIScrollView) {
            let yOffset = CGFloat(parent.currentIndex) * UIScreen.main.bounds.height
            view.setContentOffset(CGPoint(x: 0, y: yOffset), animated: false)
            
            loadVideoForCurrentAndAdjacent(currentIndex: parent.currentIndex)
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let currentIndex = Int(scrollView.contentOffset.y / UIScreen.main.bounds.height)
            parent.currentIndex = currentIndex
            
            if index != currentIndex {
                index = currentIndex
                loadVideoForCurrentAndAdjacent(currentIndex: currentIndex)
            }
        }
        
        func loadVideoForCurrentAndAdjacent(currentIndex: Int) {
            let indicesToLoad = [currentIndex - 1, currentIndex, currentIndex + 1]
            for index in indicesToLoad where index >= 0 && index < parent.items.count {
                parent.videoLoader.loadVideo(for: parent.items[index]) { result in
                    // Handle the result if needed
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let player):
                            self.parent.items[index].player = player
                        case .failure(let error):
                            print("Failed to load video at index \(index): \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        func onAppear() {
            loadVideoForCurrentAndAdjacent(currentIndex: index)
        }
        
        func onDisappear() {
            // No need to implement anything here as video pausing is handled in VideoLoader
        }
    }
}


class VideoPlayerViewController: UIViewController {
    var item: PodItem?
    var videoLoader: VideoLoader?
    var index: Int = 0
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var cancellables = Set<AnyCancellable>()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupObserver()
        loadVideo()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupViews() {
        view.backgroundColor = .black
        
        view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        view.addSubview(errorLabel)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupObserver() {
        videoLoader?.$loadingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(for: state)
            }
            .store(in: &cancellables)
    }
    
    private func loadVideo() {
        guard let item = item else { return }
        videoLoader?.loadVideo(for: item) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let player):
                    self?.updateUI(for: .loaded(player))
                case .failure(let error):
                    self?.updateUI(for: .failed(error))
                }
            }
        }
    }
    
    private func updateUI(for state: VideoLoader.LoadingState) {
        switch state {
        case .idle, .loading:
            showLoadingIndicator()
        case .loaded(let player):
            hideLoadingIndicator()
            setupPlayer(player)
        case .failed(let error):
            hideLoadingIndicator()
            showErrorMessage(error.localizedDescription)
        }
    }
    
    private func setupPlayer(_ player: AVPlayer) {
        self.player = player
        playerLayer?.removeFromSuperlayer()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = view.bounds
        playerLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer!)
        
        player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidReachEnd(notification:)),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: player.currentItem)
        
        player.play()
    }
    
    @objc func playerItemDidReachEnd(notification: Notification) {
        player?.seek(to: CMTime.zero)
        player?.play()
    }
    
    @objc func handleTap() {
        if let player = player {
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
        }
    }
    
    private func showLoadingIndicator() {
        errorLabel.isHidden = true
        loadingIndicator.startAnimating()
    }
    
    private func hideLoadingIndicator() {
        loadingIndicator.stopAnimating()
    }
    
    private func showErrorMessage(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

//extra
struct VideoPlayerView: View {
    let item: PodItem
    @ObservedObject var videoLoader: VideoLoader
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    @Binding var player: AVPlayer?
    let isCurrentlyPlaying: Bool
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .background(Color.black.opacity(0.5))
            } else if let error = errorMessage {
                VStack {
                    Text(error)
                    Button("Retry") {
                        loadVideo()
                    }
                }
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .background(Color.black.opacity(0.5))
            } else if let player = player {
                Player(player: player)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .onAppear {
                        if isCurrentlyPlaying {
                            player.play()
                        } else {
                            player.pause()
                        }
                        setupLooping(for: player)
                    }
                    .onChange(of: isCurrentlyPlaying) { newValue in
                        if newValue {
                            player.play()
                        } else {
                            player.pause()
                        }
                    }
            } else {
                Text("No content available")
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .background(Color.gray)
            }
        }
        .onAppear {
            if player == nil && item.videoURL != nil {
                loadVideo()
            }
        }
    }
    
    private func loadVideo() {
        guard let videoURL = item.videoURL else {
            errorMessage = "Invalid video URL"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        videoLoader.loadVideo(for: item) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newPlayer):
                    self.player = newPlayer
                    self.isLoading = false
                    if self.isCurrentlyPlaying {
                        newPlayer.play()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    private func setupLooping(for player: AVPlayer) {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }
}
