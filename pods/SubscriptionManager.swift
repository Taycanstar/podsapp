//import SwiftUI
//import StoreKit
//import Foundation
//
//class SubscriptionManager: ObservableObject {
//    @Published var products: [Product] = []
//    @Published var purchasedSubscriptions: [Product] = []
//    private var onboardingViewModel: OnboardingViewModel?
//    private var lastKnownSubscriptionStatuses: [String: String] = [:]
//
//    init() {
//        Task {
//            await fetchProducts()
//            await updatePurchasedSubscriptions()
//            await listenForTransactions()
//        }
//
//    }
//    func setOnboardingViewModel(_ viewModel: OnboardingViewModel) {
//            self.onboardingViewModel = viewModel
//        }
//    
//    
//    
//
//    @MainActor
//    func fetchProducts() async {
//        do {
//            let productIdentifiers = [
//                "com.humuli.pods.plus.month",
//                "com.humuli.pods.plus.year",
//                "com.humuli.pods.team.month",
//                "com.humuli.pods.team.year"
//            ]
//            
//          
//            
//            let storeProducts = try await Product.products(for: productIdentifiers)
//            
//            if storeProducts.isEmpty {
//                print("No products were fetched from the App Store.")
//            } else {
//                self.products = storeProducts
//
//            }
//        } catch {
//            print("Failed to fetch products. Error: \(error)")
//            if let storeKitError = error as? StoreKitError {
//                switch storeKitError {
//                case .networkError(let netError):
//                    print("Network error: \(netError.localizedDescription)")
//                case .userCancelled:
//                    print("User cancelled the request")
//                case .unknown:
//                    print("An unknown StoreKit error occurred")
//                case .systemError(_):
//                    print("System error")
//                case .notAvailableInStorefront:
//                    print("Not available in store front")
//                case .notEntitled:
//                    print("Not entitled")
//                @unknown default:
//                    print("An unexpected StoreKit error occurred")
//                }
//            }
//        }
//    }
//    
//    @MainActor
//    func updatePurchasedSubscriptions() async {
//        for await result in Transaction.currentEntitlements {
//            if case .verified(let transaction) = result {
//                if let product = self.products.first(where: { $0.id == transaction.productID }) {
//                    self.purchasedSubscriptions.append(product)
//                }
//            }
//        }
//    }
//    
//    @MainActor
//    func listenForTransactions() async {
//        for await result in Transaction.updates {
//            if case .verified(let transaction) = result {
//                await handleVerifiedTransaction(transaction)
//            }
//        }
//    }
//
//    @MainActor
//    func handleVerifiedTransaction(_ transaction: StoreKit.Transaction) async {
//        if let product = self.products.first(where: { $0.id == transaction.productID }) {
//            self.purchasedSubscriptions.append(product)
//        }
//        await transaction.finish()
//        
//        NotificationCenter.default.post(name: .subscriptionPurchased, object: nil)
//    }
//
//    @MainActor
//    func purchase(tier: SubscriptionTier, planType: PricingView.PlanType, userEmail: String, onboardingViewModel: OnboardingViewModel) async throws {
//        let productIdSuffix = planType == .annual ? "year" : "month"
//        let productId = "\(tier.productIdPrefix).\(productIdSuffix)"
//        print("Attempting to purchase product with ID: \(productId)")
//        
//        guard let product = self.products.first(where: { $0.id == productId }) else {
//            print("Product not found for ID: \(productId)")
//            throw SubscriptionError.productNotFound
//        }
//        
//        print("Found product: \(product.id), \(product.displayName)")
//        
//        do {
//            let result = try await product.purchase()
//            
//            print("Purchase result: \(result)")
//            
//            switch result {
//            case .success(let verificationResult):
//                switch verificationResult {
//                case .verified(let transaction):
//
//                    print("Purchase success: \(transaction.productID)")
//                          await handleVerifiedTransaction(transaction)
//                          print("Syncing purchase with backend...")
//                    print("Transaction object: \(transaction)")
//                    print("Transaction ID: \(transaction.id.description)")
//
//                          await syncPurchaseWithBackend(
//                              productId: transaction.productID,
//                              transactionId: transaction.id.description,  // Add this line
//                              userEmail: userEmail,
//                              onboardingViewModel: onboardingViewModel
//                          )
//                case .unverified:
//                    print("Purchase unverified")
//                    throw SubscriptionError.purchaseUnverified
//                }
//            case .userCancelled:
//                print("User cancelled purchase")
//                throw SubscriptionError.userCancelled
//            case .pending:
//                print("Purchase pending")
//                throw SubscriptionError.purchasePending
//            @unknown default:
//                print("Unknown purchase result")
//                throw SubscriptionError.unknown
//            }
//        } catch {
//            print("Purchase failed: \(error)")
//            throw error
//        }
//    }
//
//    func syncPurchaseWithBackend(productId: String, transactionId: String, userEmail: String, onboardingViewModel: OnboardingViewModel) async {
//        print("Attempting to get receipt data...")
//        
//        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
//              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
//            print("App Store receipt not found")
//            return
//        }
//        
//        do {
//            let receiptData = try Data(contentsOf: appStoreReceiptURL)
//                    let receiptString = receiptData.base64EncodedString()
//                        .replacingOccurrences(of: "\n", with: "")
//                        .replacingOccurrences(of: "\r", with: "")
//            print("Full receipt string: \(receiptString)")
//            
//            print("Successfully retrieved receipt data")
//            print("Receipt data length: \(receiptString.count)")
//            print("Receipt string (first 100 characters): \(String(receiptString.prefix(100)))")
//            
//            let finalTransactionId = transactionId == "0" ? UUID().uuidString : transactionId
//                
//                print("Final Transaction ID: \(finalTransactionId)")
//            
//            let networkManager = NetworkManager()
//            do {
//                print("Calling purchaseSubscription endpoint with productId: \(productId), userEmail: \(userEmail)")
//                let purchaseResult = try await networkManager.purchaseSubscription(
//                    userEmail: userEmail,
//                    productId: productId,
//                    transactionId: finalTransactionId
////                    receiptData: receiptString
//                )
//                
//                print("Backend sync result: \(purchaseResult)")
//                
//                // Rest of the function remains the same
//            } catch {
//                print("Failed to sync purchase with backend: \(error)")
//                if let nsError = error as NSError? {
//                    print("Error domain: \(nsError.domain)")
//                    print("Error code: \(nsError.code)")
//                    print("Error userInfo: \(nsError.userInfo)")
//                }
//            }
//        } catch {
//            print("Couldn't read receipt data with error: \(error.localizedDescription)")
//        }
//    }
//
//    private func checkIfSubscriptionWillRenew(_ transaction: StoreKit.Transaction) async -> Bool {
//            guard let statuses = try? await Product.SubscriptionInfo.status(for: transaction.productID) else {
//                return false
//            }
//            
//            for status in statuses {
//                switch status.state {
//                case .subscribed:
//                    if case .verified(let renewalInfo) = status.renewalInfo {
//                        return renewalInfo.willAutoRenew
//                    }
//                case .inGracePeriod:
//                    if case .verified(let renewalInfo) = status.renewalInfo {
//                        return renewalInfo.willAutoRenew
//                    }
//                case .inBillingRetryPeriod:
//                    if case .verified(let renewalInfo) = status.renewalInfo {
//                        return renewalInfo.willAutoRenew
//                    }
//                case .expired:
//                    continue
//                case .revoked:
//                    continue
//                default:
//                    print("Unknown subscription state for \(transaction.productID)")
//                    continue
//                }
//            }
//            
//            return false
//        }
//
//    func startingPrice(for tier: SubscriptionTier) -> String {
//        switch tier {
//        case .none:
//            return "Free"
//        case .plusMonthly, .plusYearly:
//            return "$5.99/month"
//        case .teamMonthly, .teamYearly:
////            return "$6.99 per seat/month"
//            return "$44.99/month for 5 seats"
//        }
//    }
//      
//    func annualPrice(for tier: SubscriptionTier) -> String {
//        switch tier {
//        case .none:
//            return "Free"
//        case .plusMonthly, .plusYearly:
//            return "$3.99/month"
//        case .teamMonthly, .teamYearly:
//            return "$6.99 per seat/month"
//        }
//    }
//      
//    func monthlyPrice(for tier: SubscriptionTier) -> String {
//        switch tier {
//        case .none:
//            return "Free"
//        case .plusMonthly, .plusYearly:
//            return "$5.99/month"
//        case .teamMonthly, .teamYearly:
//            return "$8.99 per seat/month"
//        }
//    }
//      
//    func annualBillingInfo(for tier: SubscriptionTier) -> String {
//        switch tier {
//        case .none:
//            return "Free"
//        case .plusMonthly, .plusYearly:
//            return "$47.90 per year billed annually"
//        case .teamMonthly, .teamYearly:
//            return "$419.99 per year billed annually starting with 5 team members"
//        }
//    }
//      
//    func monthlyBillingInfo(for tier: SubscriptionTier) -> String {
//        switch tier {
//        case .none:
//            return "Free"
//        case .plusMonthly, .plusYearly:
//            return "$71.88 per year billed monthly"
//        case .teamMonthly, .teamYearly:
//            return "$539.40 per year billed monthly starting with 5 team members"
//        }
//    }
//}
//
//enum SubscriptionError: Error {
//    case purchaseUnverified
//    case userCancelled
//    case purchasePending
//    case unknown
//    case productNotFound
//    
//    var localizedDescription: String {
//        switch self {
//        case .purchaseUnverified:
//            return "The purchase could not be verified."
//        case .userCancelled:
//            return "The purchase was cancelled."
//        case .purchasePending:
//            return "The purchase is pending."
//        case .unknown:
//            return "An unknown error occurred."
//        case .productNotFound:
//            return "The requested product could not be found."
//        }
//    }
//}
//
//enum SubscriptionTier: String, CaseIterable {
//    case none = "None"
//    case plusMonthly = "Podstack Plus Monthly"
//    case plusYearly = "Podstack Plus Yearly"
//    case teamMonthly = "Podstack Team Monthly"
//    case teamYearly = "Podstack Team Yearly"
//    
//    var name: String {
//        switch self {
//        case .none: return "Free"
//        case .plusMonthly, .plusYearly: return "Podstack+"
//        case .teamMonthly, .teamYearly: return "Podstack Team"
//        }
//    }
//    
//    var productIdPrefix: String {
//        switch self {
//        case .none: return ""
//        case .plusMonthly, .plusYearly: return "com.humuli.pods.plus"
//        case .teamMonthly, .teamYearly: return "com.humuli.pods.team"
//        }
//    }
//    
//    var features: [String] {
//        switch self {
//        case .none:
//            return ["Limited features"]
//        case .plusMonthly, .plusYearly:
//            return [
//                "Unlimited pods",
//                "Unlimited items",
//                "Unlimited workspaces",
//                "AI automation features",
//                "Activity logs from up to 2 weeks",
//                "Data tracking and analysis",
//                "Customize column colors",
//                "Video integration",
//                "Collaboration features",
//                "Free templates"
//            ]
//        case .teamMonthly, .teamYearly:
//            return [
//                "Create a new team",
//                "Team dashboard with analytics",
//                "Individual team members' analytics",
//                "Activity logs from up to 1 month",
//                "Unlimited pods",
//                "Unlimited items",
//                "Unlimited workspaces",
//                "AI Automation features",
//                "Data tracking and analysis",
//                "Customize column colors",
//                "Video integration",
//                "Collaboration features",
//                "Free templates"
//            ]
//        }
//    }
//}
//
//extension Notification.Name {
//    static let subscriptionPurchased = Notification.Name("subscriptionPurchased")
//    static let subscriptionUpdated = Notification.Name("subscriptionUpdated")
//}

