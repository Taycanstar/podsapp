
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
             let productIdentifiers = [
                 "com.humuli.pods.plus.monthly",
                 "com.humuli.pods.plus.yearly",
                 "com.humuli.pods.team.monthly",
                 "com.humuli.pods.team.yearly"
             ]
             
             print("Attempting to fetch products with IDs: \(productIdentifiers)")
             
             let storeProducts = try await Product.products(for: productIdentifiers)
             
             if storeProducts.isEmpty {
                 print("No products were fetched from the App Store.")
             } else {
                 self.products = storeProducts
                 print("Fetched products: \(storeProducts.map { "\($0.id): \($0.displayName)" })")
             }
         } catch {
             print("Failed to fetch products. Error: \(error)")
             if let storeKitError = error as? StoreKitError {
                 switch storeKitError {
                 case .networkError(let netError):
                     print("Network error: \(netError.localizedDescription)")
                 case .userCancelled:
                     print("User cancelled the request")
                 case .unknown:
                     print("An unknown StoreKit error occurred")
                 case .systemError(_):
                     print("System error")
                 case .notAvailableInStorefront:
                     print("Not avilable in store front")
                 case .notEntitled:
                     print("Not entitled")
                 @unknown default:
                     print("An unexpected StoreKit error occurred")
                 }
             }
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
    
    func purchase(tier: SubscriptionTier, planType: PricingView.PlanType) async throws {
        let productIdSuffix = planType == .annual ? "yearly" : "monthly"
        let productId = "\(tier.productIdPrefix).\(productIdSuffix)"
        print("Attempting to purchase product with ID: \(productId)")
        
        guard let product = self.products.first(where: { $0.id == productId }) else {
            print("Product not found for ID: \(productId)")
            throw SubscriptionError.productNotFound
        }
        
        print("Found product: \(product.id), \(product.displayName)")
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    print("Purchase success: \(transaction.productID)")
                    await transaction.finish()
                    await updatePurchasedSubscriptions()
                    await syncPurchaseWithBackend(productId: transaction.productID)
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
        } catch {
            print("Purchase failed: \(error)")
            throw error
        }
    }
    
    func syncPurchaseWithBackend(productId: String) async {
        let networkManager = NetworkManager()
        do {
            try await networkManager.updateSubscription(productId: productId)
        } catch {
            print("Failed to sync purchase with backend: \(error)")
        }
    }

    func startingPrice(for tier: SubscriptionTier) -> String {
        switch tier {
        case .none:
            return "Free"
        case .plusMonthly, .plusYearly:
            return "$3.99/month"
        case .teamMonthly, .teamYearly:
            return "$6.99 per seat/month"
        }
    }
      
    func annualPrice(for tier: SubscriptionTier) -> String {
        switch tier {
        case .none:
            return "Free"
        case .plusMonthly, .plusYearly:
            return "$3.99/month"
        case .teamMonthly, .teamYearly:
            return "$6.99 per seat/month"
        }
    }
      
    func monthlyPrice(for tier: SubscriptionTier) -> String {
        switch tier {
        case .none:
            return "Free"
        case .plusMonthly, .plusYearly:
            return "$5.99/month"
        case .teamMonthly, .teamYearly:
            return "$8.99 per seat/month"
        }
    }
      
    func annualBillingInfo(for tier: SubscriptionTier) -> String {
        switch tier {
        case .none:
            return "Free"
        case .plusMonthly, .plusYearly:
            return "$47.90 per year billed annually"
        case .teamMonthly, .teamYearly:
            return "$419.99 per year billed annually starting with 5 team members"
        }
    }
      
    func monthlyBillingInfo(for tier: SubscriptionTier) -> String {
        switch tier {
        case .none:
            return "Free"
        case .plusMonthly, .plusYearly:
            return "$71.88 per year billed monthly"
        case .teamMonthly, .teamYearly:
            return "$539.40 per year billed monthly starting with 5 team members"
        }
    }
}

enum SubscriptionError: Error {
    case purchaseUnverified
    case userCancelled
    case purchasePending
    case unknown
    case productNotFound
    
    var localizedDescription: String {
        switch self {
        case .purchaseUnverified:
            return "The purchase could not be verified."
        case .userCancelled:
            return "The purchase was cancelled."
        case .purchasePending:
            return "The purchase is pending."
        case .unknown:
            return "An unknown error occurred."
        case .productNotFound:
            return "The requested product could not be found."
        }
    }
}

enum SubscriptionTier: String, CaseIterable {
    case none = "None"
    case plusMonthly = "Podstack Plus Monthly"
    case plusYearly = "Podstack Plus Yearly"
    case teamMonthly = "Podstack Team Monthly"
    case teamYearly = "Podstack Team Yearly"
    
    var name: String {
        switch self {
        case .none: return "Free"
        case .plusMonthly, .plusYearly: return "Podstack+"
        case .teamMonthly, .teamYearly: return "Podstack Team"
        }
    }
    
    var productIdPrefix: String {
        switch self {
        case .none: return ""
        case .plusMonthly, .plusYearly: return "com.humuli.pods.plus"
        case .teamMonthly, .teamYearly: return "com.humuli.pods.team"
        }
    }
    
    var features: [String] {
        switch self {
        case .none:
            return ["Limited features"]
        case .plusMonthly, .plusYearly:
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
                "Free templates"
            ]
        case .teamMonthly, .teamYearly:
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
