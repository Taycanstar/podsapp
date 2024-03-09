
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
    @Published var password: String = ""
}
