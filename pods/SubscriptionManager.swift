

import SwiftUI
import StoreKit
import Foundation
import Mixpanel

class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    private var onboardingViewModel: OnboardingViewModel?
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionInfo: SubscriptionInfo?

    @Published var isLoading: Bool = false

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
          
          // Post a notification that the subscription has been updated
                NotificationCenter.default.post(name: .subscriptionUpdated, object: nil)
      }
    
    @MainActor // Add MainActor here too since it modifies published property
    func checkCurrentEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if let product = self.products.first(where: { $0.id == transaction.productID }) {
                    self.purchasedSubscriptions.append(product)
                }
            }
        }
    }

    @MainActor
    func fetchSubscriptionInfo(for email: String) async {
        print("Fetching subscription info for email: \(email)")
        let networkManager = NetworkManager()
        
        return await withCheckedContinuation { continuation in
            networkManager.fetchSubscriptionInfo(for: email) { result in
                switch result {
                case .success(let info):
                    DispatchQueue.main.async {
                        self.subscriptionInfo = info
                        print("Updated subscription info: \(String(describing: info))")
                    }
                    continuation.resume()
                case .failure(let error):
                    print("Failed to fetch subscription info: \(error)")
                    DispatchQueue.main.async {
                        self.subscriptionInfo = nil
                    }
                    continuation.resume()
                }
            }
        }
    }

    func hasActiveSubscription() -> Bool {
        print("Checking subscription status...")
        print("subscriptionInfo: \(String(describing: subscriptionInfo))")
        
        guard let subscriptionInfo = subscriptionInfo else {
            print("No subscription info available")
            return false
        }
        
        print("Subscription status: \(subscriptionInfo.status)")
        
        if subscriptionInfo.status == "active" {
            print("Subscription is active")
            return true
        }
        
        if subscriptionInfo.status == "cancelled" {
            print("Subscription is cancelled, checking expiration date")
            if let expiresAtString = subscriptionInfo.expiresAt {
                print("Expiration date string: \(expiresAtString)")
                let dateFormatter = ISO8601DateFormatter.fullFormatter
                if let expiresAt = dateFormatter.date(from: expiresAtString) {
                    print("Parsed expiration date: \(expiresAt)")
                    let currentDate = Date()
                    print("Current date: \(currentDate)")
                    let isStillActive = expiresAt > currentDate
                    print("Is still active: \(isStillActive)")
                    return isStillActive
                } else {
                    print("Failed to parse expiration date")
                    print("Date formatter used: \(dateFormatter.string(from: Date()))")
                }
            } else {
                print("No expiration date found for cancelled subscription")
            }
        }
        
        print("Subscription is not active")
        return false
    }

       func isSubscriptionCancelled() -> Bool {
           return subscriptionInfo?.status == "cancelled"
       }

       func getSubscriptionEndDate() -> Date? {
           guard let dateString = subscriptionInfo?.expiresAt else { return nil }
           let dateFormatter = ISO8601DateFormatter()
           return dateFormatter.date(from: dateString)
       }

    func shouldShowRenewButton() -> Bool {
        guard let subscriptionInfo = subscriptionInfo else {
            return false
        }
        
        let isCancelled = subscriptionInfo.status == "cancelled"
        let isStillActive = hasActiveSubscription()
        
        print("Should show renew button - Is cancelled: \(isCancelled), Is still active: \(isStillActive)")
        
        return isCancelled && isStillActive
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
      func renewSubscription(userEmail: String) async throws {
          print("Starting renewSubscription for email: \(userEmail)")

          let networkManager = NetworkManager()
          do {
              let result = try await networkManager.renewSubscription(userEmail: userEmail)
              print("Subscription renewal result: \(result)")
              
              if let status = result["status"] as? String, status == "success" {
                  print("Subscription renewed successfully")
                  await updateSubscriptionStatus()
                  
                  Mixpanel.mainInstance().track(event: "Subscription Renewal", properties: [
                      "Plan": subscriptionInfo?.plan ?? "Unknown",
                      "Renewed": true
                  ])

              } else {
                  throw SubscriptionError.renewalFailed
              }
          } catch {
              print("Error during renewal: \(error)")
              throw error
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
                    // Perform backend sync
                    if let latestVerification = await Transaction.latest(for: transaction.productID) {
                        switch latestVerification {
                        case .verified(let latestTransaction):
                            print("Latest transaction ID: \(latestTransaction.id)")
                            
                            try await syncPurchaseWithBackend(
                                productId: latestTransaction.productID,
                                transactionId: String(latestTransaction.id),
                                userEmail: userEmail,
                                onboardingViewModel: onboardingViewModel
                            )
                            
                            Mixpanel.mainInstance().track(event: "Subscription Purchase", properties: [
                                "Plan": planType == .annual ? "Annual" : "Monthly",
                                "Tier": tier.rawValue,
                            ])

                        case .unverified:
                            print("Latest transaction unverified")
                        }
                    }
                    
                    await transaction.finish()
                    
                    // Update the subscription status
                    await updateSubscriptionStatus()
                    
                    // Post a notification to update the view
                    NotificationCenter.default.post(name: .subscriptionUpdated, object: nil)
                    
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

    
    func syncPurchaseWithBackend(productId: String, transactionId: String, userEmail: String, onboardingViewModel: OnboardingViewModel) async throws {
        print("Syncing purchase with backend...")
        print("Product ID: \(productId)")
        print("Transaction ID: \(transactionId)")
        print("User Email: \(userEmail)")
        
        let networkManager = NetworkManager()
        print("Calling purchaseSubscription endpoint...")
        let purchaseResult = try await networkManager.purchaseSubscription(
            userEmail: userEmail,
            productId: productId,
            transactionId: transactionId
        )
        
        print("Backend sync result: \(purchaseResult)")
        await updateSubscriptionStatus()
    }


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
//                await updateSubscriptionStatus()
//                // Rest of the function remains the same
//            } catch {
//                print("Failed to sync purchase with backend: \(error)")
//                if let nsError = error as NSError? {
//                    print("Error domain: \(nsError.domain)")
//                    print("Error code: \(nsError.code)")
//                    print("Error userInfo: \(nsError.userInfo)")
//                }
//                throw error
//            }
//        } catch {
//            print("Couldn't read receipt data with error: \(error.localizedDescription)")
//        }
//    }
    
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
    func cancelSubscription(userEmail: String) async throws {
        print("Starting cancelSubscription for email: \(userEmail)")

        let networkManager = NetworkManager()
        do {
            let result = try await networkManager.cancelSubscription(userEmail: userEmail)
            print("Subscription cancellation result: \(result)")
            await updateSubscriptionStatus()
            
            Mixpanel.mainInstance().track(event: "Subscription Cancellation", properties: [
                "Plan": subscriptionInfo?.plan ?? "Unknown",
                "End Date": getSubscriptionEndDate()?.description ?? "Unknown"
            ])

        } catch {
            print("Error during cancellation: \(error)")
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
            return "$47.90 per year"
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
    case renewalFailed
    
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
        case .renewalFailed:
                   return "Failed to renew the subscription. Please try again later."
               }
        }
    }


enum SubscriptionTier: String, CaseIterable {
    case none = "None"
    case plusMonthly = "Pods Plus Monthly"
    case plusYearly = "Pods Plus Yearly"
    case teamMonthly = "Pods Team Monthly"
    case teamYearly = "Pods Team Yearly"
    
    var name: String {
        switch self {
        case .none: return "Free"
        case .plusMonthly, .plusYearly: return "Pods+"
        case .teamMonthly, .teamYearly: return "Pods Team"
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

extension ISO8601DateFormatter {
    static let fullFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        return formatter
    }()
}

