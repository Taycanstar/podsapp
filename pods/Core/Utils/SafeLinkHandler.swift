//
//  SafeLinkHandler.swift
//  pods
//
//  Created by Dimi Nunez on 12/17/25.
//


//
//  SafeLinkHandler.swift
//  pods
//
//  Created by Claude on 12/17/25.
//

import SwiftUI
import SafariServices

/// Handles opening links safely with trust verification.
/// Trusted domains open directly, untrusted domains show a confirmation dialog.
final class SafeLinkHandler: NSObject {

    /// Shared instance for easy access
    static let shared = SafeLinkHandler()

    /// Whether to show confirmation for untrusted domains (can be disabled for testing)
    var showConfirmationForUntrusted = true

    private override init() {
        super.init()
    }

    /// Handle a link tap with trust verification (finds the topmost view controller automatically)
    /// - Parameter url: The URL to open
    func handleLink(_ url: URL) {
        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            // Fallback: open in default browser
            openInDefaultBrowser(url)
            return
        }

        // Find the topmost presented view controller
        let presentingVC = topMostViewController(from: rootVC)
        handleLink(url, from: presentingVC)
    }

    /// Handle a link tap with trust verification
    /// - Parameters:
    ///   - url: The URL to open
    ///   - viewController: The view controller to present from
    func handleLink(_ url: URL, from viewController: UIViewController) {
        if TrustedDomains.isTrusted(url) || !showConfirmationForUntrusted {
            // Trusted domain - open directly
            openInSafari(url, from: viewController)
        } else {
            // Untrusted domain - show confirmation
            showConfirmation(for: url, from: viewController)
        }
    }

    /// Handle a citation link tap
    /// - Parameters:
    ///   - citation: The citation to open
    ///   - viewController: The view controller to present from (optional)
    func handleCitation(_ citation: Citation, from viewController: UIViewController? = nil) {
        guard let urlString = citation.url, let url = URL(string: urlString) else {
            return
        }

        if let vc = viewController {
            handleLink(url, from: vc)
        } else {
            handleLink(url)
        }
    }

    // MARK: - Private Methods

    private func openInSafari(_ url: URL, from viewController: UIViewController) {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true

        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.preferredControlTintColor = .systemBlue
        safariVC.dismissButtonStyle = .close

        viewController.present(safariVC, animated: true)
    }

    private func showConfirmation(for url: URL, from viewController: UIViewController) {
        let domain = url.host ?? "this website"

        let alert = UIAlertController(
            title: "Open External Link?",
            message: "You're about to visit \(domain). This will open in Safari within the app.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open", style: .default) { [weak self] _ in
            self?.openInSafari(url, from: viewController)
        })

        viewController.present(alert, animated: true)
    }

    private func openInDefaultBrowser(_ url: URL) {
        UIApplication.shared.open(url)
    }

    private func topMostViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return topMostViewController(from: presented)
        }

        if let nav = viewController as? UINavigationController,
           let visible = nav.visibleViewController {
            return topMostViewController(from: visible)
        }

        if let tab = viewController as? UITabBarController,
           let selected = tab.selectedViewController {
            return topMostViewController(from: selected)
        }

        return viewController
    }
}

// MARK: - SwiftUI Integration

/// A SwiftUI view modifier that handles link taps with trust verification
struct SafeLinkHandlerModifier: ViewModifier {
    @State private var linkHandler = SafeLinkHandler.shared

    let onLinkTap: (URL) -> Void

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                linkHandler.handleLink(url)
                return .handled
            })
    }
}

extension View {
    /// Apply safe link handling to this view's links
    func safeLinkHandling() -> some View {
        self.modifier(SafeLinkHandlerModifier(onLinkTap: { url in
            SafeLinkHandler.shared.handleLink(url)
        }))
    }
}
