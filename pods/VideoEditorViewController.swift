

import UIKit
import AVFoundation
import AVKit

struct VideoEditParameters: Equatable {
    var rotationAngle: CGFloat = 0.0
    var scale: CGFloat?
    var cropRect: CGRect?
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
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Set default selection to Freeform
        if let freeformButton = self.view.viewWithTag(1) { // Ensure it's the correct type
            self.handleAspectRatioSelection(freeformButton)
        }
    }
    

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
                setupPlayerFrame()
            addCornerHandlesToCroppingArea()
            croppingAreaView?.frame = playerLayer?.frame ?? .zero
        addGridLinesToCroppingArea()

            }

    @objc private func handleAspectRatioSelection(_ sender: Any) {
        // Determine whether the sender is a view or a gesture recognizer
        let selectedView: UIView?
        if let recognizer = sender as? UITapGestureRecognizer {
            // Sender is a gesture recognizer; use its view
            selectedView = recognizer.view
        } else if let view = sender as? UIView {
            // Sender is directly a view
            selectedView = view
        } else {
            // Unrecognized sender; abort
            return
        }
        
        guard let viewToSelect = selectedView else { return }
        
        // Reset previously selected button's icon and label color
        if let previousSelectedButton = selectedAspectRatioButton {
            let iconView = previousSelectedButton.subviews.compactMap { $0 as? UIImageView }.first
            let labelView = previousSelectedButton.subviews.compactMap { $0 as? UILabel }.first
            iconView?.tintColor = .white // Reset icon color
            labelView?.textColor = .white // Reset label color
        }
        
        // Highlight the newly selected button's icon and label
        let iconView = viewToSelect.subviews.compactMap { $0 as? UIImageView }.first
        let labelView = viewToSelect.subviews.compactMap { $0 as? UILabel }.first
        iconView?.tintColor = UIColor(red: 70/255, green: 87/255, blue: 245/255, alpha: 1) // Selected icon color
        labelView?.textColor = UIColor(red: 70/255, green: 87/255, blue: 245/255, alpha: 1) // Selected label color
        
        selectedAspectRatioButton = viewToSelect // Update the reference to the newly selected button
        
        // Adjust cropping area and player layer according to the selected aspect ratio
        if let aspectRatioTag = viewToSelect.tag as? Int {
           
                adjustCroppingAreaAndPlayer(for: aspectRatioTag)
         
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(loopVideo), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)

        // Add Pinch Gesture Recognizer to the topContainer
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        topContainer.addGestureRecognizer(pinchGesture)
    }
    
    @objc func loopVideo() {
        player?.seek(to: CMTime.zero)
        player?.play()
    }

    deinit {
        // Don't forget to remove the observer
        NotificationCenter.default.removeObserver(self)
    }

