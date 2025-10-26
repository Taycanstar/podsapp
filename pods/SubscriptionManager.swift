

import SwiftUI
import StoreKit
import Foundation
import Mixpanel
import os.log

// Create logger for StoreKit diagnostics
private let storeKitLogger = Logger(subsystem: "com.humuli.pods", category: "StoreKit")

enum SubscriptionDuration {
    case monthly
    case yearly
}

class SubscriptionManager: ObservableObject {
    private enum CacheKeys {
        static let info = "cachedSubscriptionInfo"
        static let timestamp = "cachedSubscriptionInfoTimestamp"
        static let email = "cachedSubscriptionEmail"
    }

    @Published var products: [Product] = []
    private var onboardingViewModel: OnboardingViewModel?
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionInfo: SubscriptionInfo?

    @Published var isLoading: Bool = false

    private var lastFetchedEmail: String?
    private var lastFetchDate: Date?
    private let refreshInterval: TimeInterval = 300 // 5 minutes TTL

    init() {
        Task {
            await fetchProducts()
            await updatePurchasedSubscriptions()
            await listenForTransactions()
        }

        loadCachedSubscription()
    }
    func setOnboardingViewModel(_ viewModel: OnboardingViewModel) {
            self.onboardingViewModel = viewModel
        }
    
    @MainActor
    func fetchSubscriptionInfoIfNeeded(for email: String, force: Bool = false) async {
        if !force,
           let lastEmail = lastFetchedEmail,
           lastEmail == email,
           let lastFetchDate = lastFetchDate,
           Date().timeIntervalSince(lastFetchDate) < refreshInterval,
           subscriptionInfo != nil {
            return
        }

        await fetchSubscriptionInfo(for: email)
    }
    
    @MainActor
      func updateSubscriptionStatus() async {
          await checkCurrentEntitlements()
          if let email = onboardingViewModel?.email {
              await fetchSubscriptionInfoIfNeeded(for: email, force: true)
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
                        self.cacheSubscription(info, for: email)
                        self.lastFetchedEmail = email
                        self.lastFetchDate = Date()
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

    private func cacheSubscription(_ info: SubscriptionInfo, for email: String) {
        guard let encoded = try? JSONEncoder().encode(info) else { return }

        let defaults = UserDefaults.standard
        defaults.set(encoded, forKey: CacheKeys.info)
        defaults.set(Date(), forKey: CacheKeys.timestamp)
        defaults.set(email, forKey: CacheKeys.email)
    }

    private func loadCachedSubscription() {
        let defaults = UserDefaults.standard

        guard let currentEmail = defaults.string(forKey: "userEmail"),
              currentEmail.isEmpty == false else {
            clearCachedSubscription()
            return
        }

        guard let cachedEmail = defaults.string(forKey: CacheKeys.email),
              cachedEmail == currentEmail else {
            if defaults.object(forKey: CacheKeys.info) != nil {
                print("Warning: subscription cache email mismatch. Clearing stale cache.")
            }
            clearCachedSubscription()
            return
        }

        guard let data = defaults.data(forKey: CacheKeys.info),
              let cached = try? JSONDecoder().decode(SubscriptionInfo.self, from: data) else {
            clearCachedSubscription()
            return
        }

        subscriptionInfo = cached
        lastFetchedEmail = currentEmail
        lastFetchDate = defaults.object(forKey: CacheKeys.timestamp) as? Date
    }

    private func clearCachedSubscription() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: CacheKeys.info)
        defaults.removeObject(forKey: CacheKeys.timestamp)
        defaults.removeObject(forKey: CacheKeys.email)
    }