import SwiftUI
import StoreKit
import Foundation

class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    private var onboardingViewModel: OnboardingViewModel?
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionInfo: SubscriptionInfo?

    init() {
        Task {
            await fetchProducts()
            await updatePurchasedSubscriptions()
            await listenForTransactions()
        }

    }
    func setOnboardingViewModel(_ viewModel: OnboardingViewModel) {
            self.onboardingViewModel = viewModel
        }
    
    @MainActor
      func updateSubscriptionStatus() async {
          await checkCurrentEntitlements()
          if let email = onboardingViewModel?.email {
              await fetchSubscriptionInfo(for: email)
          }
      }
    
    
    
    func checkCurrentEntitlements() async {
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if let product = self.products.first(where: { $0.id == transaction.productID }) {
                        self.purchasedSubscriptions.append(product)
                    }
                }
            }
        }

    func fetchSubscriptionInfo(for email: String) {
           let networkManager = NetworkManager()
           networkManager.fetchSubscriptionInfo(for: email) { result in
               DispatchQueue.main.async {
                   switch result {
                   case .success(let info):
                       self.subscriptionInfo = info
                   case .failure(let error):
                       print("Failed to fetch subscription info: \(error)")
                   }
               }
           }
       }


    func hasActiveSubscription() -> Bool {
            return subscriptionInfo?.status == "active" && subscriptionInfo?.plan != nil && subscriptionInfo?.plan != "None"
        }

        func getCurrentSubscriptionTier() -> SubscriptionTier {
            return SubscriptionTier(rawValue: subscriptionInfo?.plan ?? "None") ?? .none
        }

    @MainActor
    func fetchProducts() async {
        do {
            let productIdentifiers = [
                "com.humuli.pods.plus.month",
                "com.humuli.pods.plus.year",
                "com.humuli.pods.team.month",
                "com.humuli.pods.team.year"
            ]
            
          
            
            let storeProducts = try await Product.products(for: productIdentifiers)
            
            if storeProducts.isEmpty {
                print("No products were fetched from the App Store.")
            } else {
                self.products = storeProducts

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
                    print("Not available in store front")
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
    
    @MainActor
    func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await handleVerifiedTransaction(transaction)
            }
        }
    }

    @MainActor
    func handleVerifiedTransaction(_ transaction: StoreKit.Transaction) async {
        if let product = self.products.first(where: { $0.id == transaction.productID }) {
            self.purchasedSubscriptions.append(product)
        }
        await transaction.finish()
        
        NotificationCenter.default.post(name: .subscriptionPurchased, object: nil)
    }

    @MainActor
    func purchase(tier: SubscriptionTier, planType: PricingView.PlanType, userEmail: String, onboardingViewModel: OnboardingViewModel) async throws {
        let productIdSuffix = planType == .annual ? "year" : "month"
        let productId = "\(tier.productIdPrefix).\(productIdSuffix)"
        print("Attempting to purchase product with ID: \(productId)")
        
        guard let product = self.products.first(where: { $0.id == productId }) else {
            print("Product not found for ID: \(productId)")
            throw SubscriptionError.productNotFound
        }
        
        print("Found product: \(product.id), \(product.displayName)")
        
        do {
            let result = try await product.purchase()
            
            print("Purchase result: \(result)")
            
            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):

                    print("Purchase success: \(transaction.productID)")
                          await handleVerifiedTransaction(transaction)
                          print("Syncing purchase with backend...")

                          await syncPurchaseWithBackend(
                              productId: transaction.productID,
                              transactionId: transaction.id.description,  // Add this line
                              userEmail: userEmail,
                              onboardingViewModel: onboardingViewModel
                          )
                  
                case .unverified:
                    print("Purchase unverified")
                    throw SubscriptionError.purchaseUnverified
                }
            case .userCancelled:
                print("User cancelled purchase")
                throw SubscriptionError.userCancelled
            case .pending:
                print("Purchase pending")
                throw SubscriptionError.purchasePending
            @unknown default:
                print("Unknown purchase result")
                throw SubscriptionError.unknown
            }
        } catch {
            print("Purchase failed: \(error)")
            throw error
        }
    }

    func syncPurchaseWithBackend(productId: String, transactionId: String, userEmail: String, onboardingViewModel: OnboardingViewModel) async {
        print("Attempting to get receipt data...")
        
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            print("App Store receipt not found")
            return
        }
        
        do {
            let receiptData = try Data(contentsOf: appStoreReceiptURL)
                    let receiptString = receiptData.base64EncodedString()
                        .replacingOccurrences(of: "\n", with: "")
                        .replacingOccurrences(of: "\r", with: "")
            print("Full receipt string: \(receiptString)")
            
            print("Successfully retrieved receipt data")
            print("Receipt data length: \(receiptString.count)")
            print("Receipt string (first 100 characters): \(String(receiptString.prefix(100)))")
            
            let finalTransactionId = transactionId == "0" ? UUID().uuidString : transactionId
                
                print("Final Transaction ID: \(finalTransactionId)")
            
            let networkManager = NetworkManager()
            do {
                print("Calling purchaseSubscription endpoint with productId: \(productId), userEmail: \(userEmail)")
                let purchaseResult = try await networkManager.purchaseSubscription(
                    userEmail: userEmail,
                    productId: productId,
                    transactionId: finalTransactionId
//                    receiptData: receiptString
                )
                
                print("Backend sync result: \(purchaseResult)")
                await updateSubscriptionStatus()
                // Rest of the function remains the same
            } catch {
                print("Failed to sync purchase with backend: \(error)")
                if let nsError = error as NSError? {
                    print("Error domain: \(nsError.domain)")
                    print("Error code: \(nsError.code)")
                    print("Error userInfo: \(nsError.userInfo)")
                }
            }
        } catch {
            print("Couldn't read receipt data with error: \(error.localizedDescription)")
        }
    }
    
    @MainActor
        func handleSubscriptionChange(_ transaction: StoreKit.Transaction) async {
            let productId = transaction.productID
            let transactionId = transaction.id.description
            let userEmail = onboardingViewModel?.email ?? ""

            let networkManager = NetworkManager()
            do {
                let result = try await networkManager.updateSubscription(
                    userEmail: userEmail,
                    productId: productId,
                    transactionId: transactionId
                )
                print("Subscription change sync result: \(result)")
                await updateSubscriptionStatus()
            } catch {
                print("Failed to sync subscription change with backend: \(error)")
            }
        }

        @MainActor
        func cancelSubscription() async throws {
            guard let userEmail = onboardingViewModel?.email else {
                throw SubscriptionError.userEmailNotFound
            }

            let networkManager = NetworkManager()
            do {
                let result = try await networkManager.cancelSubscription(userEmail: userEmail)
                print("Subscription cancellation result: \(result)")
                await updateSubscriptionStatus()
            } catch {
                throw error
            }
        }

    func startingPrice(for tier: SubscriptionTier) -> String {
        switch tier {
        case .none:
            return "Free"
        case .plusMonthly, .plusYearly:
            return "$5.99/month"
        case .teamMonthly, .teamYearly:
//            return "$6.99 per seat/month"
            return "$44.99/month for 5 seats"
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
    case userEmailNotFound
    
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
        case .userEmailNotFound:
                    return "User email not found."
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

extension Notification.Name {
    static let subscriptionPurchased = Notification.Name("subscriptionPurchased")
    static let subscriptionUpdated = Notification.Name("subscriptionUpdated")
}
