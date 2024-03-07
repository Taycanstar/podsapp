
import SwiftUI

class OnboardingViewModel: ObservableObject {
    enum OnboardingStep {
        case landing
        case signup
        case emailVerification(email: String)
        case info(email: String)
    }

    @Published var currentStep: OnboardingStep = .landing
    @Published var email: String = ""
}
