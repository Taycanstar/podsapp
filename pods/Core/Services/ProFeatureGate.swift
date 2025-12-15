import Foundation
import SwiftUI

@MainActor
final class ProFeatureGate: ObservableObject {
    enum ProFeature: String, CaseIterable {
        case foodScans = "Unlimited Food Scans"
        case workouts = "Unlimited Workout Sessions"
        case proSearch = "Pro Food Search"
        case analytics = "Advanced Analytics"
        case scheduledLogging = "Scheduled Meal Logging"
        case bulkLogging = "Bulk Photo Logging"
        
        var apiKey: String {
            switch self {
            case .foodScans: return "food_scans"
            case .workouts: return "workouts"
            case .proSearch: return "pro_search"
            case .analytics: return "analytics"
            case .scheduledLogging: return "scheduled_logging"
            case .bulkLogging: return "bulk_logging"
            }
        }
    }
    
    @Published var showUpgradeSheet = false
    @Published var blockedFeature: ProFeature?
    @Published var usageSummary: UsageSummary?
    @Published private(set) var isCheckingAccess = false
    
    private let networkManager = NetworkManager()
    private var subscriptionManager: SubscriptionManager?
    
    func configure(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
    }
    
    func hasActiveSubscription() -> Bool {
        subscriptionManager?.hasActiveSubscription() ?? false
    }
    
    func checkAccess(for feature: ProFeature,
                     userEmail: String,
                     increment: Bool = true,
                     onAllowed: @escaping () -> Void,
                     onBlocked: (() -> Void)? = nil) {
        // Paywall active - all users have full access
        onAllowed()
    }
    
    func requirePro(for feature: ProFeature,
                    userEmail: String,
                    action: @escaping () -> Void) {
        if hasActiveSubscription() {
            action()
            return
        }
        blockedFeature = feature
        showUpgradeSheet = true
        Task {
            await refreshUsageSummary(for: userEmail)
        }
    }
    
    func refreshUsageSummary(for userEmail: String) async {
        usageSummary = await withCheckedContinuation { continuation in
            networkManager.fetchUsageSummary(userEmail: userEmail) { result in
                switch result {
                case .success(let summary):
                    continuation.resume(returning: summary)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func dismissUpgradeSheet() {
        showUpgradeSheet = false
        blockedFeature = nil
    }
}
