//
//  VideoEditorViewController.swift
//  pods
//
//  Created by Dimi Nunez on 3/19/24.
//

import Foundation

import UIKit
import AVFoundation

class VideoEditorViewController: UIViewController {
    var videoURL: URL?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    
    // Add a delegate or closure to pass the edited video back
    var onConfirmEditing: ((URL) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black // Ensure the background is black for better visibility
        setupVideoPlayer()
        setupGestureRecognizers()
        setupUIControls()
//        extendViewToCoverEntireScreen()
    }
    
    private func setupUIControls() {
           let expandButton = UIButton(type: .system)
           expandButton.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
           expandButton.addTarget(self, action: #selector(handleExpand), for: .touchUpInside)

           let rotateButton = UIButton(type: .system)
           rotateButton.setImage(UIImage(systemName: "rotate.right"), for: .normal)
           rotateButton.addTarget(self, action: #selector(handleRotate), for: .touchUpInside)

           let confirmButton = UIButton(type: .system)
           confirmButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
           confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)

           // Layout buttons, for simplicity we're adding them directly to the view
           let stackView = UIStackView(arrangedSubviews: [expandButton, rotateButton, confirmButton])
           stackView.axis = .horizontal
           stackView.distribution = .equalSpacing
           stackView.translatesAutoresizingMaskIntoConstraints = false
           view.addSubview(stackView)

           // Constraints (adjust as needed)
           stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
           stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20).isActive = true
       }

       @objc private func handleExpand() {
           // Implement zoom-out to fit behavior
       }

       @objc private func handleRotate() {
           // Rotate the video by 90 degrees
           guard let layer = playerLayer else { return }
           let currentRotation = atan2(layer.transform.m12, layer.transform.m11)
           let newRotation = currentRotation + CGFloat.pi / 2 // Add 90 degrees
           layer.setAffineTransform(CGAffineTransform(rotationAngle: newRotation))
       }

       @objc private func handleConfirm() {
           // Pass the edited video URL back and dismiss the editor
           onConfirmEditing?(videoURL!) // Ensure you're passing the correct URL, possibly the edited one
           dismiss(animated: true, completion: nil)
       }

    private func setupVideoPlayer() {
        guard let videoURL = videoURL else { return }
        player = AVPlayer(url: videoURL)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = view.bounds
        playerLayer?.videoGravity = .resizeAspect // Change here for no cropping
        guard let playerLayer = playerLayer else { return }
        view.layer.addSublayer(playerLayer)
        player?.play()
        player?.actionAtItemEnd = .none // Loop the video
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidReachEnd(notification:)),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: player?.currentItem)
    }

    @objc func playerItemDidReachEnd(notification: Notification) {
        player?.seek(to: CMTime.zero)
        player?.play()
    }


    private func setupGestureRecognizers() {
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchRecognizer)

        let rotationRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        view.addGestureRecognizer(rotationRecognizer)
    }

//    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
//        guard let layer = playerLayer else { return }
//
//        if recognizer.state == .changed {
//            let scale = recognizer.scale
//            layer.transform = CATransform3DScale(layer.transform, scale, scale, scale)
//            recognizer.scale = 1 // Reset the scale to 1 to continuously compute scale change
//        }
//    }
    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let layer = playerLayer else { return }
        
        // Adjust scale based on pinch
        if recognizer.state == .changed {
            let scale = recognizer.scale
            var currentScale = sqrt(abs(layer.transform.m11 * layer.transform.m22))
            
            // Apply pinch scale to current scale but prevent zooming out beyond the initial scale
            currentScale *= scale
            let initialScale: CGFloat = 1.0 // Assume initial scale is 1.0 (fill screen)
            currentScale = max(currentScale, initialScale)
            
            // Apply scale to layer
            layer.setAffineTransform(CGAffineTransform(scaleX: currentScale, y: currentScale))
            recognizer.scale = 1 // Reset recognizer scale to 1
        }
        
        // When pinch ends, check if video is smaller than view and snap back if necessary
        if recognizer.state == .ended {
            // Calculate the scale that perfectly fits the video in the view
            let fitScale = calculateFitScaleForVideo()
            let currentScale = sqrt(abs(layer.transform.m11 * layer.transform.m22))
            
            // If current scale is less than the fit scale, animate back to fitting the view
            if currentScale < fitScale {
                UIView.animate(withDuration: 0.25) {
                    layer.setAffineTransform(CGAffineTransform(scaleX: fitScale, y: fitScale))
                }
            }
        }
    }

    /// Calculate the scale that would make the video fill the view.
    /// - Returns: A CGFloat representing the scale factor.
    private func calculateFitScaleForVideo() -> CGFloat {
        guard let layer = playerLayer else { return 1.0 }
        let videoAspect = layer.bounds.width / layer.bounds.height
        let viewAspect = view.bounds.width / view.bounds.height
        if videoAspect > viewAspect {
            // Video is wider than view
            return view.bounds.height / layer.bounds.height
        } else {
            // Video is narrower than view
            return view.bounds.width / layer.bounds.width
        }
    }


    
    private func extendViewToCoverEntireScreen() {
        if #available(iOS 11.0, *) {
            // Extend the view's edges to the screen's edges, ignoring the safe area.
            view.insetsLayoutMarginsFromSafeArea = false
            view.translatesAutoresizingMaskIntoConstraints = true
            view.frame = UIScreen.main.bounds
        }
    }

    @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        guard let layer = playerLayer else { return }

        if recognizer.state == .changed {
            let rotation = recognizer.rotation
            layer.transform = CATransform3DRotate(layer.transform, rotation, 0, 0, 1)
            recognizer.rotation = 0 // Reset the rotation to 0 to continuously compute rotation change
        }
    }
    
    // Assume additional UI elements and functionalities are implemented here...
}
