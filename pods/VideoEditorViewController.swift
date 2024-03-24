

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
    private var croppingAreaView: UIView?
    private var topContainer = UIView()
    var selectedAspectRatioButton: UIView?



  



    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 20.0/255.0, green: 20.0/255.0, blue: 20.0/255.0, alpha: 1.0)
        
        setupControlsContainer()
        setupTopContainer()
        setupPlayer()
        setupCroppingArea()
        
        
        // Ensure controlsContainer stays on top
           view.bringSubviewToFront(controlsContainer)
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupPlayerFrame()
        croppingAreaView?.frame = playerLayer?.frame ?? .zero
        addGridLinesToCroppingArea()
        addCornerHandlesToCroppingArea()
    }
    

    @objc private func handleAspectRatioSelection(_ recognizer: UITapGestureRecognizer) {
        if let selectedView = recognizer.view {
            // Reset previously selected button's icon and label color
            if let previousSelectedButton = selectedAspectRatioButton {
                let iconView = previousSelectedButton.subviews.compactMap { $0 as? UIImageView }.first
                let labelView = previousSelectedButton.subviews.compactMap { $0 as? UILabel }.first
                iconView?.tintColor = .white // Reset icon color
                labelView?.textColor = .white // Reset label color
            }
            
            // Highlight the newly selected button's icon and label
            let iconView = selectedView.subviews.compactMap { $0 as? UIImageView }.first
            let labelView = selectedView.subviews.compactMap { $0 as? UILabel }.first
            iconView?.tintColor = UIColor(red: 70/255, green: 87/255, blue: 245/255, alpha: 1) // Selected icon color
            labelView?.textColor = UIColor(red: 70/255, green: 87/255, blue: 245/255, alpha: 1) // Selected label color
            
            selectedAspectRatioButton = selectedView // Update the reference to the newly selected button
            
            // Adjust cropping area and player layer according to the selected aspect ratio
            if let aspectRatioTag = selectedView.tag as? Int {
                adjustCroppingAreaAndPlayer(for: aspectRatioTag)
            }
        }
    }

    

    private func aspectRatio(forTag tag: Int) -> CGFloat {
        switch tag {
        case 1: // Tag for "Freeform" might just maintain the video's original aspect ratio
            return calculateVideoAspectRatio() ?? 16/9 // Default to 16:9 if calculation fails
        case 2: // Tag for "9:16"
            return 9/16
        case 3: // Tag for "16:9"
            return 16/9
        case 4: // Tag for "1:1"
            return 1/1
        case 5: // Tag for "3:4"
            return 3/4
        case 6: // Tag for "4:3"
            return 4/3
        default:
            return 16/9 // Default aspect ratio
        }
    }


    private func addOverlayOutsideCroppingArea() {
        // Remove existing overlays
        topContainer.subviews.forEach { view in
            if view.tag == 998 { // Assuming 998 is the unique tag for overlay views
                view.removeFromSuperview()
            }
        }

        let overlayColor = UIColor(red: 27/255, green: 27/255, blue: 27/255, alpha: 0.4)
        // Assuming croppingAreaView is properly positioned and sized
        guard let croppingFrame = croppingAreaView?.frame else { return }
        
        // Create and position overlay views
        let positions = [
            CGRect(x: 0, y: 0, width: topContainer.bounds.width, height: croppingFrame.minY), // Top
            CGRect(x: 0, y: croppingFrame.maxY, width: topContainer.bounds.width, height: topContainer.bounds.height - croppingFrame.maxY), // Bottom
            CGRect(x: 0, y: croppingFrame.minY, width: croppingFrame.minX, height: croppingFrame.height), // Left
            CGRect(x: croppingFrame.maxX, y: croppingFrame.minY, width: topContainer.bounds.width - croppingFrame.maxX, height: croppingFrame.height) // Right
        ]
        
        positions.forEach { frame in
            let overlayView = UIView(frame: frame)
            overlayView.backgroundColor = overlayColor
            overlayView.tag = 998 // Tag for identification
            topContainer.addSubview(overlayView)
        }
    }



    private func setupPlayerFrame() {
        guard let videoAspectRatio = calculateVideoAspectRatio() else { return }
        
        // Assuming topContainer has been laid out here
        let containerSize = topContainer.bounds.size
        let containerAspectRatio = containerSize.width / containerSize.height
        
        var playerFrame: CGRect = .zero
        if videoAspectRatio > containerAspectRatio {
            // Video is wider than the container
            let height = containerSize.width / videoAspectRatio
            playerFrame = CGRect(x: 0, y: (containerSize.height - height) / 2, width: containerSize.width, height: height)
        } else {
            // Video is taller than the container
            let width = containerSize.height * videoAspectRatio
            playerFrame = CGRect(x: (containerSize.width - width) / 2, y: 0, width: width, height: containerSize.height)
        }
        
        playerLayer?.frame = playerFrame
    }

    
    private func setupTopContainer() {
        topContainer.backgroundColor = UIColor(red: 20.0/255.0, green: 20.0/255.0, blue: 20.0/255.0, alpha: 1.0)
        view.addSubview(topContainer)
        
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topContainer.bottomAnchor.constraint(equalTo: controlsContainer.topAnchor) // Align the bottom of the topContainer with the top of the controlsContainer
        ])
    }


