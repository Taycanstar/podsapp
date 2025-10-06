import SwiftUI
import UIKit

extension UIColor {
    static var onboardingBackground: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .black : .systemGroupedBackground
        }
    }

    static var onboardingCardBackground: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .systemGray6 : .white
        }
    }
}

extension Color {
    static var onboardingBackground: Color { Color(UIColor.onboardingBackground) }
    static var onboardingCardBackground: Color { Color(UIColor.onboardingCardBackground) }
}
