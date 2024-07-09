
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
    @State private var showOptionsSheet: Bool = false
    @State private var selectedOption: String = "Create pod"
    @State private var showPodSelectionSheet: Bool = false
    @State private var selectedPod: Pod?
    @Binding var showCreatePodView: Bool
    @Binding var showPreview: Bool


    var body: some View {
        
  
            
            
            VStack {
                header
                if selectedOption == "Create pod" {
                    PlaceholderTextView(placeholder: "Pod name", text: $podName)
                }
                
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
            
            .background(Color(UIColor.systemBackground))
            .sheet(isPresented: $showOptionsSheet) {
                OptionsSheetView(showOptionsSheet: $showOptionsSheet, selectedOption: $selectedOption, showPodSelectionSheet: $showPodSelectionSheet)
                    .presentationDetents([.height(UIScreen.main.bounds.height / 4)])
            }
            
            .sheet(isPresented: $showPodSelectionSheet) {
                PodSelectionView(selectedPod: $selectedPod, showPodSelectionSheet: $showPodSelectionSheet, selectedOption: $selectedOption)
                    .environmentObject(homeViewModel)
                    .environmentObject(viewModel)
                
            }
        
    }


    private var header: some View {
        HStack {
            Button(action: {
                showCreatePodView = false
                showPreview = true
            }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 20))
            }
            Spacer()
            HStack {
                Text(selectedOption)
                    .font(.system(size: 18))
                    .fontWeight(.bold)
                Button(action: {
                    showOptionsSheet.toggle()
                }) {
                    Image(systemName: showOptionsSheet || showPodSelectionSheet ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
            }
            .onTapGesture {
                showOptionsSheet.toggle()
            }
            Spacer()
        }
        .padding()
    }

       private var itemList: some View {
           List {
               ForEach(Array(pod.items.enumerated()), id: \.element.id) { index, item in
                   HStack {
                       VStack(alignment: .leading, spacing: 0) {
                           DynamicTextField(text: $pod.items[index].metadata, placeholder: "Item \(item.id)")

                               DynamicTextFieldNotes(text: $pod.items[index].notes, placeholder: "Add note")

                       }
                       Spacer()
                       Image(uiImage: item.thumbnail ?? UIImage())
                           .resizable()
                           .aspectRatio(contentMode: .fill)
                           .frame(width: 40, height: 40)
                           .clipShape(RoundedRectangle(cornerRadius: 8))
                   }
                   .contentShape(Rectangle())
               }
           }
           .listStyle(PlainListStyle())
       }

    private var createButton: some View {

            VStack {
                //            Spacer() // Use to push everything up
                Button(action: selectedOption == "Create pod" ? createPodAction : addItemsToPod) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1)
                    } else {
                        
                        Text(selectedOption == "Create pod" ? "Create" : "Add to pod")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .foregroundColor(.white)
                .background(Color(red: 35/255, green: 108/255, blue: 255/255))
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
        let items = pod.items.map { item -> PodItem in
               let metadata = item.metadata.isEmpty ? "Item \(item.id)" : item.metadata
            let notes = item.notes.isEmpty ? "Add note" : item.notes
            return PodItem(id: item.id, videoURL: item.videoURL, image: item.image, metadata: metadata, thumbnail: item.thumbnail, itemType: item.itemType, notes: notes)
           }
        
        networkManager.createPod(podTitle: podName, items: items, email: viewModel.email) { success, message in
            let endTime = Date() // End time
            let duration = endTime.timeIntervalSince(startTime)
            DispatchQueue.main.async {
                isLoading = false // Stop loading
                if success {
                   
                    print("Pod created successfully in \(duration) seconds.")
                    uploadViewModel.uploadCompleted()
                    homeViewModel.refreshPods(email: viewModel.email) {
                                      // Additional actions after refresh if needed
                                  }
                    selectedTab = 0
                } else {
                    print("Failed to create pod: \(message ?? "Unknown error")")
                    errorMessage = "\(String(describing: message))"
                }
             
            }
        }
    }
    
    private func addItemsToPod() {
        guard let selectedPod = selectedPod else {
              print("No pod selected.")
              errorMessage = "No pod selected."
              return
          }
          self.showingVideoCreationScreen = false
          isLoading = true // Start loading
          if let thumbnail = pod.items.last?.thumbnail {
              uploadViewModel.startUpload(withThumbnail: thumbnail)
          }
          
          let startTime = Date()
          let items = pod.items.map { item -> PodItem in
              let metadata = item.metadata.isEmpty ? "Item \(item.id)" : item.metadata
              let notes = item.notes.isEmpty ? "" : item.notes
              return PodItem(id: item.id, videoURL: item.videoURL, image: item.image, metadata: metadata, thumbnail: item.thumbnail, itemType: item.itemType, notes: notes)
          }
          
          networkManager.addItemsToPod(podId: selectedPod.id, items: items) { success, message in
              let endTime = Date() // End time
              let duration = endTime.timeIntervalSince(startTime)
              DispatchQueue.main.async {
                  isLoading = false // Stop loading
                  if success {
                      print("Items added to pod successfully in \(duration) seconds.")
                      uploadViewModel.uploadCompleted()
                      homeViewModel.refreshPods(email: viewModel.email) {
                                        // Additional actions after refresh if needed
                                    }
                      selectedTab = 0
                  } else {
                      print("Failed to add items to pod: \(message ?? "Unknown error")")
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
                .foregroundColor(Color(red: 35/255, green: 108/255, blue: 255/255))
         
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
                .padding(.top, 0)
                .padding(.leading, -5)
                .font(.system(size: 17))

            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .allowsHitTesting(false)
            }
        }
        .padding(.vertical, 0)
        .background(.blue)
//        .frame(minHeight: 10, maxHeight: .infinity)
        .frame(height: 20)
    }
}

struct DynamicTextFieldNotes: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        ZStack(alignment: .leading) {
            TextEditor(text: $text)
                .background(Color.clear)
                .padding(.top, 0)
                .padding(.leading, -5)
                .font(.system(size: 14))
                .foregroundColor(.gray)

            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .font(.system(size: 14))
                    .allowsHitTesting(false)
            }
        }
        .padding(.vertical, 0)