    @MainActor
    func clearSubscriptionState() {
        subscriptionInfo = nil
        lastFetchedEmail = nil
        lastFetchDate = nil
        purchasedSubscriptions = []
        clearCachedSubscription()
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
            let identifiers = SubscriptionTier.allProductIdentifiers
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"

            // Enhanced diagnostics using os_log (GUARANTEED to appear in Console.app)
            storeKitLogger.critical("═══════════════════════════════════════════")
            storeKitLogger.critical("[StoreKit] DETAILED DIAGNOSTICS")
            storeKitLogger.critical("═══════════════════════════════════════════")
            storeKitLogger.critical("[StoreKit] Bundle ID: \(bundleIdentifier)")
            storeKitLogger.critical("[StoreKit] Requesting products: \(identifiers.joined(separator: ", "))")
            storeKitLogger.critical("[StoreKit] Product count requested: \(identifiers.count)")
            storeKitLogger.critical("[StoreKit] Receipt URL exists: \(Bundle.main.appStoreReceiptURL?.path ?? "none")")
            if let receiptURL = Bundle.main.appStoreReceiptURL {
                let receiptExists = FileManager.default.fileExists(atPath: receiptURL.path)
                storeKitLogger.critical("[StoreKit] Receipt file exists: \(receiptExists ? "YES" : "NO")")
            }
            storeKitLogger.critical("[StoreKit] Current locale: \(Locale.current.identifier)")
            storeKitLogger.critical("[StoreKit] Current storefront: \(Locale.current.regionCode ?? "unknown")")
            storeKitLogger.critical("═══════════════════════════════════════════")

            guard identifiers.isEmpty == false else {
                storeKitLogger.error("❌ No product identifiers configured for subscription tiers.")
                products = []
                return
            }

            storeKitLogger.critical("[StoreKit] Calling Product.products(for:)...")
            let storeProducts = try await Product.products(for: identifiers)

            storeKitLogger.critical("═══════════════════════════════════════════")
            storeKitLogger.critical("[StoreKit] RESPONSE RECEIVED")
            storeKitLogger.critical("═══════════════════════════════════════════")
            storeKitLogger.critical("[StoreKit] Products returned: \(storeProducts.count)")

            if storeProducts.isEmpty {
                storeKitLogger.error("❌ NO PRODUCTS RETURNED FROM APP STORE")
                storeKitLogger.error("[StoreKit] This means:")
                storeKitLogger.error("  • Bundle ID mismatch, OR")
                storeKitLogger.error("  • Products not approved/available in this storefront, OR")
                storeKitLogger.error("  • Products not linked to this app version, OR")
                storeKitLogger.error("  • Apple server propagation delay")
            } else {
                storeKitLogger.info("✅ Products successfully fetched:")
                for (index, product) in storeProducts.enumerated() {
                    storeKitLogger.info("  [\(index + 1)] ID: \(product.id)")
                    storeKitLogger.info("      Name: \(product.displayName)")
                    storeKitLogger.info("      Price: \(product.displayPrice)")
                    storeKitLogger.info("      Type: \(String(describing: product.type))")
                    if let subscription = product.subscription {
                        storeKitLogger.info("      Period: \(subscription.subscriptionPeriod.value) \(String(describing: subscription.subscriptionPeriod.unit))")
                    }
                }
                products = storeProducts.sorted(by: { $0.displayName < $1.displayName })
            }
            storeKitLogger.critical("═══════════════════════════════════════════")
        } catch {
            storeKitLogger.critical("═══════════════════════════════════════════")
            storeKitLogger.critical("[StoreKit] ERROR OCCURRED")
            storeKitLogger.critical("═══════════════════════════════════════════")
            storeKitLogger.error("❌ Failed to fetch products. Error: \(error.localizedDescription)")

            let nsError = error as NSError
            storeKitLogger.error("❌ Domain: \(nsError.domain)")
            storeKitLogger.error("❌ Code: \(nsError.code)")
            storeKitLogger.error("❌ UserInfo: \(String(describing: nsError.userInfo))")

            if let storeKitError = error as? StoreKitError {
                switch storeKitError {
                case .networkError(let netError):
                    storeKitLogger.error("❌ Network error: \(netError.localizedDescription)")
                case .userCancelled:
                    storeKitLogger.error("❌ User cancelled the request")
                case .unknown:
                    storeKitLogger.error("❌ An unknown StoreKit error occurred")
                case .systemError(_):
                    storeKitLogger.error("❌ System error")
                case .notAvailableInStorefront:
                    storeKitLogger.error("❌ Not available in storefront")
                    storeKitLogger.error("   → Check product availability in App Store Connect for region: \(Locale.current.regionCode ?? "unknown")")
                case .notEntitled:
                    storeKitLogger.error("❌ Not entitled")
                @unknown default:
                    storeKitLogger.error("❌ An unexpected StoreKit error occurred")
                }
            }
            storeKitLogger.critical("═══════════════════════════════════════════")
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
            if case .verified(let transaction) = result,
               let product = products.first(where: { $0.id == transaction.productID }),
               purchasedSubscriptions.contains(where: { $0.id == product.id }) == false {
                purchasedSubscriptions.append(product)
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
        if let product = products.first(where: { $0.id == transaction.productID }),
           purchasedSubscriptions.contains(where: { $0.id == product.id }) == false {
            purchasedSubscriptions.append(product)
        }
        await transaction.finish()
        
        NotificationCenter.default.post(name: .subscriptionPurchased, object: nil)
    }
 

    @MainActor
    func purchase(tier: SubscriptionTier,
                  duration: SubscriptionDuration,
                  userEmail: String,
                  onboardingViewModel: OnboardingViewModel) async throws {
        guard let productId = tier.productIdentifier(for: duration) else {
            print("No product identifier configured for \(tier) and duration \(duration).")
            throw SubscriptionError.productNotFound
        }

        print("Attempting to purchase product with ID: \(productId)")
        
        guard let product = products.first(where: { $0.id == productId }) else {
            print("Product not found for ID: \(productId)")
            throw SubscriptionError.productNotFound
        }
        
        print("Found product: \(product.id), \(product.displayName)")

        // Check intro offer eligibility
        let isEligibleForIntro = await checkIntroductoryOfferEligibility(for: product)
        print("Eligible for introductory offer: \(isEligibleForIntro)")

        if let introDescription = await getIntroductoryOfferDescription(for: product) {
            print("Introductory offer: \(introDescription)")
        }

        do {
            // Purchase with intro offer automatically applied if eligible
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
                                "Plan": duration == .yearly ? "Annual" : "Monthly",
                                "Tier": tier.rawValue,
                                "Has Intro Offer": isEligibleForIntro
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

    @MainActor
    func restorePurchases(userEmail: String) async throws {
        print("Restoring purchases for \(userEmail)")
        try await AppStore.sync()
        await updateSubscriptionStatus()
        await fetchSubscriptionInfoIfNeeded(for: userEmail, force: true)
        Mixpanel.mainInstance().track(event: "Subscription Restore", properties: [
            "User Email": userEmail
        ])
    }

    // MARK: - Introductory Offer Methods

    @MainActor
    func checkIntroductoryOfferEligibility(for product: Product) async -> Bool {
        #if targetEnvironment(simulator)
        // In simulator, always show as eligible for testing
        return true
        #else
        // Check actual eligibility on device
        guard let subscription = product.subscription else { return false }
        return await subscription.isEligibleForIntroOffer
        #endif
    }

    @MainActor
    func getIntroductoryOfferDescription(for product: Product) async -> String? {
        print("🎁 Getting intro offer description for product: \(product.id)")

        let isEligible = await checkIntroductoryOfferEligibility(for: product)
        print("🎁 Is eligible: \(isEligible)")

        guard isEligible else {
            print("🎁 Not eligible for intro offer")
            return nil
        }

        guard let subscription = product.subscription else {
            print("🎁 No subscription property on product")
            return nil
        }

        guard let introOffer = subscription.introductoryOffer else {
            print("🎁 No introductory offer on subscription")
            return nil
        }

        print("🎁 Found intro offer with payment mode: \(introOffer.paymentMode)")
        print("🎁 Intro offer period: \(introOffer.period.value) \(introOffer.period.unit)")

        // Use if-else to avoid exhaustiveness issues with StoreKit enums
        if introOffer.paymentMode == .freeTrial {
            let period = introOffer.period
            if period.unit == .week && period.value == 1 {
                return "7 days free"
            } else if period.unit == .month && period.value == 1 {
                return "1 month free"
            } else {
                // Handle all period units
                let unitString: String
                switch period.unit {
                case .day:
                    unitString = period.value == 1 ? "day" : "days"
                case .week:
                    unitString = period.value == 1 ? "week" : "weeks"
                case .month:
                    unitString = period.value == 1 ? "month" : "months"
                case .year:
                    unitString = period.value == 1 ? "year" : "years"
                @unknown default:
                    unitString = "period"
                }
                return "\(period.value) \(unitString) free"
            }
        } else if introOffer.paymentMode == .payAsYouGo {
            return "Introductory offer available"
        } else if introOffer.paymentMode == .payUpFront {
            return "Special intro price"
        } else {
            return nil
        }
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

    private func product(for tier: SubscriptionTier, duration: SubscriptionDuration) -> Product? {
        guard let productId = tier.productIdentifier(for: duration) else {
            return nil
        }
        return products.first(where: { $0.id == productId })
    }

    func storeProduct(for tier: SubscriptionTier, duration: SubscriptionDuration) -> Product? {
        product(for: tier, duration: duration)
    }

    private func priceString(for tier: SubscriptionTier, duration: SubscriptionDuration) -> String {
        if tier == .none {
            return "Free"
        }

        if let product = product(for: tier, duration: duration) {
            return product.displayPrice
        }

        return tier.fallbackPrice(for: duration) ?? "Price unavailable"
    }

    func startingPrice(for tier: SubscriptionTier) -> String {
        let price = priceString(for: tier, duration: .monthly)
        return tier == .none ? price : "\(price)/month"
    }
      
    func annualPrice(for tier: SubscriptionTier) -> String {
        let price = priceString(for: tier, duration: .yearly)
        return tier == .none ? price : "\(price)/year"
    }
      
    func monthlyPrice(for tier: SubscriptionTier) -> String {
        let price = priceString(for: tier, duration: .monthly)
        return tier == .none ? price : "\(price)/month"
    }
      
    func annualBillingInfo(for tier: SubscriptionTier) -> String {
        let price = priceString(for: tier, duration: .yearly)
        return tier == .none ? price : "\(price) billed annually"
    }
      
    func monthlyBillingInfo(for tier: SubscriptionTier) -> String {
        let price = priceString(for: tier, duration: .monthly)
        return tier == .none ? price : "\(price) billed monthly"
    }

    func savingsPercentage(for tier: SubscriptionTier) -> Int {
        guard
            let monthlyProduct = product(for: tier, duration: .monthly),
            let yearlyProduct = product(for: tier, duration: .yearly)
        else {
            return 0
        }

        let monthlyPrice = NSDecimalNumber(decimal: monthlyProduct.price).doubleValue
        let yearlyPrice = NSDecimalNumber(decimal: yearlyProduct.price).doubleValue

        guard monthlyPrice > 0 else { return 0 }

        let annualisedMonthly = monthlyPrice * 12.0
        let savingsRatio = max(0, (annualisedMonthly - yearlyPrice) / annualisedMonthly)
        return Int((savingsRatio * 100).rounded())
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
    case humuliProMonthly = "Humuli Pro Monthly"
    case humuliProYearly = "Humuli Pro Yearly"
    case teamMonthly = "Pods Team Monthly"
    case teamYearly = "Pods Team Yearly"

    static var allProductIdentifiers: [String] {
        var identifiers = Set<String>()
        for tier in SubscriptionTier.allCases {
            if let monthly = tier.productIdentifier(for: .monthly) {
                identifiers.insert(monthly)
            }
            if let yearly = tier.productIdentifier(for: .yearly) {
                identifiers.insert(yearly)
            }
        }
        return Array(identifiers)
    }

    var name: String {
        switch self {
        case .none:
            return "Free"
        case .humuliProMonthly, .humuliProYearly:
            return "Humuli Pro"
        case .teamMonthly, .teamYearly:
            return "Pods Team"
        }
    }

    func productIdentifier(for duration: SubscriptionDuration) -> String? {
        switch self {
        case .humuliProMonthly, .humuliProYearly:
            return duration == .monthly ? "humuli_pro_monthly" : "humuli_pro_yearly"
        case .teamMonthly, .teamYearly, .none:
            return nil
        }
    }

    func fallbackPrice(for duration: SubscriptionDuration) -> String? {
        switch (self, duration) {
        case (.humuliProMonthly, .monthly), (.humuliProYearly, .monthly):
            return "$19.99"
        case (.humuliProMonthly, .yearly), (.humuliProYearly, .yearly):
            return "$95.99"
        case (.teamMonthly, .monthly), (.teamYearly, .monthly):
            return "$44.99"
        case (.teamMonthly, .yearly), (.teamYearly, .yearly):
            return "$419.99"
        case (.none, _):
            return "Free"
        }
    }

    var features: [String] {
        switch self {
        case .none:
            return [
                "Limited AI scans",
                "Basic meal logging",
                "Standard insights"
            ]
        case .humuliProMonthly, .humuliProYearly:
            return [
                "Unlimited food scans",
                "Voice & barcode logging",
                "Advanced nutrition analytics",
                "AI-generated meal plans",
                "Workout and Health integrations",
                "Priority support"
            ]
        case .teamMonthly, .teamYearly:
            return [
                "Team dashboards & analytics",
                "Per-seat billing with shared credits",
                "Advanced collaboration tools",
                "Extended activity history",
                "Custom branding & exports",
                "Priority onboarding"
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
