import SwiftUI

struct MainOnboardingView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Binding var isAuthenticated: Bool

    var body: some View {
        switch viewModel.currentStep {
        case .landing:
            LandingView(isAuthenticated: $isAuthenticated) // Assuming LandingView is modified to use viewModel
        case .signup:
            SignupView()
        case .emailVerification:
            EmailVerificationView() // Modified to not require passing email as a parameter
        case .info:
            InfoView()
        case .login:
            LoginView(isAuthenticated: $isAuthenticated)
        case .welcome:
            WelcomeView(isAuthenticated: $isAuthenticated)
        }
   
    
    }
}



