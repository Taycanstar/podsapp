//
//  TourView.swift
//  Podstack
//
//  Created by Dimi Nunez on 6/25/24.
//

import SwiftUI
import AVKit

struct TourView: View {
    @State private var currentIndex: Int = 0
    let videos: [String] = ["app1", "app2"]
    @Binding var isTourViewPresented: Bool
    
    var body: some View {
        
      
        VStack {
            videoCarousel
                .background(Color.white)
                .frame(maxHeight: .infinity)

            pageControl

            continueButton
                .padding(.bottom, 20)
                .padding(.horizontal, 30)
        }
        .navigationTitle("Tour")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.white.edgesIgnoringSafeArea(.all))
        
    }
    
    private var videoCarousel: some View {
        TabView(selection: $currentIndex) {
            ForEach(0..<videos.count, id: \.self) { index in
//                VideoPlayerView(videoName: videos[index])
                CustomVideoPlayerView(videoName: videos[index])
                    .tag(index)
            }
            .background(Color.white)
        }
        .background(Color.white)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(height: UIScreen.main.bounds.height * 0.7) // Adjust height as needed
    }
    
    private var pageControl: some View {
        HStack {
            Spacer()
            PageControl(currentIndex: $currentIndex, numberOfPages: videos.count)
            Spacer()
        }
        .background(.white)
        .padding(.bottom, 10)
    }
    
    private var continueButton: some View {
        Button(action: {
            if currentIndex < videos.count - 1 {
                        currentIndex += 1
                    } else {
                        isTourViewPresented = false
                    }
        }) {
            Text(currentIndex < videos.count - 1 ? "Next" : "Continue")
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .padding(.horizontal)
                .fontWeight(.semibold)
                .font(.system(size: 16))
                .background(Color(red: 70/255, green: 87/255, blue: 245/255))
                .cornerRadius(15)
        }
        .frame(height: 50)
    }
}

struct VideoPlayerView: View {
    let videoName: String
    @State private var player: AVQueuePlayer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white  // This will fill the entire area with white
                
                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fit)
                        .frame(width: geometry.size.width * 0.9,  height: geometry.size.height)
                        .clipped()
                        .background(.white)
                } else {
                    Text("Loading video...")
                }
            }
        }
        .background(Color.white)
        .onAppear(perform: setupPlayer)
        .onDisappear(perform: cleanupPlayer)
    }
    
    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            print("Video file not found")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVQueuePlayer(playerItem: playerItem)
        
        // Loop the video
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
            player?.seek(to: CMTime.zero)
            player?.play()
        }
        
        player?.play()
    }
    
    private func cleanupPlayer() {
        player?.pause()
        player = nil
    }
}

struct PageControl: View {
    @Binding var currentIndex: Int
    let numberOfPages: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color(red: 70/255, green: 87/255, blue: 245/255) : Color.gray)
                    .frame(width: 7, height: 7)
            }
        }
    }
}

struct CustomVideoPlayerView: UIViewControllerRepresentable {
    let videoName: String
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerViewController = AVPlayerViewController()
        playerViewController.showsPlaybackControls = false
        playerViewController.view.backgroundColor = UIColor.white
        playerViewController.player = createPlayer()
        return playerViewController
    }
    
    func updateUIViewController(_ playerViewController: AVPlayerViewController, context: Context) {
        playerViewController.player = createPlayer()
        playerViewController.view.backgroundColor = UIColor.white
    }
    
    private func createPlayer() -> AVPlayer? {
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            print("Video file not found")
            return nil
        }
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        
        // Loop the video
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
            player.seek(to: CMTime.zero)
            player.play()
        }
        
        player.play()
        return player
    }
    
    func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: ()) {
        uiViewController.player?.pause()
        uiViewController.player = nil
    }
}


