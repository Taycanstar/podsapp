import SwiftUI

struct HomeView: View {
    // Assuming CameraViewModel is accessible and contains an array of Pods
    @ObservedObject var cameraModel = CameraViewModel()
    
    // Example Pods Data - Replace with actual data fetching mechanism
    private let pods = [
        Pod(items: [PodItem(videoURL: URL(string: "video1")!, metadata: "Pod 1", thumbnail: nil, title: "Pod 1")]),
        Pod(items: [PodItem(videoURL: URL(string: "video2")!, metadata: "Pod 2", thumbnail: nil, title:"Pod 2"), PodItem(videoURL: URL(string: "video3")!, metadata: "Pod 3", thumbnail: nil, title: "Pod 3")]),
        // Add more pods for demonstration
    ]
    
    // Environment property to detect color scheme
    @Environment(\.colorScheme) var colorScheme
    

    
    var body: some View {
           NavigationView {
               List(pods.indices, id: \.self) { index in
                   VStack(alignment: .leading, spacing: 0) {
                       HStack {
                           Text(pods[index].items.first?.title ?? "Unnamed Pod")
                               .font(.system(size: 16, design: .rounded))
                               .fontWeight(.bold)
                           Spacer()
                           Text("\(pods[index].items.count)")
                           
                           Image(systemName: "chevron.right")
                               .font(.system(size: 14))
                       }
                       .padding(17)
                       .background(colorScheme == .dark ? Color(red: 30/255, green: 30/255, blue: 30/255) : Color.white)
                   }
                   .listRowInsets(EdgeInsets())
                   
              

               }
               .navigationTitle("Pods")
               .navigationBarTitleDisplayMode(.inline)
           }
           .background(backgroundColor)
           .edgesIgnoringSafeArea(.all)
       }
       
       private var backgroundColor: Color {
           colorScheme == .dark ? Color.black : Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
       }
}
