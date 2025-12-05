import Foundation
import Combine
import SwiftUI

@MainActor
final class StartupCoordinator: ObservableObject {
    static let shared = StartupCoordinator()

    enum StartupState: Equatable {
        case idle
        case waitingForUser
        case loading
        case warming
        case ready
    }

    @Published private(set) var state: StartupState = .idle

    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var currentEmail: String?
    private var lastBootstrapDate: Date?
    private let minimumBootstrapInterval: TimeInterval = 30 // seconds

    private let profileRepository = ProfileRepository.shared
    private let subscriptionRepository = SubscriptionRepository.shared
    private let foodRepository = FoodFeedRepository.shared
    private let dayLogsRepository = DayLogsRepository.shared
    private var cancellables: Set<AnyCancellable> = []

    private init() {}

    func bootstrapIfNeeded(onboarding: OnboardingViewModel,
                           foodManager: FoodManager,
                           dayLogs: DayLogsViewModel,
                           subscriptionManager: SubscriptionManager) {
        let email = resolveEmail(from: onboarding)

        guard let email else {
            state = .waitingForUser
            return
        }

        let shouldSkip: Bool
        if currentEmail == email,
           let lastBootstrapDate,
           Date().timeIntervalSince(lastBootstrapDate) < minimumBootstrapInterval,
           state == .ready {
            shouldSkip = true
        } else {
            shouldSkip = false
        }

        guard !shouldSkip else { return }

        currentEmail = email
        lastBootstrapDate = Date()
        state = .loading

        subscriptionManager.setOnboardingViewModel(onboarding)
        profileRepository.configure(email: email)
        subscriptionRepository.configure(email: email,
                                         onboarding: onboarding,
                                         manager: subscriptionManager)
        foodRepository.configure(email: email)
        onboarding.bindRepositories(for: email)

        subscriptionRepository.$subscription
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { info in
                subscriptionManager.subscriptionInfo = info
            }
            .store(in: &cancellables)

        if let cachedSubscription = subscriptionRepository.subscription {
            subscriptionManager.subscriptionInfo = cachedSubscription
        }

        foodManager.initialize(userEmail: email)
        onboarding.trySeedRemoteNutritionProfile()
        dayLogs.setEmail(email)
        dayLogs.preloadForStartup(email: email)

        state = .warming

        // CRITICAL FIX: Use Task { @MainActor in } to ensure all repository refreshes
        // and state updates happen on main thread
        Task { @MainActor [weak self] in
            guard let self else { return }

            async let profileTask: Void = self.profileRepository.refresh(force: false)
            async let subscriptionTask: Void = self.subscriptionRepository.refresh(force: false)
            async let foodTask: Bool = self.foodRepository.refresh(force: false)
            async let logsTask: Void = self.dayLogsRepository.refresh(date: dayLogs.selectedDate, force: false)

            _ = await profileTask
            _ = await subscriptionTask
            _ = await foodTask
            _ = await logsTask

            self.state = .ready
            self.resumeContinuations()
        }
    }

    func ready() async {
        if state == .ready {
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            continuations.append(continuation)
        }
    }

    private func resolveEmail(from onboarding: OnboardingViewModel) -> String? {
        if !onboarding.email.isEmpty {
            return onboarding.email
        }
        if let stored = UserDefaults.standard.string(forKey: "userEmail"), !stored.isEmpty {
            return stored
        }
        return nil
    }

    private func resumeContinuations() {
        guard !continuations.isEmpty else { return }
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }
}
