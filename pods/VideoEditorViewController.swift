
//import Foundation
//
//import UIKit
//import AVFoundation
//
//struct VideoEditParameters: Equatable {
//    var rotationAngle: CGFloat = 0.0
//    var scale: CGFloat?
//    // Add other parameters like cropRect if needed
//}
//
//class VideoEditorViewController: UIViewController {
//    var videoURL: URL?
//    private var player: AVPlayer?
//    private var playerLayer: AVPlayerLayer?
//    
//    // Properties to track cumulative adjustments
//    private var cumulativeRotation: CGFloat = 0.0
//    private var cumulativeScale: CGFloat = 1.0
//    
//    // Add a delegate or closure to pass the edited video back
//    // Update the delegate or closure type to pass edit parameters instead of URL
//    var onConfirmEditing: ((VideoEditParameters) -> Void)?
//    
//    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        playerLayer?.frame = self.view.bounds
//        print("View bounds: \(self.view.bounds)") // Debugging frame sizes
//        print("Player layer frame: \(playerLayer?.frame ?? CGRect.zero)") // Debugging frame sizes
//    }
//
//
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = .black // Ensure the background is black for better visibility
//        setupVideoPlayer()
//        setupGestureRecognizers()
//        setupUIControls()
//        
//        if #available(iOS 11.0, *) {
//             self.view.insetsLayoutMarginsFromSafeArea = false
//         }
//
//    }
// 
//
//    
//    private func setupUIControls() {
//        // Create and style the expand button
//        let expandButton = createIconButton(systemName: "arrow.up.left.and.arrow.down.right", action: #selector(handleExpand))
//
//        // Create and style the rotate button
//        let rotateButton = createIconButton(systemName: "arrow.clockwise", action: #selector(handleRotate))
//
//        // Create and style the confirm button
//        let confirmButton = createIconButton(systemName: "checkmark", action: #selector(handleConfirm))
//
//        // Stack view for left-aligned buttons
//        let leftStackView = UIStackView(arrangedSubviews: [expandButton, rotateButton])
//        leftStackView.axis = .horizontal
//        leftStackView.distribution = .equalSpacing
//        leftStackView.spacing = 20 // Adjust the spacing between buttons
//
//        // Layout buttons, for simplicity we're adding them directly to the view
//        leftStackView.translatesAutoresizingMaskIntoConstraints = false
//        confirmButton.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(leftStackView)
//        view.addSubview(confirmButton)
//
//        // Constraints (adjust as needed)
//        NSLayoutConstraint.activate([
//            leftStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
//            leftStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
//
//            confirmButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
//            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
//        ])
//    }
//
//    /// Helper function to create a styled icon button.
//    private func createIconButton(systemName: String, action: Selector) -> UIButton {
//        let button = UIButton(type: .system)
//        button.setImage(UIImage(systemName: systemName)?.withRenderingMode(.alwaysTemplate), for: .normal)
//        button.tintColor = .white // Set icon color to white
//        button.backgroundColor = UIColor.black.withAlphaComponent(0.6) // Black background with opacity
//        button.layer.cornerRadius = 22 // Half of width and height to make it circular
//        button.addTarget(self, action: action, for: .touchUpInside)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            button.widthAnchor.constraint(equalToConstant: 44), // Set width
//            button.heightAnchor.constraint(equalToConstant: 44) // Set height
//        ])
//        return button
//    }
//
//
//
//    @objc private func handleExpand() {
//        guard let layer = playerLayer else { return }
//
//        // Calculate the maximum scale factor that allows the video to fill the view, considering current rotation
//        let videoBounds = layer.bounds.applying(layer.affineTransform())
//        let scaleX = view.bounds.width / videoBounds.width
//        let scaleY = view.bounds.height / videoBounds.height
//        let maxScale = min(scaleX, scaleY)
//
//        // Apply scale transformation on top of existing transformations, without resetting them
//        var currentTransform = layer.affineTransform()
//        currentTransform = currentTransform.scaledBy(x: maxScale, y: maxScale)
//        UIView.animate(withDuration: 0.25) {
//            layer.setAffineTransform(currentTransform)
//        }
//    }
// 
//    @objc private func handleRotate() {
//        guard let layer = playerLayer else { return }
//
//        // Increment the cumulative rotation by 90 degrees
//        cumulativeRotation = fmod(cumulativeRotation + CGFloat.pi / 2, 2 * CGFloat.pi)
//
//        // Reset the transform to calculate scale factors for the current video size
//        let originalTransform = layer.affineTransform()
//        layer.setAffineTransform(.identity)
//        let originalSize = CGSize(width: layer.bounds.width, height: layer.bounds.height)
//        layer.setAffineTransform(originalTransform)
//
//        // Calculate new size considering the rotation
//        let newSize: CGSize
//        if Int(cumulativeRotation * 2 / CGFloat.pi) % 2 == 0 {
//            newSize = originalSize
//        } else {
//            newSize = CGSize(width: originalSize.height, height: originalSize.width)
//        }
//
//        // Calculate scale factors to fit the new size within the view bounds
//        let scaleToFit = min(view.bounds.width / newSize.width, view.bounds.height / newSize.height)
//
//        // Apply the rotation transform with scaling
//        let rotationTransform = CGAffineTransform(rotationAngle: cumulativeRotation)
//        let transform = rotationTransform.scaledBy(x: scaleToFit, y: scaleToFit)
//
//        UIView.animate(withDuration: 0.25) {
//            layer.setAffineTransform(transform)
//        }
//    }
//
//
//
//    private func setupVideoPlayer() {
//        guard let videoURL = videoURL else { return }
//        player = AVPlayer(url: videoURL)
//        playerLayer = AVPlayerLayer(player: player)
//        // Set the playerLayer's frame to match the parent view's bounds
//        playerLayer?.frame = self.view.bounds
//
//        
//        // Set videoGravity to .resizeAspectFill to cover the full area
//        playerLayer?.videoGravity = .resizeAspectFill
//
//        guard let playerLayer = playerLayer else { return }
//        self.view.layer.insertSublayer(playerLayer, at: 0) // Ensure it's the bottommost layer
//
//        player?.play()
//        player?.actionAtItemEnd = .none // Loop the video
//
//        NotificationCenter.default.addObserver(self,
//                                               selector: #selector(playerItemDidReachEnd(notification:)),
//                                               name: .AVPlayerItemDidPlayToEndTime,
//                                               object: player?.currentItem)
//    }
//
//
//    @objc func playerItemDidReachEnd(notification: Notification) {
//        player?.seek(to: CMTime.zero)
//        player?.play()
//    }
//
//
//    private func setupGestureRecognizers() {
//        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
//        view.addGestureRecognizer(pinchRecognizer)
//
//
//    }
//
//
//    private func calculateFitScaleForVideo() -> CGFloat {
//        guard let layer = playerLayer else { return 1.0 }
//        let videoAspect = layer.bounds.width / layer.bounds.height
//        let viewAspect = view.bounds.width / view.bounds.height
//        if videoAspect > viewAspect {
//            // Video is wider than view
//            return view.bounds.height / layer.bounds.height
//        } else {
//            // Video is narrower than view
//            return view.bounds.width / layer.bounds.width
//        }
//    }
//
//
//    
//    private func extendViewToCoverEntireScreen() {
//        if #available(iOS 11.0, *) {
//            // Extend the view's edges to the screen's edges, ignoring the safe area.
//            view.insetsLayoutMarginsFromSafeArea = false
//            view.translatesAutoresizingMaskIntoConstraints = true
//            view.frame = UIScreen.main.bounds
//        }
//    }
//
//    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
//        guard let layer = playerLayer else { return }
//
//        let pinchCenter = recognizer.location(in: view)
//        let pinchCenterLayer = layer.convert(pinchCenter, from: layer.superlayer)
//
//        if recognizer.state == .began {
//            adjustAnchorPointForGestureRecognizer(recognizer)
//        } else if recognizer.state == .changed {
//            let scale = recognizer.scale
//            // Combine the scales
//            let combinedScale = cumulativeScale * scale
//            
//            // Enforce min/max scale limits
//            let minScale: CGFloat = 1.0 // Example minimum scale
//            let maxScale: CGFloat = 7.0 // Example maximum scale
//            let finalScale = min(max(combinedScale, minScale), maxScale)
//            
//            if finalScale != cumulativeScale {
//                let scaleAdjustment = finalScale / cumulativeScale
//                let transform = layer.affineTransform().scaledBy(x: scaleAdjustment, y: scaleAdjustment)
//                layer.setAffineTransform(transform)
//                cumulativeScale = finalScale
//            }
//            recognizer.scale = 1 // Reset the scale for the next change
//        }
//        // No immediate reset on .ended or .cancelled to maintain focus
//    }
//
//    private func adjustAnchorPointForGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
//        if let view = gestureRecognizer.view, let layer = playerLayer {
//            let locationInView = gestureRecognizer.location(in: view)
//            // Use the view's layer to convert the view location to the layer's coordinate system
//            let locationInLayer = layer.convert(locationInView, from: view.layer)
//
//            // Calculate new anchor point based on the location in the layer
//            let anchorPointX = locationInLayer.x / layer.bounds.width
//            let anchorPointY = locationInLayer.y / layer.bounds.height
//
//            // Adjust anchor point without moving the layer
//            let oldPosition = layer.position
//            let newPosition = CGPoint(
//                x: oldPosition.x + (anchorPointX - layer.anchorPoint.x) * layer.bounds.width,
//                y: oldPosition.y + (anchorPointY - layer.anchorPoint.y) * layer.bounds.height
//            )
//
//            layer.anchorPoint = CGPoint(x: anchorPointX, y: anchorPointY)
//            layer.position = newPosition
//        }
//    }
//    
//    // In the handleConfirm method, use cumulativeScale and cumulativeRotation for the final edit parameters
//    @objc private func handleConfirm() {
//        // Prepare the edit parameters based on cumulative changes
//        let editParameters = VideoEditParameters(rotationAngle: cumulativeRotation, scale: cumulativeScale)
//        // Additional parameters like scale can be added to VideoEditParameters if needed
//        
//        DispatchQueue.main.async {
//            self.onConfirmEditing?(editParameters)
//            self.dismiss(animated: true, completion: nil)
//        }
//    }
//    
//    // Assume additional UI elements and functionalities are implemented here...
//}


