import Foundation
import Combine

@MainActor
final class ProfileRepository: ObservableObject {
    static let shared = ProfileRepository()

    @Published private(set) var profile: ProfileDataResponse?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false

    private var currentEmail: String?
    private let store = UserContextStore.shared
    private let service = UserProfileService.shared

    private init() {}

    func configure(email: String) {
        guard currentEmail != email else { return }
        currentEmail = email

        if let cached: CachedEntry<ProfileDataResponse> = store.load(ProfileDataResponse.self,
                                                                     for: UserScopedKey(email: email, domain: .profile)) {
            profile = cached.value
            lastUpdated = cached.updatedAt
            syncStreak(from: cached.value)
        }
    }

    func refresh(force: Bool = false) async {
        guard let email = currentEmail else { return }

        if isRefreshing {
            return
        }

        if !force,
           let lastUpdated,
           cachedIsFresh(lastUpdated: lastUpdated, ttl: RepositoryTTL.profile) {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        await service.refreshProfileDataIfNeeded(userEmail: email, force: force)

        if let latest = service.profileData {
            applyProfileUpdate(latest, email: email)
        }
    }

    private func cachedIsFresh(lastUpdated: Date, ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(lastUpdated) < ttl
    }

    private func applyProfileUpdate(_ profile: ProfileDataResponse, email: String) {
        self.profile = profile
        lastUpdated = Date()
        store.save(CachedEntry(value: profile, updatedAt: lastUpdated!),
                   for: UserScopedKey(email: email, domain: .profile))
        syncStreak(from: profile)
    }

    private func syncStreak(from profile: ProfileDataResponse) {
        if let currentStreak = profile.currentStreak,
           let longestStreak = profile.longestStreak,
           let streakAsset = profile.streakAsset {
            let streakData = UserStreakData(
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                streakAsset: streakAsset,
                lastActivityDate: profile.lastActivityDate,
                streakStartDate: profile.streakStartDate
            )
            StreakManager.shared.syncFromServer(streakData: streakData)
        }
    }
}
