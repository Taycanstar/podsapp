import SwiftUI

struct StartupView: View {
    private let backgroundColor = Color.black
    @Binding var isAuthenticated: Bool
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    
                    Image("logo-bkv2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                    
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Button {
                            viewModel.newOnboardingStepIndex = 1
                            viewModel.currentStep = .fitnessGoal
                        } label: {
                            Text("Get started")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                // .background(Color.accentColor)
                                .background(.black)
                                .foregroundColor(.white)
                                .cornerRadius(36)
                        }
                        
                        NavigationLink {
                            LandingView(isAuthenticated: $isAuthenticated, showEmailOption: false)
                        } label: {
                            Text("Log in")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.black)
                                .cornerRadius(36)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 48)
                    .padding(.bottom, 72)
                    .background(Color.white.cornerRadius(32, corners: [.topLeft, .topRight]))
                }
                .edgesIgnoringSafeArea(.all)
            }
            .padding(.bottom, 1)
            .preferredColorScheme(.light)
            .ignoresSafeArea()
        }
        .opacity(isAuthenticated ? 0 : 1)
    }
}

struct StartupView_Previews: PreviewProvider {
    static var previews: some View {
        StartupView(isAuthenticated: .constant(false))
            .environmentObject(OnboardingViewModel())
    }
}
