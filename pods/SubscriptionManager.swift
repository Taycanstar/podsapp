//
//  SubscriptionManager.swift
//  Podstack
//
//  Created by Dimi Nunez on 9/2/24.
//
import SwiftUI
import StoreKit

class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    
    init() {
        Task {
            await fetchProducts()
            await updatePurchasedSubscriptions()
        }
    }
    
    @MainActor
    func fetchProducts() async {
        do {
            let storeProducts = try await Product.products(for: [
                "com.humuli.pods.plus.monthly",
                "com.humuli.pods.plus.yearly",
                "com.humuli.pods.team.monthly",
                "com.humuli.pods.team.yearly"
            ])
            self.products = storeProducts
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    @MainActor
    func updatePurchasedSubscriptions() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if let product = self.products.first(where: { $0.id == transaction.productID }) {
                    self.purchasedSubscriptions.append(product)
                }
            }
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verificationResult):
            switch verificationResult {
            case .verified(let transaction):
                await transaction.finish()
                await updatePurchasedSubscriptions()
                await notifyServerAboutPurchase(productId: transaction.productID)
            case .unverified:
                throw SubscriptionError.purchaseUnverified
            }
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.purchasePending
        @unknown default:
            throw SubscriptionError.unknown
        }
    }
    
    func notifyServerAboutPurchase(productId: String) async {
        // Implement API call to your server to update subscription status
    }
    
    // Pricing and tier information methods
    func startingPrice(for tier: SubscriptionTier) -> String {
        switch tier {
        case .plus:
            return "$3.99/month"
        case .team:
            return "$6.99 per seat/month"
        }
    }
    
    func annualPrice(for tier: SubscriptionTier) -> String {
        switch tier {
        case .plus:
            return "$3.99/month"
        case .team:
            return "$6.99 per seat/month"
        }
    }
    
    func monthlyPrice(for tier: SubscriptionTier) -> String {
        switch tier {
        case .plus:
            return "$5.99/month"
        case .team:
            return "$8.99 per seat/month"
        }
    }
    
    func annualBillingInfo(for tier: SubscriptionTier) -> String {
        switch tier {
        case .plus:
            return "$49.99 per year billed annually"
        case .team:
            return "$419.99 per year billed annually starting with 5 team members"
        }
    }
    
    func monthlyBillingInfo(for tier: SubscriptionTier) -> String {
        switch tier {
        case .plus:
            return "$71.88 per year billed monthly"
        case .team:
            return "$539.40 per year billed monthly starting with 5 team members"
        }
    }
    
    func purchase(tier: SubscriptionTier) {
        Task {
            if let product = self.products.first(where: { $0.id.contains(tier.productIdPrefix) }) {
                do {
                    try await purchase(product)
                } catch {
                    print("Failed to purchase: \(error)")
                }
            }
        }
    }
}

enum SubscriptionTier: CaseIterable {
    case plus, team
    
    var name: String {
        switch self {
        case .plus: return "Podstack+"
        case .team: return "Podstack Team"
        }
    }
    
    var productIdPrefix: String {
        switch self {
        case .plus: return "com.humuli.pods.plus"
        case .team: return "com.humuli.pods.team"
        }
    }
    
    var features: [String] {
        switch self {
        case .plus:
            return [
                "Unlimited pods",
                "Unlimited items",
                "Unlimited workspaces",
                "AI automation features",
                "Activity logs from up to 2 weeks",
                "Data tracking and analysis",
                "Customize column colors",
                "Video integration",
                "Collaboration features",
                "Free templates",
                
                
            ]
        case .team:
            return [
                "Create a new team",
                "Team dashboard with analytics",
                "Individual team members' analytics",
                "Activity logs from up to 1 month",
                "Unlimited pods",
                "Unlimited items",
                "Unlimited workspaces",
                "AI Automation features",
                "Data tracking and analysis",
                "Customize column colors",
                "Video integration",
                "Collaboration features",
                "Free templates"
               
            ]
        }
    }
}

enum SubscriptionError: Error {
    case purchaseUnverified
    case userCancelled
    case purchasePending
    case unknown
}
