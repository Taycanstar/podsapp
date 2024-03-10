import SwiftUI

struct HomeView: View {

    @ObservedObject var cameraModel = CameraViewModel()
    @ObservedObject var homeViewModel = HomeViewModel()
    @EnvironmentObject var viewModel: OnboardingViewModel
    var networkManager: NetworkManager = NetworkManager()
    
    // Example Pods Data - Replace with actual data fetching mechanism
//    private let pods = [
//        Pod(items: [PodItem(videoURL: Bundle.main.url(forResource: "vid", withExtension: "mp4")!, metadata: "dummy data", thumbnail: UIImage(named: "livvy")),PodItem(videoURL: Bundle.main.url(forResource: "vid2", withExtension: "mov")!, metadata: "dummy data", thumbnail: UIImage(named: "livvy")), PodItem(videoURL: Bundle.main.url(forResource: "vid", withExtension: "mp4")!, metadata: "dummy data", thumbnail: UIImage(named: "livvy")), PodItem(videoURL: Bundle.main.url(forResource: "vid2", withExtension: "mov")!, metadata: "dummy data", thumbnail: UIImage(named: "livvy")), PodItem(videoURL: Bundle.main.url(forResource: "vid", withExtension: "mp4")!, metadata: "dummy data", thumbnail: UIImage(named: "livvy"))], title: "Pod 1"),
//        Pod(items: [PodItem(videoURL: Bundle.main.url(forResource: "vid2", withExtension: "mov")!, metadata: "Pod 2", thumbnail: UIImage(named: "livvy")), PodItem(videoURL: Bundle.main.url(forResource: "vid", withExtension: "mp4")!, metadata: "Pod 3", thumbnail: UIImage(named: "livvy"))], title: "Pod 3"),
//        // Add more pods for demonstration
//    ]
//    
    @Environment(\.colorScheme) var colorScheme

    @State private var expandedPods = Set<String>()
    @State private var currentItemIndex = 0

    
    var body: some View {
      
        NavigationView {
            List {
                ForEach(homeViewModel.pods.indices, id: \.self) { index in
                   
                    VStack {
                     
                        PodTitleRow(pod: homeViewModel.pods[index], isExpanded: expandedPods.contains(homeViewModel.pods[index].title), onExpandCollapseTapped: {
                                    // This closure is what you pass to the button inside PodTitleRow
                                    withAnimation {
                                        togglePodExpansion(for: homeViewModel.pods[index].title)
                                    }
                                })
                                    .listRowInsets(EdgeInsets())
                                    .buttonStyle(PlainButtonStyle())
                    }
                    .listRowInsets(EdgeInsets())
//                    .animation(nil)
                    
                    if expandedPods.contains(homeViewModel.pods[index].title) {
                        ForEach(homeViewModel.pods[index].items, id: \.metadata) { item in
                            NavigationLink(destination: ItemView(items: homeViewModel.pods[index].items)) {
                                    ItemRow(item: item)
                                        .listRowInsets(EdgeInsets())
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .padding(.trailing, 15)
                        }
                    
                    }
                    
            }
            .onAppear {
                print(homeViewModel.pods, "pods")
                homeViewModel.fetchPodsForUser(email: viewModel.email) // Use the actual user email
                       }
            
            .listStyle(InsetGroupedListStyle())
                           .navigationTitle("Pods")
                           .navigationBarTitleDisplayMode(.inline)
        }
        .background(backgroundColor.edgesIgnoringSafeArea(.all))
    }

    private func togglePodExpansion(for title: String) {
        withAnimation(.easeInOut) {
            if expandedPods.contains(title) {
                expandedPods.remove(title)
            } else {
                expandedPods.insert(title)
            }
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
    }
    
}

struct PodTitleRow: View {
    let pod: Pod
    let isExpanded: Bool
    var onExpandCollapseTapped: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            ZStack{
                NavigationLink(destination: PodView(pod: pod)){ EmptyView() }.opacity(0.0)
                    .padding(.trailing, -5).frame(width:0, height:0)
                Text(pod.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .padding(.leading, 0) // Apply padding to the text element itself
            }
            
            Spacer()
            Button(action: onExpandCollapseTapped) {
                HStack{
                    Text("\(pod.items.count)")
                        .foregroundColor(.gray)
                        .padding(.trailing, 4) // Adjust as necessary for alignment
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")

                        .foregroundColor(.gray)
                        .padding(.trailing, 0)
                    
                }
        
            }
          
        }
        .background(colorScheme == .dark ? Color(red: 30/255, green: 30/255, blue: 30/255) : Color.white)
        .cornerRadius(10)
        .padding(.vertical, 17)
        .padding(.horizontal, 15)
    }
    

    
}


struct ItemRow: View {
    let item: PodItem

    var body: some View {
        HStack {
            Text(item.metadata)
            Spacer()
            if let thumbnail = item.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 35, height: 35)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.leading, 30)

        .padding(.bottom, 10)
        .padding(.top, 10)

    }
}
