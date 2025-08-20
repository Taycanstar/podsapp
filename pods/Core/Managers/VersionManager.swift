

import Foundation
import SwiftUI

@MainActor
class VersionManager: ObservableObject {
    @Published var requiresUpdate = false
    @Published var storeUrl: String?
    
    static let shared = VersionManager()
    
    func checkVersion() async {
        do {
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            print("📱 Current app version:", currentVersion)
            
            let response = try await NetworkManager().checkAppVersion()
            print("🔄 Version check response:", """
                Minimum version: \(response.minimumVersion)
                Needs update: \(response.needsUpdate)
                Store URL: \(response.storeUrl)
                """)
                
            requiresUpdate = response.needsUpdate
            storeUrl = response.storeUrl
        } catch {
            print("❌ Version check failed:", error)
        }
    }
}
