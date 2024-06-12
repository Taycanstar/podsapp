import SwiftUI

struct WelcomeView: View {
    @State private var password: String = ""
    @State private var email: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.presentationMode) var presentationMode
    @Binding var isAuthenticated: Bool
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack {
                    ScrollView {
                        VStack {
                            topBar
                            logo
                            formSection
                            infoSection
                            Spacer(minLength: 0) // Use a spacer to push everything up
                        }
                    }
                    .background(Color.white)
                    .frame(minHeight: geometry.size.height - 50) // Reserve space for the button

                    continueButton
                       
                       
                }
              
                .background(Color.white)
            }
            .background(Color.white)
//            .padding(.bottom, 25)
            .navigationBarHidden(true)
        }
        
        .navigationBarBackButtonHidden(true)
        .background(Color.white)
//        .preferredColorScheme(.light)
    }
    

    private var topBar: some View {
        HStack {
            Button("Sign out") {
                viewModel.currentStep = .landing
            }
            .foregroundColor(Color(red: 70/255, green: 87/255, blue: 245/255))
            .padding()
            Spacer()
        }
        .background(Color.white)
    }

    private var logo: some View {
        HStack {
            Spacer()
            Image("black-logo") // Make sure the logo image is added to your asset catalog
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
            Spacer()
        }
        .background(Color.white)
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome to Podstack")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.black)
            
            Text("Improve your daily life by becoming more organized and creative")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .background(Color.white)
        .padding(.horizontal)
    }
    
    private var infoSection: some View {
            VStack(alignment: .leading, spacing: 15) { // Adjust spacing as needed
                ForEach(infoData) { item in
                    HStack {
                        ZStack{
                            Image(systemName: item.icon)
                                .foregroundColor(item.color) // Adjust color as needed
                                .frame(width: 40, height: 40)
                            Spacer()
                        }
                       
                           
                        VStack(alignment: .leading) {
                            Text(item.title)
                                .fontWeight(.semibold)
                                .font(.system(size: 17))
                                .foregroundColor(.black)
                            Text(item.subtitle)
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                
                        }
                        Spacer() // Push content to the left
                    }
                    .background(Color.white)
                    .padding(.vertical, 5) // Optional padding for each row
                }
                .background(Color.white)
            }
            .background(Color.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }
    
    
    private var continueButton: some View {
        Button(action: {
            isLoading = true // Start loading animation
            authenticateUser() // Call your authentication function
        }) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1, anchor: .center) // Scale your progress view as needed
                } else {
                    Text("Continue")
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(red: 70/255, green: 87/255, blue: 245/255))
            .cornerRadius(10)
        }
        .disabled(isLoading) // Disable the button while loading
//        .padding()
        .padding(.bottom, 35)
        .padding(.horizontal)
        .frame(height: 50) // Keep your button area height as is
        
    }
    
    private func authenticateUser() {
        let authenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        let networkManager = NetworkManager()
        if authenticated {
            viewModel.currentStep = .landing
            self.isAuthenticated = true
        } else {
           
            networkManager.login(username: viewModel.username, password: viewModel.password) { success, _ in
                DispatchQueue.main.async {
                    isLoading = false // Stop loading animation
                    if success {
                        self.isAuthenticated = true
                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
                        UserDefaults.standard.set(email, forKey: "userEmail")
                        viewModel.email = email
                        self.viewModel.password = ""
                        viewModel.currentStep = .landing
                    } else {
                        // Handle login failure
                        self.errorMessage = "Login failed. Please check your credentials and try again."
                    }
                }
            }
        }

       
    }

    
    // Sample data structure for the info section
    private let infoData = [
        InfoItem(icon: "record.circle", title: "Organize with video", subtitle: "Create video-integrated ordered collections", color: .red),
        InfoItem(icon: "film.stack.fill", title: "Stack Pods", subtitle: "Stack collections called pods, each containing video items", color:.green),
        InfoItem(icon: "waveform", title: "Transcribe videos", subtitle: "Automate item labeling by converting audio within the video into text", color: Color(red: 70/255, green: 86/255, blue: 246/255)),
//        InfoItem(icon: "mic.fill", title: "Hands-free controls", subtitle: "Use voice commands: Say 'Start recording' and 'Stop recording'", color: Color(red: 70/255, green: 86/255, blue: 246/255))
    ]
        
}

struct InfoItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
}

//struct WelcomeView_Previews: PreviewProvider {
//    static var previews: some View {
//        WelcomeView().environmentObject(OnboardingViewModel())
//    }
//}
