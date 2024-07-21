//
//  PlayerContainerView.swift
//  pods
//
//  Created by Dimi Nunez on 4/28/24.
//
//
//import SwiftUI
//
//struct PlayerContainerView: View {
//    @State private var index = 0
//    var items: [PodItem]
//    @Environment(\.presentationMode) var presentationMode
//    @State private var currentIndex = 0
//    @EnvironmentObject var sharedViewModel: SharedViewModel
////    @State var initialIndex: Int
//
//    
//    init(items: [PodItem], initialIndex: Int) {
//            self.items = items
//            self._currentIndex = State(initialValue: initialIndex)
//        }
//  
//
//    var body: some View {
//        ZStack(alignment: .topLeading) {
//            PlayerPageView(items: items, currentIndex: $currentIndex)
//          
//                .background(Color.black
//                    .edgesIgnoringSafeArea(.all))
//                .edgesIgnoringSafeArea(.all)
//
//                         .toolbar {
//                             ToolbarItem(placement: .navigationBarLeading) {
//                                 backButton
//                             }
//                             ToolbarItem(placement: .principal) {
//                                 Text(displayTitle())
//                                     .foregroundColor(.white)
//                                     .font(.headline)
//                             }
//                         }
//                         .onAppear {
//                                    sharedViewModel.isItemViewActive = true
////                             currentIndex = initialIndex
//                             
//                                }
//                                .onDisappear {
//                                    sharedViewModel.isItemViewActive = false
//                                }
//                      
//                .navigationBarBackButtonHidden(true)
//        
//               }
//        
//
//        }
//    
//
//    private var backButton: some View {
//        
//        Button(action: {
//            presentationMode.wrappedValue.dismiss()
//        }) {
//            Image(systemName: "chevron.left").foregroundColor(.white)
//                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
//                .font(.system(size: 20))
//        }
//    }
//    
//    private func displayTitle() -> String {
//           if items.indices.contains(currentIndex) {
//               return items[currentIndex].metadata // Assuming metadata is a String
//           }
//           return "No Video"
//       }
//    
//    
//}
import SwiftUI
import AVKit
import AVFoundation

struct PlayerContainerView: View {
    @State private var currentIndex: Int
    var items: [PodItem]
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sharedViewModel: SharedViewModel
    @StateObject private var videoLoader = VideoLoader()

    init(items: [PodItem], initialIndex: Int) {
        self.items = items
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlayerPageView(items: items, currentIndex: $currentIndex, videoLoader: videoLoader)
//            PlayerPageView(items: items, currentIndex: $currentIndex)
                .background(Color.black.edgesIgnoringSafeArea(.all))
                .edgesIgnoringSafeArea(.all)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        backButton
                    }
                    ToolbarItem(placement: .principal) {
                        Text(displayTitle())
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
//                .onAppear {
//                    sharedViewModel.isItemViewActive = true
//                    videoLoader.loadVideo(for: items[currentIndex])
//                }
                .onAppear {
                                 sharedViewModel.isItemViewActive = true
                                 videoLoader.loadVideo(for: items[currentIndex]) { result in
                                     switch result {
                                     case .success(let player):
                                         // Handle successful video loading if needed
                                         print("Video loaded successfully for index \(self.currentIndex)")
                                     case .failure(let error):
                                         // Handle error if needed
                                         print("Failed to load video for index \(self.currentIndex): \(error.localizedDescription)")
                                     }
                                 }
                             }
                .onDisappear {
                    sharedViewModel.isItemViewActive = false
                    videoLoader.cancelLoading()
                }
                .navigationBarBackButtonHidden(true)
        }
    }

    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left").foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                .font(.system(size: 20))
        }
    }

    private func displayTitle() -> String {
        if items.indices.contains(currentIndex) {
            return items[currentIndex].metadata
        }
        return "No Video"
    }
}

//class VideoLoader: ObservableObject {
//    @Published var loadingState: LoadingState = .idle
//
//    enum LoadingState {
//        case idle
//        case loading
//        case loaded(AVPlayer)
//        case failed(Error)
//    }
//
//    func loadVideo(for item: PodItem) {
//        guard let url = item.videoURL else {
//            loadingState = .failed(NSError(domain: "VideoLoader", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
//            return
//        }
//
//        loadingState = .loading
//
//        let asset = AVAsset(url: url)
//        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
//            DispatchQueue.main.async {
//                var error: NSError?
//                let status = asset.statusOfValue(forKey: "playable", error: &error)
//                
//                switch status {
//                case .loaded:
//                    if asset.isPlayable {
//                        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
//                        self?.loadingState = .loaded(player)
//                    } else {
//                        self?.loadingState = .failed(NSError(domain: "VideoLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Video is not playable"]))
//                    }
//                case .failed:
//                    self?.loadingState = .failed(error ?? NSError(domain: "VideoLoader", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load video"]))
//                case .cancelled:
//                    self?.loadingState = .idle
//                default:
//                    break
//                }
//            }
//        }
//    }
//
//    func cancelLoading() {
//        loadingState = .idle
//    }
//}

class VideoLoader: ObservableObject {
    @Published var loadingState: LoadingState = .idle

    enum LoadingState {
        case idle
        case loading
        case loaded(AVPlayer)
        case failed(Error)
    }

    func loadVideo(for item: PodItem, completion: @escaping (Result<AVPlayer, Error>) -> Void) {
        guard let url = item.videoURL else {
            completion(.failure(NSError(domain: "VideoLoader", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        loadingState = .loading

        let asset = AVAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
            DispatchQueue.main.async {
                var error: NSError?
                let status = asset.statusOfValue(forKey: "playable", error: &error)
                
                switch status {
                case .loaded:
                    if asset.isPlayable {
                        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                        self?.loadingState = .loaded(player)
                        completion(.success(player))
                    } else {
                        let error = NSError(domain: "VideoLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Video is not playable"])
                        self?.loadingState = .failed(error)
                        completion(.failure(error))
                    }
                case .failed:
                    let error = error ?? NSError(domain: "VideoLoader", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load video"])
                    self?.loadingState = .failed(error)
                    completion(.failure(error))
                case .cancelled:
                    self?.loadingState = .idle
                    completion(.failure(NSError(domain: "VideoLoader", code: 3, userInfo: [NSLocalizedDescriptionKey: "Video loading cancelled"])))
                default:
                    break
                }
            }
        }
    }

    func cancelLoading() {
        loadingState = .idle
    }
}