import UIKit
import AVFoundation
import AVKit

struct VideoEditParameters: Equatable {
    var rotationAngle: CGFloat = 0.0
    var scale: CGFloat?
    // Add other parameters like cropRect if needed
}

class VideoEditorViewController: UIViewController {
    var videoURL: URL?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    var onConfirmEditing: ((VideoEditParameters) -> Void)?
        private var cumulativeRotation: CGFloat = 0.0
        private var cumulativeScale: CGFloat = 1.0
    private var controlsContainer = UIView()


    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 20.0/255.0, green: 20.0/255.0, blue: 20.0/255.0, alpha: 1.0)
        
        setupControlsContainer()
        setupPlayer()
       
        
    }
    
    private func setupPlayer() {
        guard let videoURL = videoURL else { return }
        player = AVPlayer(url: videoURL)
        playerLayer = AVPlayerLayer(player: player)
        
        let controlsHeight: CGFloat = 300 // Height of the controls container
        playerLayer?.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - controlsHeight)
        playerLayer?.videoGravity = .resizeAspect
        
        if let playerLayer = playerLayer {
            view.layer.insertSublayer(playerLayer, at: 0) // Insert player layer at the very bottom
        }
        
        player?.play()
    }
    
    
    private func setupControlsContainer() {
        // Removed the local declaration here
        controlsContainer.backgroundColor = UIColor(red: 20.0/255.0, green: 20.0/255.0, blue: 20.0/255.0, alpha: 1.0)

        view.addSubview(controlsContainer)
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlsContainer.heightAnchor.constraint(equalToConstant: 100),
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        setupAspectRatioSelector()
        setupActionButtons()
    }
    

    private func createCustomButton(title: String, imageSystemName: String, action: Selector) -> UIView {
        let buttonIcon = UIImageView(image: UIImage(systemName: imageSystemName))
        buttonIcon.contentMode = .scaleAspectFit // Ensure the icon maintains its aspect ratio
        buttonIcon.tintColor = .white

        let buttonLabel = UILabel()
        buttonLabel.text = title
        buttonLabel.font = UIFont.systemFont(ofSize: 10) // Adjust font size as needed
        buttonLabel.textColor = .white
        buttonLabel.textAlignment = .center

        let buttonView = UIView()
        buttonView.addSubview(buttonIcon)
        buttonView.addSubview(buttonLabel)

        // Setup constraints for buttonIcon and buttonLabel within buttonView
        buttonIcon.translatesAutoresizingMaskIntoConstraints = false
        buttonLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            buttonIcon.centerXAnchor.constraint(equalTo: buttonView.centerXAnchor),
            buttonIcon.topAnchor.constraint(equalTo: buttonView.topAnchor),
            buttonIcon.widthAnchor.constraint(equalTo: buttonView.widthAnchor, multiplier: 0.6), // Adjust multiplier as needed to control the size of the icon
            buttonIcon.heightAnchor.constraint(equalTo: buttonIcon.widthAnchor), // Keep the icon square

            buttonLabel.topAnchor.constraint(equalTo: buttonIcon.bottomAnchor, constant: 5),
            buttonLabel.leadingAnchor.constraint(equalTo: buttonView.leadingAnchor),
            buttonLabel.trailingAnchor.constraint(equalTo: buttonView.trailingAnchor),
            buttonLabel.bottomAnchor.constraint(equalTo: buttonView.bottomAnchor)
        ])

        // Add tap gesture recognizer to handle taps on the buttonView
        let tapRecognizer = UITapGestureRecognizer(target: self, action: action)
        buttonView.addGestureRecognizer(tapRecognizer)

        return buttonView
    }


    
    private func setupAspectRatioSelector() {
        let aspectRatios: [(title: String, imageSystemName: String)] = [
                   ("Freeform", "square.arrowtriangle.4.outward"),
                   ("9:16", "rectangle.ratio.9.to.16"),
                   ("16:9", "rectangle.ratio.16.to.9"),
                   ("1:1", "square"),
                   ("3:4", "rectangle.ratio.3.to.4"),
                   ("4:3", "rectangle.ratio.4.to.3")
               ]
            
            let selectorStackView = UIStackView()
            selectorStackView.axis = .horizontal
            selectorStackView.distribution = .fillEqually
            selectorStackView.spacing = 10 // Adjust as needed

        for aspectRatio in aspectRatios {
                   let customButtonView = createCustomButton(title: aspectRatio.title, imageSystemName: aspectRatio.imageSystemName, action: #selector(handleAspectRatioSelection(_:)))
                   selectorStackView.addArrangedSubview(customButtonView)
               }

            selectorStackView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(selectorStackView)
            
            // NSLayoutConstraint activations
        
      
        NSLayoutConstraint.activate([
            selectorStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            selectorStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            selectorStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            selectorStackView.heightAnchor.constraint(equalToConstant: 70)
        ])
        }
    
    @objc private func handleAspectRatioSelection(_ recognizer: UITapGestureRecognizer) {
           if let view = recognizer.view, let stackView = view as? UIStackView, let label = stackView.arrangedSubviews.last as? UILabel {
               print("Selected aspect ratio: \(label.text ?? "")")
               // Here, you can adjust the playerLayer's frame or the cropping area based on the selected aspect ratio
           }
       }
    
//    private func setupActionButtons() {
//        // Create buttons with specific font styles and sizes
//        let cancelButton = createButton(title: "Cancel", font: UIFont.systemFont(ofSize: 17), action: #selector(cancelAction))
//        let cropButton = createButton(title: "Crop", font: UIFont.boldSystemFont(ofSize: 17), action: #selector(cropAction))
//        let saveButton = createButton(title: "Save", font: UIFont.systemFont(ofSize: 17, weight: .medium), action: #selector(saveAction))
//        
//        let stackView = UIStackView(arrangedSubviews: [cancelButton, cropButton, saveButton])
//        stackView.axis = .horizontal
//        stackView.distribution = .fillEqually
//        stackView.translatesAutoresizingMaskIntoConstraints = false
//        controlsContainer.addSubview(stackView)
//        
//        NSLayoutConstraint.activate([
//            stackView.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: -25), // Adjust constant for edge padding
//            stackView.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: 25), // Adjust constant for edge padding
//            stackView.topAnchor.constraint(equalTo: controlsContainer.topAnchor),
//            stackView.heightAnchor.constraint(equalToConstant: 150) // Adjust as needed
//        ])
//    }
    private func setupActionButtons() {
        let cancelButton = createButton(title: "Cancel", font: UIFont.systemFont(ofSize: 16), action: #selector(cancelAction))
        let saveButton = createButton(title: "Save", font: UIFont.systemFont(ofSize: 16, weight: .medium), action: #selector(saveAction))

        // Create a UILabel for "Crop" instead of a UIButton
        let cropLabel = UILabel()
        cropLabel.text = "Crop"
        cropLabel.font = UIFont.boldSystemFont(ofSize: 18)
        cropLabel.textColor = .white
        cropLabel.textAlignment = .center
        cropLabel.isUserInteractionEnabled = true // To respond to taps
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cropAction))
        cropLabel.addGestureRecognizer(tapGesture)

        let stackView = UIStackView(arrangedSubviews: [cancelButton, cropLabel, saveButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: -35), // Adjust constant for edge padding
            stackView.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: 35), // Adjust constant for edge padding
            stackView.topAnchor.constraint(equalTo: controlsContainer.topAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 150) // Adjust as needed
        ])
    }

    private func createButton(title: String, font: UIFont, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = font
        button.addTarget(self, action: action, for: .touchUpInside)
        button.tintColor = .white
        // Adjust contentEdgeInsets if needed to position "Cancel" and "Save" closer to edges
        return button
    }

    
 



    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.tintColor = .white
        return button
    }

    @objc private func cancelAction() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func cropAction() {
        // Placeholder for crop functionality
    }
    
    @objc private func saveAction() {
        // Assuming you have code here to determine the final rotation angle and scale
        let parameters = VideoEditParameters(rotationAngle: cumulativeRotation, scale: cumulativeScale)
        // Call the onConfirmEditing closure to notify about the completion
        onConfirmEditing?(parameters)
    }


    // Implement crop area setup and adjustment based on selected aspect ratio
    // Implement functionality for adjusting the playerLayer frame to match the selected aspect ratio
}


