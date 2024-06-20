import Foundation

class RegionManager {
    static let shared = RegionManager()
    
    private init() {
        // Initialize with a default region if needed
        region = "centralus"
    }
    
    var region: String {
        didSet {
            print("Region updated to: \(region)")
        }
    }
}
