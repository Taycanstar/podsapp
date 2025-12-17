//
//  TrustedDomains.swift
//  pods
//
//  Created by Dimi Nunez on 12/17/25.
//


//
//  TrustedDomains.swift
//  pods
//
//  Created by Claude on 12/17/25.
//

import Foundation

/// Manages a list of trusted domains for safe link handling.
/// Links from trusted domains open directly in Safari.
/// Links from untrusted domains show a confirmation dialog first.
struct TrustedDomains {

    /// Set of trusted domains (health, fitness, nutrition, official sources)
    static let trusted: Set<String> = [
        // Government Health Sources
        "nih.gov",
        "cdc.gov",
        "who.int",
        "fda.gov",
        "usda.gov",
        "hhs.gov",

        // Medical/Health Information
        "mayoclinic.org",
        "webmd.com",
        "healthline.com",
        "clevelandclinic.org",
        "hopkinsmedicine.org",
        "medlineplus.gov",
        "medscape.com",
        "pubmed.ncbi.nlm.nih.gov",

        // Nutrition
        "fdc.nal.usda.gov",
        "nutritiondata.self.com",
        "myfitnesspal.com",
        "cronometer.com",
        "eatthismuch.com",

        // Fitness & Exercise
        "acefitness.org",
        "exrx.net",
        "bodybuilding.com",
        "strengthlevel.com",
        "muscleandstrength.com",

        // Academic & Research
        "scholar.google.com",
        "ncbi.nlm.nih.gov",
        "nature.com",
        "sciencedirect.com",

        // Apple
        "apple.com",
        "support.apple.com",
        "developer.apple.com",

        // General Trusted
        "wikipedia.org",
        "github.com"
    ]

    /// Check if a URL is from a trusted domain
    /// - Parameter url: The URL to check
    /// - Returns: `true` if the domain is trusted, `false` otherwise
    static func isTrusted(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        // Check exact match or subdomain match
        return trusted.contains { trustedDomain in
            host == trustedDomain || host.hasSuffix(".\(trustedDomain)")
        }
    }

    /// Check if a URL string is from a trusted domain
    /// - Parameter urlString: The URL string to check
    /// - Returns: `true` if the domain is trusted, `false` otherwise
    static func isTrusted(urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return isTrusted(url)
    }

    /// Get the display domain from a URL (for UI purposes)
    /// - Parameter url: The URL to extract the domain from
    /// - Returns: The host portion of the URL, or "Unknown" if not available
    static func displayDomain(from url: URL) -> String {
        url.host ?? "Unknown"
    }

    /// Get the display domain from a URL string
    /// - Parameter urlString: The URL string to extract the domain from
    /// - Returns: The host portion of the URL, or "Unknown" if not available
    static func displayDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "Unknown" }
        return displayDomain(from: url)
    }
}
