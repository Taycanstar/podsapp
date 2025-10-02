import UIKit

enum NavigationBarStyler {
    private static var activeCount = 0
    private static var originalStandardAppearance: UINavigationBarAppearance?
    private static var originalScrollEdgeAppearance: UINavigationBarAppearance?
    private static var originalCompactAppearance: UINavigationBarAppearance?

    static func beginOnboardingAppearance() {
        if activeCount == 0 {
            originalStandardAppearance = UINavigationBar.appearance().standardAppearance
            originalScrollEdgeAppearance = UINavigationBar.appearance().scrollEdgeAppearance
            originalCompactAppearance = UINavigationBar.appearance().compactAppearance

            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .onboardingBackground
            appearance.shadowColor = .clear

            setAppearance(appearance)
        }

        activeCount += 1
    }

    static func endOnboardingAppearance() {
        guard activeCount > 0 else { return }

        activeCount -= 1
        guard activeCount == 0 else { return }

        setAppearance(originalStandardAppearance,
                      scrollEdge: originalScrollEdgeAppearance,
                      compact: originalCompactAppearance)

        originalStandardAppearance = nil
        originalScrollEdgeAppearance = nil
        originalCompactAppearance = nil
    }

    private static func setAppearance(_ standard: UINavigationBarAppearance?,
                                      scrollEdge: UINavigationBarAppearance? = nil,
                                      compact: UINavigationBarAppearance? = nil) {
        if let standard {
            UINavigationBar.appearance().standardAppearance = standard
        }
        if let scrollEdge {
            UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge
        } else if let standard {
            UINavigationBar.appearance().scrollEdgeAppearance = standard
        }
        if let compact {
            UINavigationBar.appearance().compactAppearance = compact
        } else if let standard {
            UINavigationBar.appearance().compactAppearance = standard
        }
    }
}
