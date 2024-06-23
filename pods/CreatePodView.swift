import SwiftUI

struct CreatePodView: View {
    @State var podName: String = ""
    @Binding var pod: Pod
    @Environment(\.presentationMode) var presentationMode
    var networkManager: NetworkManager = NetworkManager()
    @State private var isLoading = false
    @EnvironmentObject var viewModel: OnboardingViewModel
    @StateObject var cameraModel = CameraViewModel()
    @Binding var showingVideoCreationScreen: Bool
    @Binding var selectedTab: Int
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            header
            PlaceholderTextView(placeholder: "Pod name", text: $podName)
            itemList
            if let errorMessage = errorMessage {
                           Text(errorMessage)
                               .foregroundColor(.red)
                               .padding(.horizontal, 15)
                               .padding(.top, 5)
                               .onAppear {
                                   DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                       self.errorMessage = nil
                                   }
                               }
                       }
            createButton
            Spacer()
        }
//        .background(Color.white)
    }

    private var header: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.backward")
//                    .foregroundColor(.black)
                    .font(.system(size: 20))
            }
            Spacer()
            Text("Create Pod")
                .font(.system(size: 18))
                .fontWeight(.bold)
//                .foregroundColor(.black)
            Spacer()
        }
        .padding()
    }

    private var itemList: some View {
        List {
            ForEach($pod.items, id: \.id) { $item in
                HStack {

                    DynamicTextField(text: $item.metadata,  placeholder: "Item \($item.id.wrappedValue)")
                    
                
                    Spacer()
                    Image(uiImage: item.thumbnail ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
//                .listRowBackground(Color.white)
            }
        }
        .listStyle(PlainListStyle())
    }

    private var createButton: some View {
        VStack {
//            Spacer() // Use to push everything up
            Button(action: createPodAction) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1)
                } else {
                    Text("Create")
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .foregroundColor(.white)
            .background(Color(rgb: 71, 98, 246
                                ))
            .cornerRadius(8)

        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .overlay(Divider().opacity(0.5), alignment: .top)
      
    }

    private func createPodAction() {
        guard !podName.isEmpty else {
            print("Pod name is required.")
            errorMessage = "Pod name is required."
            return
        }
        self.showingVideoCreationScreen = false 
        isLoading = true // Start loading
        if let thumbnail = pod.items.last?.thumbnail {
               uploadViewModel.startUpload(withThumbnail: thumbnail)
           }
        
        let startTime = Date()
//
//        let items = pod.items.map { PodItem(id: $0.id, videoURL: $0.videoURL, image: $0.image, metadata: $0.metadata, thumbnail: $0.thumbnail, itemType: $0.itemType) }
        let items = pod.items.map { item -> PodItem in
               let metadata = item.metadata.isEmpty ? "Item \(item.id)" : item.metadata
               return PodItem(id: item.id, videoURL: item.videoURL, image: item.image, metadata: metadata, thumbnail: item.thumbnail, itemType: item.itemType)
           }
        
        networkManager.createPod(podTitle: podName, items: items, email: viewModel.email) { success, message in
            let endTime = Date() // End time
            let duration = endTime.timeIntervalSince(startTime)
            DispatchQueue.main.async {
                isLoading = false // Stop loading
                if success {
                   
                    print("Pod created successfully in \(duration) seconds.")
                    uploadViewModel.uploadCompleted()
                    selectedTab = 0
          
//                    self.homeViewModel.fetchPodsForUser(email: self.viewModel.email)
                    
                } else {
                    print("Failed to create pod: \(message ?? "Unknown error")")
                    errorMessage = "\(String(describing: message))"
                }
             
            }
        }
    }
}

struct PlaceholderTextView: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .font(.system(size: 28, design: .rounded).bold())
                    .padding(.horizontal, 15)
            }
            TextField("", text: $text)
                .font(.system(size: 28, design: .rounded).bold())
                .padding(.horizontal, 15)
                .foregroundColor(Color(rgb: 71, 98, 246
                                         ))
         
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


struct DynamicTextField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        ZStack(alignment: .leading) {
            TextEditor(text: $text)
                .background(Color.clear)
                .padding(.top, 10)
                .padding(.leading, -5)

            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .allowsHitTesting(false)
            }
        }
   
        .frame(minHeight: 10, maxHeight: .infinity) // Ensuring a fixed height for the entire row
    }
}

