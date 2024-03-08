import SwiftUI

struct WelcomeView: View {
    @State private var password: String = ""
    @State private var email: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.presentationMode) var presentationMode
    @Binding var isAuthenticated: Bool

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
                   
                    .frame(minHeight: geometry.size.height - 50) // Reserve space for the button

                    continueButton
                       
                }
            }
            .padding(.bottom, 25)
            .navigationBarHidden(true)
        }
        .navigationBarBackButtonHidden(true)
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
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome to Podstack")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Improve your daily life by becoming more organized and creative")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
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
                            Text(item.subtitle)
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        Spacer() // Push content to the left
                    }
                    .padding(.vertical, 5) // Optional padding for each row
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }

    private var continueButton: some View {
        Button(action: {
            let networkManager = NetworkManager()
                     networkManager.login(email: viewModel.email, password: viewModel.password) { success, _ in
                         if success {
                             // If login is successful, update the authenticated state
                             DispatchQueue.main.async {
                                 self.isAuthenticated = true
                                 self.viewModel.password = ""
                             }
                         } else {
                             // Handle login failure, e.g., by showing an error message
                             self.errorMessage = "Login failed. Please check your credentials and try again."
                         }
                     }
        }) {
            Text("Continue")
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 70/255, green: 87/255, blue: 245/255))
                .cornerRadius(10)
        }
        .padding(.horizontal)
        
        .frame(height: 50) // Specify the height of the button area to ensure it's always visible
    }
    
    // Sample data structure for the info section
    private let infoData = [
        InfoItem(icon: "record.circle", title: "Create video-based intuitive collections", subtitle: "Begin by recording a video, choosing one from your camera roll, or capturing your screen.", color: .red),
        InfoItem(icon: "film.stack.fill", title: "Stack Pods", subtitle: "Organize your collection into Pods that contain your videos", color:.green),
        InfoItem(icon: "sparkles", title: "Automate", subtitle: "Each video inside a pod uses AI to trancribe the audio into readable text", color: Color(red: 70/255, green: 87/255, blue: 245/255))
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
