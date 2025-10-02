import SwiftUI
import UIKit

extension UIColor {
    static var onboardingBackground: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .black : .systemGroupedBackground
        }
    }
}

extension Color {
    static var onboardingBackground: Color { Color(UIColor.onboardingBackground) }
}
