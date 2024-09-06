
import SwiftUI

class OnboardingViewModel: ObservableObject {
    enum OnboardingStep {
        case landing
        case signup
        case emailVerification
        case info
        case welcome
        case login
    }

    @Published var currentStep: OnboardingStep = .landing
    @Published var email: String = ""
    @Published var region: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var activeTeamId: Int?
    @Published var activeWorkspaceId: Int?
    @Published var profileInitial: String = ""
    @Published var profileColor: String = ""
    
    // Add these new properties for subscription information
      @Published var subscriptionStatus: String = "none"
      @Published var subscriptionPlan: String?
      @Published var subscriptionExpiresAt: String?
    
    func updateSubscriptionInfo(status: String?, plan: String?, expiresAt: String?) {
        self.subscriptionStatus = status ?? "none"
        self.subscriptionPlan = plan
        self.subscriptionExpiresAt = expiresAt
        
        // Also update UserDefaults
        UserDefaults.standard.set(self.subscriptionStatus, forKey: "subscriptionStatus")
        UserDefaults.standard.set(self.subscriptionPlan, forKey: "subscriptionPlan")
        UserDefaults.standard.set(self.subscriptionExpiresAt, forKey: "subscriptionExpiresAt")
    }
    
    func getCurrentSubscriptionTier() -> SubscriptionTier {
        guard let plan = subscriptionPlan else {
            return .none
        }
        return SubscriptionTier(rawValue: plan) ?? .none
    }
    
    func hasActiveSubscription() -> Bool {
        return subscriptionStatus == "active" && subscriptionPlan != nil && subscriptionPlan != "None"
    }
    
    func getActiveSubscriptionType() -> SubscriptionTier {
        guard hasActiveSubscription() else {
            return .none
        }
        return getCurrentSubscriptionTier()
    }
      

    
}
