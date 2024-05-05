//
//  MediaManager.swift
//  pods
//
//  Created by Dimi Nunez on 4/27/24.
//
import AVFoundation

class MediaManager {
    static let shared = MediaManager()
    private var playerItems: [Int: AVPlayerItem] = [:]
    private var player = AVPlayer()

    func preloadMedia(for items: [PodItem]) {
        items.forEach { item in
            if let url = item.videoURL {
                let asset = AVAsset(url: url)
                let playerItem = AVPlayerItem(asset: asset)
                playerItems[item.id] = playerItem
            }
        }
    }

    func getPlayerItem(for itemId: Int) -> AVPlayerItem? {
        return playerItems[itemId]
    }

    func getPlayer() -> AVPlayer {
        return player
    }

    func cleanup() {
        playerItems.removeAll()
    }
}
