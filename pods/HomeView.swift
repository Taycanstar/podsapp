import SwiftUI

struct HomeView: View {
    // Assuming CameraViewModel is accessible and contains an array of Pods
    @ObservedObject var cameraModel = CameraViewModel()
    
    // Example Pods Data - Replace with actual data fetching mechanism
    private let pods = [
        Pod(items: [PodItem(videoURL: URL(string: "video1")!, metadata: "dummy data", thumbnail: UIImage(named: "livvy")),PodItem(videoURL: URL(string: "video1")!, metadata: "dummy data", thumbnail: UIImage(named: "livvy")), PodItem(videoURL: URL(string: "video1")!, metadata: "dummy data", thumbnail: UIImage(named: "livvy")), PodItem(videoURL: URL(string: "video1")!, metadata: "dummy data", thumbnail: UIImage(named: "livvy")), PodItem(videoURL: URL(string: "video1")!, metadata: "dummy data", thumbnail: UIImage(named: "livvy"))], title: "Pod 1"),
        Pod(items: [PodItem(videoURL: URL(string: "video2")!, metadata: "Pod 2", thumbnail: UIImage(named: "livvy")), PodItem(videoURL: URL(string: "video3")!, metadata: "Pod 3", thumbnail: UIImage(named: "livvy"))], title: "Pod 3"),
        // Add more pods for demonstration
    ]
    
    // Environment property to detect color scheme
    @Environment(\.colorScheme) var colorScheme
    
    @State private var expandedPods = Set<String>()
//
//    
//    var body: some View {
//           NavigationView {
//               List(pods.indices, id: \.self) { index in
//                   VStack(alignment: .leading, spacing: 0) {
//                       HStack {
//                           Text(pods[index].title )
//                               .font(.system(size: 16, design: .rounded))
//                               .fontWeight(.bold)
//                           Spacer()
//                           Text("\(pods[index].items.count)")
//                               .foregroundColor(.gray)
//                           
//                           Image(systemName: "chevron.right")
//                               .font(.system(size: 14))
//                               .foregroundColor(.gray)
//                       }
//                       .padding(17)
//                       .background(colorScheme == .dark ? Color(red: 30/255, green: 30/255, blue: 30/255) : Color.white)
//                   }
//                   .listRowInsets(EdgeInsets())
//                   
//              
//
//               }
//               .navigationTitle("Pods")
//               .navigationBarTitleDisplayMode(.inline)
//           }
//           .background(backgroundColor)
//           .edgesIgnoringSafeArea(.all)
//       }
    
//    var body: some View {
//        NavigationView {
//            List {
//                ForEach(pods.indices, id: \.self) { index in
//                    Section(header: PodTitleRow(pod: pods[index], isExpanded: expandedPods.contains(pods[index].title))
//                        .onTapGesture {
//                            withAnimation(.easeInOut) {
//                                togglePodExpansion(for: pods[index].title)
//                            }
//                        }
//                    ) {
//                        if expandedPods.contains(pods[index].title) {
//                            ForEach(pods[index].items, id: \.metadata) { item in
//                                ItemRow(item: item)
//                            }
//                        }
//                    }
//                    .textCase(nil)
//                    .listRowInsets(EdgeInsets())
//                }
//            }
//            .listStyle(InsetGroupedListStyle())
//            .navigationTitle("Pods")
//        }
//        .background(backgroundColor.edgesIgnoringSafeArea(.all))
//    }
//    
//    private func togglePodExpansion(for title: String) {
//        if expandedPods.contains(title) {
//            expandedPods.remove(title)
//        } else {
//            expandedPods.insert(title)
//        }
//    }
//    
//    private var backgroundColor: Color {
//        colorScheme == .dark ? Color.black : Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
//    }
    
//    var body: some View {
//        NavigationView {
//            List {
//                ForEach(pods.indices, id: \.self) { index in
//                    VStack(alignment: .leading, spacing: 0) {
//                        PodTitleRow(pod: pods[index], isExpanded: expandedPods.contains(pods[index].title))
//                            .onTapGesture {
//                                togglePodExpansion(for: pods[index].title)
//                            }
//                        
//                        if expandedPods.contains(pods[index].title) {
//                            ForEach(pods[index].items, id: \.metadata) { item in
//                                ItemRow(item: item)
//                            }
//                            .animation(.easeInOut, value: expandedPods.contains(pods[index].title))
//                        }
//                    }
//                    .listRowInsets(EdgeInsets())
//                }
//            }
//            .listStyle(InsetGroupedListStyle())
//            .navigationTitle("Pods")
//            .navigationBarTitleDisplayMode(.automatic)
//        }
//        .background(backgroundColor.edgesIgnoringSafeArea(.all))
//    }
//    
//    private func togglePodExpansion(for title: String) {
//        withAnimation(.easeInOut) {
//            if expandedPods.contains(title) {
//                expandedPods.remove(title)
//            } else {
//                expandedPods.insert(title)
//            }
//        }
//    }
//    
//    private var backgroundColor: Color {
//        colorScheme == .dark ? Color.black : Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
//    }
    
    
    var body: some View {
        NavigationView {
            List {
                ForEach(pods.indices, id: \.self) { index in
                    VStack {
                        PodTitleRow(pod: pods[index], isExpanded: expandedPods.contains(pods[index].title))
                         
                            .onTapGesture {
                                togglePodExpansion(for: pods[index].title)
                            }
                            .listRowInsets(EdgeInsets())

                        if expandedPods.contains(pods[index].title) {
                            ForEach(pods[index].items, id: \.metadata) { item in
                                ItemRow(item: item)
                                    .listRowInsets(EdgeInsets())
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .animation(nil) // Disable animations for the pod title changes
                }
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Text(pod.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .padding(.leading, 0) // Apply padding to the text element itself
            Spacer()
            Text("\(pod.items.count)")
                .foregroundColor(.gray)
                .padding(.trailing, 4) // Adjust as necessary for alignment
            Image(systemName: "chevron.right")
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .foregroundColor(.gray)
                .padding(.trailing, 0) // Apply padding to the chevron icon itself
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
        .padding(.trailing, 10)
        .padding(.bottom, 5)

    }
}
