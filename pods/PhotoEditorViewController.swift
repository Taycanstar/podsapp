

import UIKit
import AVFoundation
import AVKit



class PhotoEditorViewController: UIViewController {
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
    var editingImage: UIImage?
    private var imageView: UIImageView?
    var imageViewConstraints: [NSLayoutConstraint] = []



    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 20.0/255.0, green: 20.0/255.0, blue: 20.0/255.0, alpha: 1.0)
        
        setupControlsContainer()
        setupTopContainer()
        setupImageView()
        setupCroppingArea()
        // Ensure controlsContainer stays on top
           view.bringSubviewToFront(controlsContainer)
        print("viewDidLoad - topContainer size: \(topContainer.frame.size), controlsContainer size: \(controlsContainer.frame.size)")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let freeformButton = self.view.viewWithTag(1) { // Ensure it's the correct type
               self.handleAspectRatioSelection(freeformButton)
           }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupImageViewFrame()
        if let imageView = self.imageView {
            croppingAreaView?.frame = imageView.frame
        }
        updateCornerHandlesPosition()
        addGridLinesToCroppingArea()
        
        print("viewDidLayoutSubviews - topContainer size: \(topContainer.frame.size), controlsContainer size: \(controlsContainer.frame.size)")
    
    }

    private func adjustCroppingAreaAndImageView(for aspectRatioTag: Int) {
        guard let image = editingImage else { return }

        let containerSize = topContainer.bounds.size
        let selectedAspectRatio = aspectRatio(forTag: aspectRatioTag)

        // Calculate new size and position for cropping area
        var newCroppingSize: CGSize
        if selectedAspectRatio > (containerSize.width / containerSize.height) {
            newCroppingSize = CGSize(width: containerSize.width, height: containerSize.width / selectedAspectRatio)
        } else {
            newCroppingSize = CGSize(width: containerSize.height * selectedAspectRatio, height: containerSize.height)
        }
        let croppingX = (containerSize.width - newCroppingSize.width) / 2
        let croppingY = (containerSize.height - newCroppingSize.height) / 2

        // Adjust cropping area within topContainer bounds
        croppingAreaView?.frame = CGRect(x: croppingX, y: max(croppingY, 0), width: newCroppingSize.width, height: min(newCroppingSize.height, containerSize.height))

        // Adjust imageView without removing it from the superview
        imageView?.translatesAutoresizingMaskIntoConstraints = true // Enable manual frame adjustment
        var imageViewFrame: CGRect = .zero

        if aspectRatioTag != 1 && aspectRatioTag != 2 { // Non-Freeform, Non-9:16
            let imageViewHeight = min(containerSize.width / image.size.width * image.size.height, containerSize.height)
            let adjustedYPosition = max((containerSize.height - imageViewHeight) / 2, 0)
            imageViewFrame = CGRect(x: 0, y: adjustedYPosition, width: containerSize.width, height: imageViewHeight)
        } else {
            // For Freeform and 9:16, ensure it matches the cropping area and stays within topContainer
            let adjustedFrame = CGRect(x: croppingX, y: max(croppingY, 0), width: newCroppingSize.width, height: min(newCroppingSize.height, containerSize.height))
            imageViewFrame = adjustedFrame
        }

        imageView?.frame = imageViewFrame
        imageView?.contentMode = .scaleAspectFill
        imageView?.clipsToBounds = false // Consider enabling clipping if you do not want the image to extend beyond its bounds visually

        // Ensure the cropping area and related UI components are correctly updated
        addCornerHandlesToCroppingArea()
        addGridLinesToCroppingArea()
        addOverlayOutsideCroppingArea()
        view.layoutIfNeeded() // Refresh layout
    }

    private func setupImageView() {
        guard let editingImage = editingImage else { return }
        
        imageView?.removeFromSuperview() // Remove the existing imageView, if any
        
        let imageView = UIImageView(image: editingImage)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        topContainer.addSubview(imageView)
        self.imageView = imageView
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Constraints to ensure imageView is centered and fills the available space without exceeding the cropping area
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: topContainer.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: topContainer.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: topContainer.widthAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: topContainer.heightAnchor),
            imageView.leadingAnchor.constraint(greaterThanOrEqualTo: topContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(lessThanOrEqualTo: topContainer.trailingAnchor),
            imageView.topAnchor.constraint(greaterThanOrEqualTo: topContainer.topAnchor),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: topContainer.bottomAnchor)
        ])
        
        // Use aspect ratio constraint to maintain the image's aspect ratio
        let aspectRatio = editingImage.size.width / editingImage.size.height
        imageView.addConstraint(NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: imageView, attribute: .height, multiplier: aspectRatio, constant: 0).withPriority(UILayoutPriority(rawValue: 999)))
        
        // Allow zooming
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchImage(_:)))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(pinchGesture)
        topContainer.addGestureRecognizer(pinchGesture)
    }

    private func updateUIComponentsRelatedToCroppingAndImageView() {
        // Example: Update overlays, corner handles, and grid lines
        addCornerHandlesToCroppingArea()
        addGridLinesToCroppingArea()
        // Any other UI update logic related to the change in the cropping area or imageView
    }

    
    @objc private func handleAspectRatioSelection(_ sender: Any) {
        print("Before handleAspectRatioSelection - topContainer size: \(topContainer.frame.size), controlsContainer size: \(controlsContainer.frame.size)")
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

        // Reset appearance for all buttons
        // Assuming you have an array or some way to iterate over all aspect ratio buttons
        // resetAllButtons() // This is a hypothetical method to reset all buttons

        if let previousSelectedButton = selectedAspectRatioButton {
            let previousIconView = previousSelectedButton.subviews.compactMap { $0 as? UIImageView }.first
            let previousLabelView = previousSelectedButton.subviews.compactMap { $0 as? UILabel }.first
            previousIconView?.tintColor = .white // Reset icon color
            previousLabelView?.textColor = .white // Reset label color
        }

        // Highlight the newly selected button's icon and label
        let iconView = viewToSelect.subviews.compactMap { $0 as? UIImageView }.first
        let labelView = viewToSelect.subviews.compactMap { $0 as? UILabel }.first
        iconView?.tintColor = UIColor(red: 70/255, green: 87/255, blue: 245/255, alpha: 1) // Selected icon color
        labelView?.textColor = UIColor(red: 70/255, green: 87/255, blue: 245/255, alpha: 1) // Selected label color

        selectedAspectRatioButton = viewToSelect // Update the reference to the newly selected button

        // Now, adjust cropping area and imageView based on the selected aspect ratio
        adjustCroppingAreaAndImageView(for: viewToSelect.tag)
        print("After handleAspectRatioSelection - topContainer size: \(topContainer.frame.size), controlsContainer size: \(controlsContainer.frame.size)")
    }
    
    private func aspectRatio(forTag tag: Int) -> CGFloat {
        switch tag {
        case 1: // Tag for "Freeform" might just maintain the video's original aspect ratio
            return calculateImageAspectRatio() ?? 16/9 // Default to 16:9 if calculation fails
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
    
    private func setupImageViewFrame() {
        guard let imageView = imageView, let image = imageView.image else { return }

        // Remove previous constraints that might conflict
        NSLayoutConstraint.deactivate(imageView.constraints.filter {
            $0.firstItem === imageView || $0.secondItem === imageView
        })
        
        let imageAspectRatio = image.size.width / image.size.height
        let containerSize = topContainer.bounds.size
        let containerAspectRatio = containerSize.width / containerSize.height

        // Re-apply constraints based on the aspect ratio comparison
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than the container
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: topContainer.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: topContainer.trailingAnchor),
                imageView.centerYAnchor.constraint(equalTo: topContainer.centerYAnchor),
                imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 1/imageAspectRatio)
            ])
        } else {
            // Image is taller than the container
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: topContainer.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: topContainer.bottomAnchor),
                imageView.centerXAnchor.constraint(equalTo: topContainer.centerXAnchor),
                imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: imageAspectRatio)
            ])
        }
        
        imageView.layoutIfNeeded() // Ensure the layout is immediately updated
    }

    
    private func setupTopContainer() {
        topContainer.backgroundColor = UIColor(red: 20.0/255.0, green: 20.0/255.0, blue: 20.0/255.0, alpha: 1.0)
        view.addSubview(topContainer)
        
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topContainer.bottomAnchor.constraint(equalTo: controlsContainer.topAnchor)
        ])
        
       

    }

    deinit {
        // Don't forget to remove the observer
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handlePinchImage(_ gesture: UIPinchGestureRecognizer) {
        guard let imageView = self.imageView else { return }

        if gesture.state == .began {
            let locationInView = gesture.location(in: imageView)
            // Normalize the pinch location within the imageView bounds
            let anchorPointX = locationInView.x / imageView.bounds.width
            let anchorPointY = locationInView.y / imageView.bounds.height
            // Adjust imageView's anchor point without moving it
            updateAnchorPointWithoutMoving2(view: imageView, toPoint: CGPoint(x: anchorPointX, y: anchorPointY))
        }

        if gesture.state == .began || gesture.state == .changed {
            let pinchScale = gesture.scale

            // Calculate the scale factor that will be applied if the gesture is recognized
            let currentScale = sqrt(imageView.transform.a * imageView.transform.d) // Extract current scale from transform
            let newScale = currentScale * pinchScale

            // Define the minimum scale factor
            let minScale: CGFloat = 1.0 // Adjust this to fit the minimum size constraint you want

            // Check if the new scale is within the acceptable bounds
            if newScale >= minScale {
                imageView.transform = imageView.transform.scaledBy(x: pinchScale, y: pinchScale)
                gesture.scale = 1.0 // Reset the gesture scale for the next pinch event
            } else {
                // Optionally, apply a minor adjustment to align exactly with the minimum scale,
                // preventing minor scaling below the threshold due to gesture precision.
                let adjustmentScale = minScale / currentScale
                imageView.transform = imageView.transform.scaledBy(x: adjustmentScale, y: adjustmentScale)
            }
        }
    }

//    @objc private func handlePinchImage(_ gesture: UIPinchGestureRecognizer) {
//        guard let imageView = self.imageView else { return }
//
//        if gesture.state == .began || gesture.state == .changed {
//            let pinchScale = gesture.scale
//            
//            // Apply pinch scale to the imageView's transform for scaling
//            imageView.transform = imageView.transform.scaledBy(x: pinchScale, y: pinchScale)
//            
//            gesture.scale = 1.0 // Resetting the gesture scale for the next pinch event
//            
//            // Ensure imageView doesn't shrink smaller than the cropping area
//            let currentScale = imageView.frame.size.width / imageView.bounds.size.width
//            let newScale = currentScale * pinchScale
//            let minScale: CGFloat = 1.0 // Adjust minScale based on your requirements
//            
//            // Prevent the imageView from scaling down too much (Optional)
//            if newScale < minScale {
//                imageView.transform = CGAffineTransform(scaleX: minScale, y: minScale)
//            }
//            
//            // Update constraints or frame to ensure imageView stays within desired bounds (Optional)
//            // This step depends on how you want the imageView to behave at its minimum and maximum zoom levels
//        }
//    }

    func updateAnchorPointWithoutMoving2(view: UIView, toPoint newAnchorPoint: CGPoint) {
        let oldAnchorPoint = view.layer.anchorPoint
        view.layer.anchorPoint = newAnchorPoint
        let newPoint = CGPoint(x: view.bounds.size.width * newAnchorPoint.x,
                               y: view.bounds.size.height * newAnchorPoint.y)
        let oldPoint = CGPoint(x: view.bounds.size.width * oldAnchorPoint.x,
                               y: view.bounds.size.height * oldAnchorPoint.y)

        var position = view.layer.position
        position.x -= oldPoint.x - newPoint.x
        position.y -= oldPoint.y - newPoint.y

        view.layer.position = position
    }


    func updateAnchorPointWithoutMoving(_ layer: CALayer, toPoint newAnchorPoint: CGPoint) {
        let oldOrigin = layer.frame.origin
        layer.anchorPoint = newAnchorPoint
        let newOrigin = layer.frame.origin

        let transition = CGPoint(x: newOrigin.x - oldOrigin.x, y: newOrigin.y - oldOrigin.y)
        layer.position = CGPoint(x: layer.position.x - transition.x, y: layer.position.y - transition.y)
    }
    
 


//    private func setupControlsContainer() {
//        controlsContainer.backgroundColor = UIColor(red: 27.0/255.0, green: 27.0/255.0, blue: 27.0/255.0, alpha: 1.0)
//        view.addSubview(controlsContainer)
//
//        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            controlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            // Adjust height constraint as needed including vertical padding
//        ])
//        
//        // Create a vertical stack view to add to controlsContainer
//        let controlsStackView = UIStackView()
//        controlsStackView.axis = .vertical
//        controlsStackView.alignment = .fill
//        controlsStackView.distribution = .fill
//        controlsStackView.spacing = 25 // Vertical spacing between elements
//
//        // Add the aspect ratio selector and action buttons
//        let aspectRatioSelectorView = setupAspectRatioSelector()
//        let actionButtonsView = setupActionButtons()
//
//        // Add a spacer view for pushing elements to top and bottom
//        let spacerView = UIView()
//        spacerView.setContentHuggingPriority(.defaultLow, for: .vertical)
//
//        controlsStackView.addArrangedSubview(aspectRatioSelectorView)
//        controlsStackView.addArrangedSubview(spacerView) // This acts like a spacer
//        controlsStackView.addArrangedSubview(actionButtonsView)
//        
//        controlsContainer.addSubview(controlsStackView)
//        controlsStackView.translatesAutoresizingMaskIntoConstraints = false
//
//        // Apply constraints including vertical padding
//        NSLayoutConstraint.activate([
//            controlsStackView.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 25), // Top padding
//            controlsStackView.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
//            controlsStackView.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
//            controlsStackView.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -10), // Bottom padding
//        ])
//    }
//
    private func setupControlsContainer() {
        controlsContainer.backgroundColor = UIColor(red: 27.0/255.0, green: 27.0/255.0, blue: 27.0/255.0, alpha: 1.0)
        view.addSubview(controlsContainer)

        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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
        let spacerView = UIView()
        spacerView.setContentHuggingPriority(.defaultLow, for: .vertical)

        // Add arranged subviews to controlsStackView
        controlsStackView.addArrangedSubview(aspectRatioSelectorView)
        controlsStackView.addArrangedSubview(spacerView)
        controlsStackView.addArrangedSubview(actionButtonsView)
        
        controlsContainer.addSubview(controlsStackView)
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false

        // Constraints for controlsStackView
        NSLayoutConstraint.activate([
            controlsStackView.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 25), // Top padding
            controlsStackView.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 20), // Leading padding
            controlsStackView.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -20), // Trailing padding
            controlsStackView.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -25), // Bottom padding
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
        
        for (_, aspectRatio) in aspectRatios.enumerated() {
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


    func updateCornerHandlesPosition() {
        // Assume croppingAreaView and its bounds are correctly set up at this point
        guard let croppingAreaView = self.croppingAreaView else { return }

        // Remove any existing handles to start fresh
        croppingAreaView.subviews.forEach { if $0.tag == 999 { $0.removeFromSuperview() } }

        // Define handle characteristics
        let handleSideLength: CGFloat = 20.0
        let handleThickness: CGFloat = 4.0

        // Corner positions relative to the croppingAreaView's bounds
        let positions = [
            CGPoint(x: 0, y: 0), // Top-left
            CGPoint(x: croppingAreaView.bounds.maxX - handleSideLength, y: 0), // Top-right
            CGPoint(x: 0, y: croppingAreaView.bounds.maxY - handleSideLength), // Bottom-left
            CGPoint(x: croppingAreaView.bounds.maxX - handleSideLength, y: croppingAreaView.bounds.maxY - handleSideLength) // Bottom-right
        ]

        // Create and add handles
        positions.enumerated().forEach { index, position in
            let handle = UIView(frame: CGRect(x: position.x, y: position.y, width: handleSideLength, height: handleSideLength))
            handle.backgroundColor = .clear
            handle.tag = 999 // Tag for identification

            // Create L shape
            let verticalPart = UIView()
            verticalPart.backgroundColor = .white
            verticalPart.frame = CGRect(x: (index % 2 == 0) ? 0 : handleSideLength - handleThickness, y: 0, width: handleThickness, height: handleSideLength)

            let horizontalPart = UIView()
            horizontalPart.backgroundColor = .white
            horizontalPart.frame = CGRect(x: 0, y: (index < 2) ? 0 : handleSideLength - handleThickness, width: handleSideLength, height: handleThickness)

            handle.addSubview(verticalPart)
            handle.addSubview(horizontalPart)

            croppingAreaView.addSubview(handle)
        }
    }

    private func createCornerView() -> UIView {
        let corner = UIView()
        corner.backgroundColor = .white
        corner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        corner.layer.cornerRadius = 0 // Optional, for rounded corners
        return corner
    }







    
    func calculateImageAspectRatio() -> CGFloat? {
        guard let image = editingImage else { return nil }
        return image.size.width / image.size.height
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

}
extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}

