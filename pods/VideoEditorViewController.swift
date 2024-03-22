//
//  VideoEditorViewController.swift
//  pods
//
//  Created by Dimi Nunez on 3/19/24.
//

import Foundation

import UIKit
import AVFoundation

struct VideoEditParameters: Equatable {
    var rotationAngle: CGFloat = 0.0
    var scale: CGFloat?
    // Add other parameters like cropRect if needed
}

class VideoEditorViewController: UIViewController {
    var videoURL: URL?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    
    // Properties to track cumulative adjustments
    private var cumulativeRotation: CGFloat = 0.0
    private var cumulativeScale: CGFloat = 1.0
    
    // Add a delegate or closure to pass the edited video back
    // Update the delegate or closure type to pass edit parameters instead of URL
    var onConfirmEditing: ((VideoEditParameters) -> Void)?
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = self.view.bounds
        print("View bounds: \(self.view.bounds)") // Debugging frame sizes
        print("Player layer frame: \(playerLayer?.frame ?? CGRect.zero)") // Debugging frame sizes
    }



    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black // Ensure the background is black for better visibility
        setupVideoPlayer()
        setupGestureRecognizers()
        setupUIControls()
        
        if #available(iOS 11.0, *) {
             self.view.insetsLayoutMarginsFromSafeArea = false
         }

    }
 

    
    private func setupUIControls() {
        // Create and style the expand button
        let expandButton = createIconButton(systemName: "arrow.up.left.and.arrow.down.right", action: #selector(handleExpand))

        // Create and style the rotate button
        let rotateButton = createIconButton(systemName: "arrow.clockwise", action: #selector(handleRotate))

        // Create and style the confirm button
        let confirmButton = createIconButton(systemName: "checkmark", action: #selector(handleConfirm))

        // Stack view for left-aligned buttons
        let leftStackView = UIStackView(arrangedSubviews: [expandButton, rotateButton])
        leftStackView.axis = .horizontal
        leftStackView.distribution = .equalSpacing
        leftStackView.spacing = 20 // Adjust the spacing between buttons

        // Layout buttons, for simplicity we're adding them directly to the view
        leftStackView.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(leftStackView)
        view.addSubview(confirmButton)

        // Constraints (adjust as needed)
        NSLayoutConstraint.activate([
            leftStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            leftStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            confirmButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    /// Helper function to create a styled icon button.
    private func createIconButton(systemName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName)?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = .white // Set icon color to white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6) // Black background with opacity
        button.layer.cornerRadius = 22 // Half of width and height to make it circular
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44), // Set width
            button.heightAnchor.constraint(equalToConstant: 44) // Set height
        ])
        return button
    }



    @objc private func handleExpand() {
        guard let layer = playerLayer else { return }

        // Calculate the maximum scale factor that allows the video to fill the view, considering current rotation
        let videoBounds = layer.bounds.applying(layer.affineTransform())
        let scaleX = view.bounds.width / videoBounds.width
        let scaleY = view.bounds.height / videoBounds.height
        let maxScale = min(scaleX, scaleY)

        // Apply scale transformation on top of existing transformations, without resetting them
        var currentTransform = layer.affineTransform()
        currentTransform = currentTransform.scaledBy(x: maxScale, y: maxScale)
        UIView.animate(withDuration: 0.25) {
            layer.setAffineTransform(currentTransform)
        }
    }
 
    @objc private func handleRotate() {
        guard let layer = playerLayer else { return }

        // Increment the cumulative rotation by 90 degrees
        cumulativeRotation = fmod(cumulativeRotation + CGFloat.pi / 2, 2 * CGFloat.pi)

        // Reset the transform to calculate scale factors for the current video size
        let originalTransform = layer.affineTransform()
        layer.setAffineTransform(.identity)
        let originalSize = CGSize(width: layer.bounds.width, height: layer.bounds.height)
        layer.setAffineTransform(originalTransform)

        // Calculate new size considering the rotation
        let newSize: CGSize
        if Int(cumulativeRotation * 2 / CGFloat.pi) % 2 == 0 {
            newSize = originalSize
        } else {
            newSize = CGSize(width: originalSize.height, height: originalSize.width)
        }

        // Calculate scale factors to fit the new size within the view bounds
        let scaleToFit = min(view.bounds.width / newSize.width, view.bounds.height / newSize.height)

        // Apply the rotation transform with scaling
        let rotationTransform = CGAffineTransform(rotationAngle: cumulativeRotation)
        let transform = rotationTransform.scaledBy(x: scaleToFit, y: scaleToFit)

        UIView.animate(withDuration: 0.25) {
            layer.setAffineTransform(transform)
        }
    }



    private func setupVideoPlayer() {
        guard let videoURL = videoURL else { return }
        player = AVPlayer(url: videoURL)
        playerLayer = AVPlayerLayer(player: player)
        // Set the playerLayer's frame to match the parent view's bounds
        playerLayer?.frame = self.view.bounds

        
        // Set videoGravity to .resizeAspectFill to cover the full area
        playerLayer?.videoGravity = .resizeAspectFill

        guard let playerLayer = playerLayer else { return }
        self.view.layer.insertSublayer(playerLayer, at: 0) // Ensure it's the bottommost layer

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


    }


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

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let layer = playerLayer else { return }

        let pinchCenter = recognizer.location(in: view)
        let pinchCenterLayer = layer.convert(pinchCenter, from: layer.superlayer)

        if recognizer.state == .began {
            adjustAnchorPointForGestureRecognizer(recognizer)
        } else if recognizer.state == .changed {
            let scale = recognizer.scale
            // Combine the scales
            let combinedScale = cumulativeScale * scale
            
            // Enforce min/max scale limits
            let minScale: CGFloat = 1.0 // Example minimum scale
            let maxScale: CGFloat = 7.0 // Example maximum scale
            let finalScale = min(max(combinedScale, minScale), maxScale)
            
            if finalScale != cumulativeScale {
                let scaleAdjustment = finalScale / cumulativeScale
                let transform = layer.affineTransform().scaledBy(x: scaleAdjustment, y: scaleAdjustment)
                layer.setAffineTransform(transform)
                cumulativeScale = finalScale
            }
            recognizer.scale = 1 // Reset the scale for the next change
        }
        // No immediate reset on .ended or .cancelled to maintain focus
    }

    private func adjustAnchorPointForGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if let view = gestureRecognizer.view, let layer = playerLayer {
            let locationInView = gestureRecognizer.location(in: view)
            // Use the view's layer to convert the view location to the layer's coordinate system
            let locationInLayer = layer.convert(locationInView, from: view.layer)

            // Calculate new anchor point based on the location in the layer
            let anchorPointX = locationInLayer.x / layer.bounds.width
            let anchorPointY = locationInLayer.y / layer.bounds.height

            // Adjust anchor point without moving the layer
            let oldPosition = layer.position
            let newPosition = CGPoint(
                x: oldPosition.x + (anchorPointX - layer.anchorPoint.x) * layer.bounds.width,
                y: oldPosition.y + (anchorPointY - layer.anchorPoint.y) * layer.bounds.height
            )

            layer.anchorPoint = CGPoint(x: anchorPointX, y: anchorPointY)
            layer.position = newPosition
        }
    }
    
    // In the handleConfirm method, use cumulativeScale and cumulativeRotation for the final edit parameters
    @objc private func handleConfirm() {
        // Prepare the edit parameters based on cumulative changes
        let editParameters = VideoEditParameters(rotationAngle: cumulativeRotation, scale: cumulativeScale)
        // Additional parameters like scale can be added to VideoEditParameters if needed
        
        DispatchQueue.main.async {
            self.onConfirmEditing?(editParameters)
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    // Assume additional UI elements and functionalities are implemented here...
}