//        .frame(minHeight: 10, maxHeight: .infinity)
        .frame(height: 31)
    }
}

struct OptionsSheetView: View {
    @Binding var showOptionsSheet: Bool
    @Binding var selectedOption: String
    @Binding var showPodSelectionSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Button(action: {
                selectedOption = "Create pod"
                showOptionsSheet = false
                
            }) {
                HStack {
                    Image(systemName: "plus.viewfinder")
                        .font(.system(size: 20))
                    Text("Create pod")
                        .padding(.horizontal, 10)
                       
                }
              
                .padding(.vertical, 8)
                .foregroundColor(Color(UIColor.label))
                .background(Color(UIColor.systemBackground))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            Button(action: {
//                selectedOption = "Add to Existing Pod"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                   showPodSelectionSheet = true
                               }
                showOptionsSheet = false
             
            }) {
                HStack {
                    Image(systemName: "memories.badge.plus")
                        .font(.system(size: 20))
                    Text("Add to existing pod")
                        .padding(.horizontal, 10)
                      
                }
                
                .padding(.vertical, 8)
                .foregroundColor(Color(UIColor.label))
                .background(Color(UIColor.systemBackground))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 45)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
    }
}



struct PodSelectionView: View {
    @Binding var selectedPod: Pod?
    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Binding var showPodSelectionSheet: Bool
    @Binding var selectedOption: String

    var body: some View {
        VStack {
            Text("Select a Pod")
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 20)
            Divider()
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(homeViewModel.pods) { pod in
                        Button(action: {
                            selectedPod = pod
                            selectedOption = pod.title
                            showPodSelectionSheet = false
                        }) {
                            Text(pod.title)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 15)
                                .foregroundColor(Color(UIColor.label))
                                .background(Color(UIColor.systemBackground))
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                    }
                }
            }
            .padding(.leading, 15)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
    }
}