//
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let playerLayer = self.playerLayer, let croppingAreaView = self.croppingAreaView else { return }

        if gesture.state == .began {
            let locationInView = gesture.location(in: gesture.view)
            // Assuming gesture.view is the view that contains playerLayer, like your topContainer
            let locationInPlayerLayer = playerLayer.superlayer!.convert(locationInView, to: playerLayer)

            // Convert pinch location to a normalized anchor point for the playerLayer
            let anchorPointX = locationInPlayerLayer.x / playerLayer.bounds.width
            let anchorPointY = locationInPlayerLayer.y / playerLayer.bounds.height

            // Adjust playerLayer's anchorPoint without moving it
            updateAnchorPointWithoutMoving(playerLayer, toPoint: CGPoint(x: anchorPointX, y: anchorPointY))
        }

        if gesture.state == .began || gesture.state == .changed {
            let pinchScale = gesture.scale
            let currentAffineTransform = playerLayer.affineTransform()
            let currentScale = sqrt(currentAffineTransform.a * currentAffineTransform.d) // Extracting scale from CGAffineTransform

            // Calculating the bounds of the cropping area in terms of the initial video size
            let minScaleWidth = croppingAreaView.bounds.width / playerLayer.bounds.width
            let minScaleHeight = croppingAreaView.bounds.height / playerLayer.bounds.height
            let minScale = max(minScaleWidth, minScaleHeight)

            // Applying the pinch scale to the current scale
            var newScale = currentScale * pinchScale
            newScale = max(newScale, minScale) // Ensuring not smaller than the cropping area
            newScale = min(newScale, 4.0) // Maximum allowed zoom

            // Apply scaling transform with respect to the current scale
            let scaleAdjustment = newScale / currentScale
            playerLayer.setAffineTransform(currentAffineTransform.scaledBy(x: scaleAdjustment, y: scaleAdjustment))

            gesture.scale = 1.0 // Resetting the gesture scale for the next pinch event
        }
    }
    


    func updateAnchorPointWithoutMoving(_ layer: CALayer, toPoint newAnchorPoint: CGPoint) {
        let oldOrigin = layer.frame.origin
        layer.anchorPoint = newAnchorPoint
        let newOrigin = layer.frame.origin

        let transition = CGPoint(x: newOrigin.x - oldOrigin.x, y: newOrigin.y - oldOrigin.y)
        layer.position = CGPoint(x: layer.position.x - transition.x, y: layer.position.y - transition.y)
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

    private func createCornerView() -> UIView {
        let corner = UIView()
        corner.backgroundColor = .white
        corner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        corner.layer.cornerRadius = 10 // Optional, for rounded corners
        return corner
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
//    @objc private func saveAction() {
//        // Assuming cropRect needs to be calculated based on the user's final cropping area
//        let cropRect = calculateCropRect()
//
//        // Update parameters with the latest scale and cropRect
//        let parameters = VideoEditParameters(rotationAngle: cumulativeRotation, scale: cumulativeScale, cropRect: cropRect)
//        
//        // Call onConfirmEditing with updated parameters
//        onConfirmEditing?(parameters)
//        
//        // Dismiss the editor
//        dismiss(animated: true, completion: nil)
//    }
    @objc private func saveAction() {
        
        guard let playerLayer = self.playerLayer else {
               print("Player layer is nil")
               return
           }
        // Extract scale from the current playerLayer's affineTransform
        let affineTransform = playerLayer.affineTransform()
        let scaleX = sqrt(affineTransform.a * affineTransform.d) // Extracting scale from CGAffineTransform
        
        let cropRect = calculateCropRect()
        let parameters = VideoEditParameters(rotationAngle: cumulativeRotation, scale: scaleX, cropRect: cropRect)
        
        onConfirmEditing?(parameters)
        
        dismiss(animated: true, completion: nil)
    }


    private func calculateCropRect() -> CGRect {
        guard let playerItem = player?.currentItem,
              let videoTrack = playerItem.asset.tracks(withMediaType: .video).first,
              let playerLayer = self.playerLayer, // Safely unwrapped playerLayer
              let superView = croppingAreaView?.superview else {
            print("Failed to get video track or playerLayer is not available")
            return .zero
        }

        // Use preferredTransform to consider video orientation.
        let videoSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let absoluteVideoSize = CGSize(width: abs(videoSize.width), height: abs(videoSize.height))

        guard let croppingAreaView = croppingAreaView else {
            print("Cropping area view is not set")
            return .zero
        }

        // Convert the cropping area's frame to match the video's dimensions, relative to the playerLayer's superlayer or containing view
        let cropFrameInView = superView.convert(croppingAreaView.frame, to: topContainer)

        // Calculate the effective video frame within the playerLayer's bounds
        let playerLayerFrame = playerLayer.videoRect

        // Convert cropFrameInView's origin to the video's coordinate system
        let cropOriginX = (cropFrameInView.origin.x - playerLayerFrame.origin.x) / playerLayerFrame.width
        let cropOriginY = (cropFrameInView.origin.y - playerLayerFrame.origin.y) / playerLayerFrame.height
        let cropWidth = cropFrameInView.width / playerLayerFrame.width
        let cropHeight = cropFrameInView.height / playerLayerFrame.height

        // The resulting cropRect is normalized to [0,1] range for both axes
        return CGRect(x: cropOriginX, y: cropOriginY, width: cropWidth, height: cropHeight)
    }



}
