import Foundation
import Combine

@MainActor
final class SubscriptionRepository: ObservableObject {
    static let shared = SubscriptionRepository()

    @Published private(set) var subscription: SubscriptionInfo?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false

    private var currentEmail: String?
    private weak var onboardingViewModel: OnboardingViewModel?
    private weak var manager: SubscriptionManager?
    private let store = UserContextStore.shared

    private init() {}

    func configure(email: String,
                   onboarding: OnboardingViewModel,
                   manager: SubscriptionManager) {
        self.onboardingViewModel = onboarding
        self.manager = manager
        manager.setOnboardingViewModel(onboarding)

        guard currentEmail != email else { return }

        manager.clearSubscriptionState()
        subscription = nil
        lastUpdated = nil
        currentEmail = email

        if let cached: CachedEntry<SubscriptionInfo> = store.load(SubscriptionInfo.self,
                                                                  for: UserScopedKey(email: email, domain: .subscription)) {
            subscription = cached.value
            lastUpdated = cached.updatedAt
            manager.subscriptionInfo = cached.value
        }
    }

    func refresh(force: Bool = false) async {
        guard let email = currentEmail, let manager else { return }

        if isRefreshing {
            return
        }

        if !force,
           let lastUpdated,
           Date().timeIntervalSince(lastUpdated) < RepositoryTTL.subscription {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        await manager.fetchSubscriptionInfoIfNeeded(for: email, force: force)

        if let latest = manager.subscriptionInfo {
            subscription = latest
            lastUpdated = Date()
            store.save(CachedEntry(value: latest, updatedAt: lastUpdated!),
                       for: UserScopedKey(email: email, domain: .subscription))
        }
    }
}