//
//    private func setupPlayer() {
//        guard let videoURL = videoURL else { return }
//        player = AVPlayer(url: videoURL)
//        let playerView = UIView() // Hosting view for playerLayer
//        playerView.frame = topContainer.bounds // Make playerView's frame match topContainer
//        playerView.backgroundColor = .clear // Ensure the background is transparent
//        topContainer.addSubview(playerView) // Add playerView to topContainer
//        
//        playerLayer = AVPlayerLayer(player: player)
//        playerLayer?.frame = playerView.bounds // Make playerLayer's frame match playerView
//        playerLayer?.videoGravity = .resizeAspect
//        if let playerLayer = playerLayer {
//            playerView.layer.addSublayer(playerLayer) // Add playerLayer to playerView
//        }
//        
//        player?.play()
//
//        topContainer.sendSubviewToBack(playerView) // Send playerView (hosting playerLayer) to the back
//    }
    private func setupPlayer() {
        guard let videoURL = self.videoURL else { return }
        player = AVPlayer(url: videoURL)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = topContainer.bounds
        playerLayer?.videoGravity = .resizeAspect
        if let layer = playerLayer {
            topContainer.layer.addSublayer(layer)
        }
        player?.play()

        // Add Pinch Gesture Recognizer to the topContainer
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        topContainer.addGestureRecognizer(pinchGesture)
    }
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.view != nil else { return }

        if gesture.state == .began || gesture.state == .changed {
            let scale = gesture.scale
            // Safely unwrap playerLayer to apply the transform
            if let playerLayer = self.playerLayer {
                // Apply scaling only to the playerLayer's transform
                let currentScale = sqrt(playerLayer.affineTransform().a * playerLayer.affineTransform().d)
                // Limit the scale factor to a reasonable range, for example, 1x to 4x
                let newScale = min(max(currentScale * scale, 1), 4)
                playerLayer.setAffineTransform(CGAffineTransform(scaleX: newScale, y: newScale))
            }
            gesture.scale = 1.0
        }
    }


    private func setupControlsContainer() {
        controlsContainer.backgroundColor = UIColor(red: 27.0/255.0, green: 27.0/255.0, blue: 27.0/255.0, alpha: 1.0)
        view.addSubview(controlsContainer)

        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            // Adjust height constraint as needed including vertical padding
        ])
        
        // Create a vertical stack view to add to controlsContainer
        let controlsStackView = UIStackView()
        controlsStackView.axis = .vertical
        controlsStackView.alignment = .fill
        controlsStackView.distribution = .fill
        controlsStackView.spacing = 25 // Vertical spacing between elements

        // Add the aspect ratio selector and action buttons
        let aspectRatioSelectorView = setupAspectRatioSelector()
        let actionButtonsView = setupActionButtons()

        // Add a spacer view for pushing elements to top and bottom
        let spacerView = UIView()
        spacerView.setContentHuggingPriority(.defaultLow, for: .vertical)

        controlsStackView.addArrangedSubview(aspectRatioSelectorView)
        controlsStackView.addArrangedSubview(spacerView) // This acts like a spacer
        controlsStackView.addArrangedSubview(actionButtonsView)
        
        controlsContainer.addSubview(controlsStackView)
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false

        // Apply constraints including vertical padding
        NSLayoutConstraint.activate([
            controlsStackView.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 25), // Top padding
            controlsStackView.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            controlsStackView.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            controlsStackView.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -10), // Bottom padding
        ])
    }


    private func createCustomButton(title: String, imageSystemName: String, action: Selector) -> UIView {
        let buttonIcon = UIImageView(image: UIImage(systemName: imageSystemName))
        buttonIcon.contentMode = .scaleAspectFit // Ensure the icon maintains its aspect ratio
        buttonIcon.tintColor = .white

        let buttonLabel = UILabel()
        buttonLabel.text = title
        buttonLabel.font = UIFont.systemFont(ofSize: 12) // Adjust font size as needed
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
            buttonIcon.widthAnchor.constraint(equalTo: buttonView.widthAnchor, multiplier: 0.5), // Adjust multiplier as needed to control the size of the icon
            buttonIcon.heightAnchor.constraint(equalTo: buttonIcon.widthAnchor), // Keep the icon square

            buttonLabel.topAnchor.constraint(equalTo: buttonIcon.bottomAnchor, constant: 5),
            buttonLabel.leadingAnchor.constraint(equalTo: buttonView.leadingAnchor,  constant: 8),
            buttonLabel.trailingAnchor.constraint(equalTo: buttonView.trailingAnchor, constant: -8),
            buttonLabel.bottomAnchor.constraint(equalTo: buttonView.bottomAnchor)
        ])

        // Add tap gesture recognizer to handle taps on the buttonView
        let tapRecognizer = UITapGestureRecognizer(target: self, action: action)
        buttonView.addGestureRecognizer(tapRecognizer)

        return buttonView
    }


    private func setupAspectRatioSelector() -> UIView {
        let aspectRatios: [(title: String, imageSystemName: String, tag: Int)] = [
            ("Free", "square.arrowtriangle.4.outward", 1),
            ("9:16", "rectangle.ratio.9.to.16", 2),
            ("16:9", "rectangle.ratio.16.to.9", 3),
            ("1:1", "square", 4),
            ("3:4", "rectangle.ratio.3.to.4", 5),
            ("4:3", "rectangle.ratio.4.to.3", 6)
        ]
        
        let selectorStackView = UIStackView()
        selectorStackView.axis = .horizontal
        selectorStackView.distribution = .fillEqually
        selectorStackView.spacing = 10 // Consider adjusting the spacing to prevent buttons from being too close
        
        for (index, aspectRatio) in aspectRatios.enumerated() {
            let buttonView = createCustomButton(title: aspectRatio.title, imageSystemName: aspectRatio.imageSystemName, action: #selector(handleAspectRatioSelection(_:)))
            buttonView.tag = aspectRatio.tag // Assign unique tag
            selectorStackView.addArrangedSubview(buttonView)
        }

        return selectorStackView
    }

    
    
    
    private func setupActionButtons() -> UIView {
        let cancelButton = createButton(title: "Cancel", font: UIFont.systemFont(ofSize: 16), action: #selector(cancelAction))
        let saveButton = createButton(title: "Save", font: UIFont.systemFont(ofSize: 16, weight: .medium), action: #selector(saveAction))

        // Create a UILabel for "Crop" instead of a UIButton, if needed
        let cropLabel = UILabel()
        cropLabel.text = "Crop"
        cropLabel.font = UIFont.boldSystemFont(ofSize: 18)
        cropLabel.textColor = .white
        cropLabel.textAlignment = .center
        cropLabel.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cropAction))
        cropLabel.addGestureRecognizer(tapGesture)
        
        let actionButtonsStackView = UIStackView(arrangedSubviews: [cancelButton, cropLabel, saveButton])
        actionButtonsStackView.axis = .horizontal
        actionButtonsStackView.distribution = .fillEqually
        
        // Adjust stack view's layout margins to push buttons closer to the edges
            actionButtonsStackView.isLayoutMarginsRelativeArrangement = true
            actionButtonsStackView.layoutMargins = UIEdgeInsets(top: 0, left: -40, bottom: 0, right: -40)
        // Adjust spacing or add constraints if needed
        
        return actionButtonsStackView
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

    private func updatePlayerLayerFrame() {
        // Assuming controlsHeight is the height of your controls container
        let controlsHeight: CGFloat = 100 // Adjust based on your actual controls container height
        let availableHeight = view.bounds.height - controlsHeight - view.safeAreaInsets.top

        // Calculate width based on the aspect ratio of the video
        if let aspectRatio = calculateVideoAspectRatio() {
            let width = min(view.bounds.width, availableHeight * aspectRatio)
            let height = width / aspectRatio

            // Center the playerLayer within the available space
            playerLayer?.frame = CGRect(
                x: (view.bounds.width - width) / 2,
                y: (availableHeight - height) / 2 + view.safeAreaInsets.top,
                width: width,
                height: height
            )
        }
    }
    
    private func setupCroppingArea() {
        // Initialize the cropping area view
        let croppingArea = UIView()
        croppingArea.backgroundColor = .clear
        croppingArea.layer.borderWidth = 1.5
        croppingArea.layer.borderColor = UIColor.white.cgColor
        topContainer.addSubview(croppingArea)
        
        self.croppingAreaView = croppingArea
    }
    private func addCornerHandlesToCroppingArea() {
        guard let croppingArea = croppingAreaView else { return }
        
        let handleSideLength: CGFloat = 20.0 // The total length of the L shape from end to end
        let handleThickness: CGFloat = 4.0 // The thickness of the L shape

        // Clean up old handles
        croppingArea.subviews.forEach { subview in
            if subview.tag == 999 {
                subview.removeFromSuperview()
            }
        }

        // Positions for each corner handle
        let positions = [
            CGPoint(x: 0, y: 0), // Top-left
            CGPoint(x: croppingArea.bounds.width - handleSideLength, y: 0), // Top-right
            CGPoint(x: 0, y: croppingArea.bounds.height - handleSideLength), // Bottom-left
            CGPoint(x: croppingArea.bounds.width - handleSideLength, y: croppingArea.bounds.height - handleSideLength) // Bottom-right
        ]
        
        for (index, position) in positions.enumerated() {
            let handle = UIView()
            handle.backgroundColor = .clear
            handle.tag = 999
            croppingArea.addSubview(handle)
            handle.frame = CGRect(x: position.x, y: position.y, width: handleSideLength, height: handleSideLength)
            
            // Create the vertical and horizontal parts of the L shape
            let verticalPart = UIView()
            verticalPart.backgroundColor = .white
            handle.addSubview(verticalPart)
            
            let horizontalPart = UIView()
            horizontalPart.backgroundColor = .white
            handle.addSubview(horizontalPart)
            
            // Adjust the frames based on corner
            switch index {
            case 0: // Top-left
                verticalPart.frame = CGRect(x: 0, y: 0, width: handleThickness, height: handleSideLength)
                horizontalPart.frame = CGRect(x: 0, y: 0, width: handleSideLength, height: handleThickness)
            case 1: // Top-right
                verticalPart.frame = CGRect(x: handleSideLength - handleThickness, y: 0, width: handleThickness, height: handleSideLength)
                horizontalPart.frame = CGRect(x: 0, y: 0, width: handleSideLength, height: handleThickness)
            case 2: // Bottom-left
                verticalPart.frame = CGRect(x: 0, y: 0, width: handleThickness, height: handleSideLength)
                horizontalPart.frame = CGRect(x: 0, y: handleSideLength - handleThickness, width: handleSideLength, height: handleThickness)
            case 3: // Bottom-right
                verticalPart.frame = CGRect(x: handleSideLength - handleThickness, y: 0, width: handleThickness, height: handleSideLength)
                horizontalPart.frame = CGRect(x: 0, y: handleSideLength - handleThickness, width: handleSideLength, height: handleThickness)
            default:
                break
            }
        }
    }

    private func adjustCroppingAreaAndPlayer(for aspectRatioTag: Int) {
        guard let videoAspectRatio = calculateVideoAspectRatio() else { return }

        let containerSize = topContainer.bounds.size
        var newCroppingSize: CGSize
        var playerFrame: CGRect

        let selectedAspectRatio: CGFloat = aspectRatio(forTag: aspectRatioTag)

        // Default behavior for other aspect ratios
        if selectedAspectRatio > (containerSize.width / containerSize.height) {
            newCroppingSize = CGSize(width: containerSize.width, height: containerSize.width / selectedAspectRatio)
        } else {
            newCroppingSize = CGSize(width: containerSize.height * selectedAspectRatio, height: containerSize.height)
        }
        
        let croppingX = (containerSize.width - newCroppingSize.width) / 2
        let croppingY = (containerSize.height - newCroppingSize.height) / 2

        switch aspectRatioTag {
        case 2: // 9:16 Aspect Ratio
            // For 9:16, the player fits within the cropping area without extending
            playerFrame = CGRect(x: croppingX, y: croppingY, width: newCroppingSize.width, height: newCroppingSize.height)
            
        case 1: // Freeform (use video's original aspect ratio)
            // For Freeform, player size matches the video's original aspect ratio within container bounds
            playerFrame = CGRect(x: croppingX, y: croppingY, width: newCroppingSize.width, height: newCroppingSize.height)
            
        default: // Other aspect ratios
            // For other aspect ratios, the player fills the width of the container and adjusts height accordingly
            let playerHeight = containerSize.width / videoAspectRatio
            playerFrame = CGRect(x: 0, y: (containerSize.height - playerHeight) / 2, width: containerSize.width, height: playerHeight)
        }

        croppingAreaView?.frame = CGRect(x: croppingX, y: croppingY, width: newCroppingSize.width, height: newCroppingSize.height)
        playerLayer?.frame = playerFrame
        
        playerLayer?.masksToBounds = true
        addCornerHandlesToCroppingArea()
        addGridLinesToCroppingArea()
        addOverlayOutsideCroppingArea()
    }


    private func adjustCroppingArea(for aspectRatio: CGFloat, within containerSize: CGSize) {
        var croppingSize = CGSize(width: containerSize.width, height: containerSize.height)
        if aspectRatio > containerSize.width / containerSize.height {
            croppingSize.height = containerSize.width / aspectRatio
        } else {
            croppingSize.width = containerSize.height * aspectRatio
        }
        
        let newX = (containerSize.width - croppingSize.width) / 2
        let newY = (containerSize.height - croppingSize.height) / 2
        croppingAreaView?.frame = CGRect(x: newX, y: newY, width: croppingSize.width, height: croppingSize.height)
        
        // Re-apply grid lines and corner handles for the new cropping area size
        addCornerHandlesToCroppingArea()
        addGridLinesToCroppingArea()
    }



    private func addGridLinesToCroppingArea() {
        guard let croppingArea = croppingAreaView else { return }
        
        // Remove existing grid lines before adding new ones
        croppingArea.layer.sublayers?.forEach { layer in
            if layer is CAShapeLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        let gridLayer = CAShapeLayer()
        gridLayer.frame = croppingArea.bounds
        let path = UIBezierPath()
        
        // Calculate positions for two lines, dividing the area into three equal parts
        let width = croppingArea.bounds.width
        let height = croppingArea.bounds.height
        let thirdWidth = width / 3
        let thirdHeight = height / 3
        
        // Draw vertical lines
        for i in 1..<3 {
            path.move(to: CGPoint(x: CGFloat(i) * thirdWidth, y: 0))
            path.addLine(to: CGPoint(x: CGFloat(i) * thirdWidth, y: height))
        }
        
        // Draw horizontal lines
        for i in 1..<3 {
            path.move(to: CGPoint(x: 0, y: CGFloat(i) * thirdHeight))
            path.addLine(to: CGPoint(x: width, y: CGFloat(i) * thirdHeight))
        }
        
        gridLayer.path = path.cgPath
        gridLayer.strokeColor = UIColor.white.withAlphaComponent(0.4).cgColor
        gridLayer.lineWidth = 1.25
        gridLayer.fillColor = nil // No fill color for the grid
        croppingArea.layer.addSublayer(gridLayer)
    }


    func calculateVideoAspectRatio() -> CGFloat? {
        guard let videoURL = self.videoURL else { return nil }
        let asset = AVAsset(url: videoURL)
        guard let track = asset.tracks(withMediaType: .video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        let aspectRatio = abs(size.width / size.height)
        return aspectRatio
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
