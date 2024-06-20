import Foundation

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private var config: [String: Any]?

    private init() {
        loadConfiguration()
    }

    private func loadConfiguration() {
        if let path = Bundle.main.path(forResource: "config.release", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path) as? [String: Any] {
            self.config = config
        }
    }

    func getValue(forKey key: String) -> Any? {
        return config?[key]
    }
}
