import SwiftUI
import UIKit

// A robust, CALayer-driven shimmer that doesn't rely on SwiftUI state updates.
// Animates CAGradientLayer.locations infinitely, so it stays smooth inside Lists.
struct ShimmerView: UIViewRepresentable {
    var highlightColor: UIColor
    var duration: CFTimeInterval = 1.6

    func makeUIView(context: Context) -> ShimmerUIView {
        let v = ShimmerUIView()
        v.highlightColor = highlightColor
        v.duration = duration
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: ShimmerUIView, context: Context) {
        uiView.highlightColor = highlightColor
        uiView.duration = duration
        uiView.updateGradient()
    }
}

final class ShimmerUIView: UIView {
    private let gradient = CAGradientLayer()
    var highlightColor: UIColor = UIColor(white: 1.0, alpha: 0.9)
    var duration: CFTimeInterval = 1.6

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.addSublayer(gradient)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        layer.addSublayer(gradient)
        setupGradient()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startAnimation()
        } else {
            gradient.removeAllAnimations()
        }
    }

    func updateGradient() {
        setupGradient()
        startAnimation()
    }

    private func setupGradient() {
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.colors = [
            UIColor.clear.cgColor,
            highlightColor.cgColor,
            UIColor.clear.cgColor
        ]
        gradient.locations = [-1, -0.5, 0]
    }

    private func startAnimation() {
        gradient.removeAnimation(forKey: "shimmer")
        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = [-1, -0.5, 0]
        anim.toValue = [1, 1.5, 2]
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        gradient.add(anim, forKey: "shimmer")
    }
}

