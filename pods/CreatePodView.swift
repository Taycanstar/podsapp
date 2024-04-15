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


    var body: some View {
        VStack {
            header
            PlaceholderTextView(placeholder: "Pod name", text: $podName)
            itemList
            createButton
            Spacer()
        }
        .background(Color.white)
    }

    private var header: some View {
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
    }

    private var itemList: some View {
        List {
            ForEach($pod.items, id: \.videoURL) { $item in
                HStack {
                    ColoredPlaceholderTextField(placeholder: "Element name", text: $item.metadata, placeholderColor: Color(red: 0.9, green: 0.9, blue: 0.9))
                        .foregroundColor(.black)
                        .background(Color.white)
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
            .background(Color(red: 70/255, green: 87/255, blue: 245/255))
            .cornerRadius(8)

        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .overlay(Divider().opacity(0.5), alignment: .top)
      
    }

    private func createPodAction() {
        guard !podName.isEmpty else {
            print("Pod name is required.")
            return
        }
        isLoading = true // Start loading
        let startTime = Date()

        let items = pod.items.map { PodItem(id: $0.id, videoURL: $0.videoURL, image: $0.image, metadata: $0.metadata, thumbnail: $0.thumbnail, itemType: $0.itemType) }
        
        networkManager.createPod(podTitle: podName, items: items, email: viewModel.email) { success, message in
            let endTime = Date() // End time
            let duration = endTime.timeIntervalSince(startTime)
            DispatchQueue.main.async {
                isLoading = false // Stop loading
                if success {
                    self.showingVideoCreationScreen = false 
                    print("Pod created successfully in \(duration) seconds.")
                    
                } else {
                    print("Failed to create pod: \(message ?? "Unknown error")")
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
