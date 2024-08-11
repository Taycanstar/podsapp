
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
}
