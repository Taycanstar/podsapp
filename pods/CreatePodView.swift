import SwiftUI


struct CreatePodView: View {
    @State var podName: String = ""
    @Binding var pod: Pod
    @Environment(\.presentationMode) var presentationMode
    var networkManager: NetworkManager = NetworkManager()
    @State private var isLoading = false
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack {
            // Header
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.backward")
                        .foregroundColor(.black)
                        .font(.system(size: 20))
                }
                Spacer()
                Text("Create Pod")
                    .font(.system(size: 18))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
            }
            .padding()

            // Pod Name Input

                PlaceholderTextView(placeholder: "Pod name", text: $podName)
                

            // List of Items
            List {
                ForEach($pod.items, id: \.videoURL) { $item in
                    HStack {
                        ColoredPlaceholderTextField(placeholder: "Element name", text: $item.metadata, placeholderColor: Color(red: 0.9, green: 0.9, blue: 0.9))
                                        .foregroundColor(.black)
                            .background(Color.white) // Explicitly set background to white
                          
                         
                        Spacer()

                        Image(uiImage: item.thumbnail ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
        
                              
                                    .listRowBackground(Color.white)
                }
            }
            .listStyle(PlainListStyle()) // Use plain style for list
    


            HStack { // Embed in HStack for padding
                Spacer() // Push button left
                Button(action: {
                  
                    guard !podName.isEmpty else {
                        print("Pod name is required.")
                        return
                    }
                    print("create tapped")
                    isLoading = true // Start loading
                    
                    let items = pod.items.map { item -> PodItem in
                        return PodItem(id: item.id, videoURL: item.videoURL, metadata: item.metadata, thumbnail: item.thumbnail)
                    }
                    
                    networkManager.createPod(podTitle: podName, items: items, email: viewModel.email) { success, message in
                        DispatchQueue.main.async {
                            isLoading = false // Stop loading
                            if success {
                                print("upload succesful")
                                print("email", viewModel.email)
                                self.presentationMode.wrappedValue.dismiss()
                            } else {
                                // Optionally show an error message to the user
                                print("Failed to create pod: \(message ?? "Unknown error")")
                            }
                        }
                    }
                }) {
                    Group {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        } else {
                            Text("Create")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity) // Full width within HStack
                .padding() // Add padding around the button content
                .foregroundColor(.white)
                .background(Color(red: 70/255, green: 87/255, blue: 245/255))
                .cornerRadius(8)
                .contentShape(Rectangle())
//                .disabled(isLoading)
                
               
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .overlay(alignment: .top) { // Apply overlay to the HStack for a top border
                Divider()
                    .opacity(0.5) // Adjust opacity if needed
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      
        .background(Color.white)
    }
}


struct PlaceholderTextView: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(red: 0.9, green: 0.9, blue: 0.9))
                    .font(.system(size: 28, design: .rounded).bold())
                    .padding(.horizontal, 15)
            }
            TextField("", text: $text)
                .font(.system(size: 28, design: .rounded).bold())
                .padding(.horizontal, 15)
                .foregroundColor(Color(red: 70/255, green: 87/255, blue: 245/255))
        }
        .frame(maxWidth: .infinity, maxHeight: 30) // Set a fixed height
    }
}


struct ColoredPlaceholderTextField: View {
    var placeholder: String
    @Binding var text: String
    var placeholderColor: Color = .gray // Default color

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(placeholderColor)
                    .font(.system(size: 18))
                    .padding(.leading, 4)
            }
            TextField("", text: $text)
                .font(.system(size: 16))
                .padding(.leading, 4)
             
        }
    }
}
