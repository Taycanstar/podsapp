import SwiftUI
import StoreKit

class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    private var onboardingViewModel: OnboardingViewModel?
    private var lastKnownSubscriptionStatuses: [String: String] = [:]
    private var timer: Timer?
    init() {
        Task {
            await fetchProducts()
            await updatePurchasedSubscriptions()
            await listenForTransactions()
        }
        startPeriodicCheck()
    }
    func setOnboardingViewModel(_ viewModel: OnboardingViewModel) {
            self.onboardingViewModel = viewModel
        }
    
    private func startPeriodicCheck() {
            DispatchQueue.main.async { [weak self] in
                self?.timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { _ in
                    Task { [weak self] in
                        await self?.checkCurrentEntitlements()
                    }
                }
            }
        }
    deinit {
          timer?.invalidate()
      }
    @MainActor
     func forceSubscriptionCheck() async {
         print("Forcing subscription check...")
         await checkAndUpdateSubscriptionStatus()
         print("Force subscription check completed.")
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
            
            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    print("Purchase success: \(transaction.productID)")
                    await handleVerifiedTransaction(transaction)
                    await syncPurchaseWithBackend(productId: transaction.productID, userEmail: userEmail, onboardingViewModel: onboardingViewModel)
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
    
    func syncPurchaseWithBackend(productId: String, userEmail: String, onboardingViewModel: OnboardingViewModel) async {
        let networkManager = NetworkManager()
        do {
            let purchaseResult = try await networkManager.purchaseSubscription(
                userEmail: userEmail,
                productId: productId,
                transactionId: UUID().uuidString
            )
            
            print("Backend sync result: \(purchaseResult)")
            
            await MainActor.run {
                onboardingViewModel.updateSubscriptionInfo(
                    status: purchaseResult["status"] as? String ?? "active",
                    plan: purchaseResult["plan_name"] as? String,
                    expiresAt: purchaseResult["end_date"] as? String,
                    renews: purchaseResult["renews"] as? Bool ?? true,
                    seats: purchaseResult["seats"] as? Int,
                    canCreateNewTeam: purchaseResult["can_create_new_team"] as? Bool ?? false
                )
            }
            
            NotificationCenter.default.post(name: .subscriptionUpdated, object: nil)
        } catch {
            print("Failed to sync purchase with backend: \(error)")
        }
    }

    @MainActor
      private func handleTransactionUpdate(_ transaction: StoreKit.Transaction) async {
          print("Handling transaction update for product: \(transaction.productID)")
          
          let status: String
          let willRenew: Bool
          
          if let revocationDate = transaction.revocationDate {
              print("Cancellation detected for product: \(transaction.productID), Revocation Date: \(revocationDate)")
              status = "cancelled"
              willRenew = false
          } else if let expirationDate = transaction.expirationDate, expirationDate < Date() {
              print("Subscription expired for product: \(transaction.productID), Expiration Date: \(expirationDate)")
              status = "expired"
              willRenew = false
          } else {
              print("Active subscription for product: \(transaction.productID)")
              status = "active"
              willRenew = await checkIfSubscriptionWillRenew(transaction)
          }

          print("Final Subscription status: \(status), Will Renew: \(willRenew), Product ID: \(transaction.productID)")
          await updateBackendSubscriptionStatus(productId: transaction.productID, status: status, willRenew: willRenew, expirationDate: transaction.expirationDate)
      }
    

    private func checkIfSubscriptionWillRenew(_ transaction: StoreKit.Transaction) async -> Bool {
            guard let statuses = try? await Product.SubscriptionInfo.status(for: transaction.productID) else {
                return false
            }
            
            for status in statuses {
                switch status.state {
                case .subscribed:
                    if case .verified(let renewalInfo) = status.renewalInfo {
                        return renewalInfo.willAutoRenew
                    }
                case .inGracePeriod:
                    if case .verified(let renewalInfo) = status.renewalInfo {
                        return renewalInfo.willAutoRenew
                    }
                case .inBillingRetryPeriod:
                    if case .verified(let renewalInfo) = status.renewalInfo {
                        return renewalInfo.willAutoRenew
                    }
                case .expired:
                    continue
                case .revoked:
                    continue
                default:
                    print("Unknown subscription state for \(transaction.productID)")
                    continue
                }
            }
            
            return false
        }


        @MainActor
         func checkCurrentEntitlements() async {
            print("Checking current entitlements...")
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    await handleTransactionUpdate(transaction)
                }
            }
            print("Current entitlements check completed.")
        }

      @MainActor
      func checkAndUpdateSubscriptionStatus() async {
          print("Checking subscription status...")
          let currentEntitlements = await Transaction.currentEntitlements
          for await result in currentEntitlements {
              if case .verified(let transaction) = result {
                  await handleTransactionUpdate(transaction)
              }
          }
          print("Subscription check completed.")
      }


    private func updateBackendSubscriptionStatus(productId: String, status: String, willRenew: Bool, expirationDate: Date?) async {
          print("Updating backend for product: \(productId), status: \(status), willRenew: \(willRenew), expiration: \(String(describing: expirationDate))")
          let networkManager = NetworkManager()
          do {
              let result = try await networkManager.updateSubscriptionStatus(
                  userEmail: UserDefaults.standard.string(forKey: "userEmail") ?? "",
                  productId: productId,
                  status: status,
                  willRenew: willRenew,
                  expirationDate: expirationDate?.ISO8601Format()
              )
              print("Backend update result: \(result)")
              
              // Update local state based on the backend response
              await MainActor.run { [weak self] in
                  self?.onboardingViewModel?.updateSubscriptionInfo(
                      status: result["new_status"] as? String ?? status,
                      plan: result["plan_name"] as? String,
                      expiresAt: result["end_date"] as? String,
                      renews: result["renews"] as? Bool ?? willRenew,
                      seats: (result["team"] as? [String: Any])?["seats"] as? Int,
                      canCreateNewTeam: result["is_team_plan"] as? Bool ?? false
                  )
              }
          } catch {
              print("Failed to update subscription status on backend: \(error)")
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

extension Notification.Name {
    static let subscriptionPurchased = Notification.Name("subscriptionPurchased")
    static let subscriptionUpdated = Notification.Name("subscriptionUpdated")
}
