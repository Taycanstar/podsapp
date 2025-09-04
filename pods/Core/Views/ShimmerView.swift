import SwiftUI
import UIKit

// CALayer-driven shimmer overlay, robust inside Lists. Avoids SwiftUI state-driven resets.
struct CALShimmerOverlay: UIViewRepresentable {
    var highlightColor: UIColor
    var duration: CFTimeInterval = 1.6

    func makeUIView(context: Context) -> CALShimmerUIView {
        let v = CALShimmerUIView()
        v.applyParameters(highlightColor: highlightColor, duration: duration)
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: CALShimmerUIView, context: Context) {
        // Only applies parameters when changed; does not restart otherwise
        uiView.applyParameters(highlightColor: highlightColor, duration: duration)
    }
}

final class CALShimmerUIView: UIView {
    private let gradient = CAGradientLayer()
    private var currentColor: UIColor = UIColor(white: 1.0, alpha: 0.9)
    private var currentDuration: CFTimeInterval = 1.6
    private var isConfigured = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = false
        layer.addSublayer(gradient)
        configureIfNeeded()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        isOpaque = false
        layer.addSublayer(gradient)
        configureIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Overscan to keep motion smooth when entering/exiting edges
        let overscanX = bounds.width
        gradient.frame = bounds.insetBy(dx: -overscanX, dy: 0)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startAnimationIfNeeded()
        } else {
            gradient.removeAllAnimations()
        }
    }

    func applyParameters(highlightColor: UIColor, duration: CFTimeInterval) {
        configureIfNeeded()

        if highlightColor != currentColor {
            currentColor = highlightColor
            gradient.colors = [
                UIColor.clear.cgColor,
                currentColor.cgColor,
                UIColor.clear.cgColor
            ]
        }

        if duration != currentDuration {
            currentDuration = duration
            startAnimation(restart: true)
        } else {
            startAnimationIfNeeded()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.colors = [
            UIColor.clear.cgColor,
            currentColor.cgColor,
            UIColor.clear.cgColor
        ]
        gradient.locations = [-1, -0.5, 0]
        gradient.shouldRasterize = true
        gradient.rasterizationScale = UIScreen.main.scale
    }

    private func startAnimationIfNeeded() {
        if gradient.animation(forKey: "shimmer") == nil {
            startAnimation(restart: false)
        }
    }

    private func startAnimation(restart: Bool) {
        if restart {
            gradient.removeAnimation(forKey: "shimmer")
        }
        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = [-1, -0.5, 0]
        anim.toValue = [1, 1.5, 2]
        anim.duration = currentDuration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        gradient.add(anim, forKey: "shimmer")
    }
}
