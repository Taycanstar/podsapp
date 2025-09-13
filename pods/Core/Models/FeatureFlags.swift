import Foundation

struct FeatureFlags {
    // Global toggle for block-based programming rollout
    static var blocksEnabled: Bool {
        // Default off; allow override via UserDefaults for testing
        if UserDefaults.standard.object(forKey: "feature_blocks_enabled") != nil {
            return UserDefaults.standard.bool(forKey: "feature_blocks_enabled")
        }
        return false
    }

    static var blocksSupersets: Bool {
        if UserDefaults.standard.object(forKey: "feature_blocks_supersets") != nil {
            return UserDefaults.standard.bool(forKey: "feature_blocks_supersets")
        }
        return false
    }

    static var blocksCircuits: Bool {
        if UserDefaults.standard.object(forKey: "feature_blocks_circuits") != nil {
            return UserDefaults.standard.bool(forKey: "feature_blocks_circuits")
        }
        return false
    }

    static var blocksIntervals: Bool {
        if UserDefaults.standard.object(forKey: "feature_blocks_intervals") != nil {
            return UserDefaults.standard.bool(forKey: "feature_blocks_intervals")
        }
        return false
    }
}

