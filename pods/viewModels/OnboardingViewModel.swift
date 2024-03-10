
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
    @Published var email: String = "dimi@humuli.com"
    @Published var password: String = ""
}
