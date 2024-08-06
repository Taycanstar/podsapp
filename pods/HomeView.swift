import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject var cameraModel = CameraViewModel()
    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var uploadViewModel: UploadViewModel
    var networkManager: NetworkManager = NetworkManager()
    
    @Environment(\.colorScheme) var colorScheme
    @State private var podsReordered = false
    @State private var editMode: EditMode = .inactive
    @State private var isLoadingMore = false
    @State private var editingPods: [Pod] = []
    @State private var hasInitiallyFetched = false
    @State private var needsRefresh: Bool = false
    @State private var showDoneButton = false
    @State private var isEditMode: Bool = false
    @State private var editingItemId: Int?
    @State private var isAnyItemEditing: Bool = false
    
    @State private var showSheet = false
    
//    var body: some View {
//        NavigationView {
//            ScrollView {
//                GeometryReader { geometry in
//                                        Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).origin.y)
//                                    }
//                                    .frame(height: 0)
//                LazyVStack(spacing: 0) {
//                    RecentlyVisitedHeader(showSheet: $showSheet)
//                    
//                    ForEach(homeViewModel.pods) { pod in
//                        PodCard(pod: pod)
//                        if pod.id != homeViewModel.pods.last?.id {
//                            Divider().padding(.horizontal)
//                        }
//                    }
//                    .onMove(perform: movePod)
//                    .onDelete(perform: deletePod)
//                }
//                      
//                .background(colorScheme == .dark ? Color(rgb: 44, 44, 44) : .white)
//                .cornerRadius(10)
//                .overlay(
//                               RoundedRectangle(cornerRadius: 10)
//                                .stroke(colorScheme == .dark ? Color(rgb: 70,70,70) : Color(rgb: 220, 220, 220), lineWidth: 0.3)
//                           )
////                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//                .padding(.horizontal)
//                .padding(.top)
//                
//                // Load More button
//                if shouldShowLoadMoreButton {
//                    Button(action: loadMorePods) {
//                        Text("Load More")
//                            .foregroundColor(.blue)
//                    }
//                    .padding()
//                }
//            }
//            
////            .coordinateSpace(name: "scroll")
//            .background(colorScheme == .dark ? Color(rgb:14,14,14) : Color(rgb: 246, 246, 246))
////                            .scrollIndicators(.hidden)
////                            .padding(.bottom, 50)
////
////            .navigationTitle("Pods")
////            .navigationBarTitleDisplayMode(.inline)
//            .onAppear {
//                fetchPodsAndWorkspacesIfNeeded()
//                    }
//            .refreshable {
//                await refreshPods()
//            }
//            .sheet(isPresented: $showSheet) {
//                           RecentlyVisitedSheet(showSheet: $showSheet, workspaces: homeViewModel.workspaces)  // Pass workspaces here
//                       }
//        }
//        
//    }
    
    var body: some View {
           NavigationView {
               ZStack(alignment: .top) {
                   ScrollView {
         
                       
                       LazyVStack(spacing: 0) {
                           RecentlyVisitedHeader(showSheet: $showSheet)
                           ForEach(homeViewModel.pods) { pod in
                               PodCard(pod: pod)
                               if pod.id != homeViewModel.pods.last?.id {
                                   Divider().padding(.horizontal)
                               }
                           }
                           .onMove(perform: movePod)
                           .onDelete(perform: deletePod)
                       }
                       .background(colorScheme == .dark ? Color(rgb: 44, 44, 44) : .white)
                       .cornerRadius(10)
                       .overlay(
                           RoundedRectangle(cornerRadius: 10)
                               .stroke(colorScheme == .dark ? Color(rgb: 70,70,70) : Color(rgb: 220, 220, 220), lineWidth: 0.3)
                       )
                       .padding(.horizontal)
                       .padding(.top, 60) // Add padding for the header
                       
                       if shouldShowLoadMoreButton {
                           Button(action: loadMorePods) {
                               Text("Load More")
                                   .foregroundColor(.blue)
                           }
                           .padding()
                       }
                   }
                   .background(colorScheme == .dark ? Color(rgb:14,14,14) : Color(rgb: 246, 246, 246))
              
                   
                   HomeHeaderView()
               }
               .navigationBarHidden(true)
               .onAppear {
                   fetchPodsAndWorkspacesIfNeeded()
               }
               .refreshable {
                   await refreshPods()
               }
                           .sheet(isPresented: $showSheet) {
                                          RecentlyVisitedSheet(showSheet: $showSheet, workspaces: homeViewModel.workspaces)  // Pass workspaces here
                                      }
           }
       }
    
    
    private func fetchPodsAndWorkspacesIfNeeded() {
          if homeViewModel.pods.isEmpty {
              homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) { }
          }
          homeViewModel.fetchWorkspacesForUser(email: viewModel.email)
      }
    
    private func loadMorePods() {
        homeViewModel.fetchPodsForUser(email: viewModel.email, page: homeViewModel.currentPage + 1) { }
    }


    
    private var shouldShowLoadMoreButton: Bool {
        return homeViewModel.pods.count < homeViewModel.totalPods
    }
    
    private func refreshPods() {
        DispatchQueue.global(qos: .background).async {
            homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
                // Additional actions after refresh if needed
            }
        }
    }

    private func saveChangesAndExitEditMode() {
        isEditMode = false
        editMode = .inactive
        if podsReordered {
            homeViewModel.pods = editingPods
            let orderedPodIds = homeViewModel.pods.map { $0.id }
            DispatchQueue.global(qos: .background).async {
                networkManager.reorderPods(email: viewModel.email, podIds: orderedPodIds) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            print("Pods reordered successfully on the backend.")
                        } else {
                            print("Failed to reorder pods on the backend: \(errorMessage ?? "Unknown error")")
                        }
                    }
                }
            }
            podsReordered = false
        }
    }

    private func saveInputChanges() {
        print("Saving input changes")
        
        guard let itemId = editingItemId else {
            print("No item selected for editing")
            return
        }
        
        if let podIndex = homeViewModel.pods.firstIndex(where: { $0.items.contains(where: { $0.id == itemId }) }),
           let itemIndex = homeViewModel.pods[podIndex].items.firstIndex(where: { $0.id == itemId }) {
            let item = homeViewModel.pods[podIndex].items[itemIndex]
            
            print("Updating item:", item)

            DispatchQueue.global(qos: .background).async {
                networkManager.updatePodItemLabelAndNotes(itemId: item.id, newLabel: item.metadata, newNotes: item.notes) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            print("Pod item label and notes updated successfully.")
                        } else {
                            print("Failed to update pod item label and notes: \(errorMessage ?? "Unknown error")")
                        }
                        self.showDoneButton = false
                        self.isAnyItemEditing = false
                        self.editingItemId = nil
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        } else {
            print("Item not found for itemId \(itemId)")
        }
    }

    func movePod(from source: IndexSet, to destination: Int) {
        let podsToMove = source.map { homeViewModel.pods[$0] }
        
        homeViewModel.pods.move(fromOffsets: source, toOffset: destination)
        
        if editMode == .active {
            editingPods.move(fromOffsets: source, toOffset: destination)
        }
        
        let orderedPodIds = homeViewModel.pods.map { $0.id }
        networkManager.reorderPods(email: viewModel.email, podIds: orderedPodIds) { [self] success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    print("Pods reordered successfully in the backend.")
                    self.podsReordered = true
                    self.homeViewModel.objectWillChange.send()
                } else {
                    print("Failed to reorder pods in the backend: \(errorMessage ?? "Unknown error")")
                    self.homeViewModel.pods = podsToMove
                    self.homeViewModel.objectWillChange.send()
                }
            }
        }
    }

    func deletePod(at offsets: IndexSet) {
        let indicesToDelete = Array(offsets)
        let sortedIndices = indicesToDelete.sorted().reversed()
        
        for index in sortedIndices {
            let podId = homeViewModel.pods[index].id
            networkManager.deletePod(podId: podId) { [self] success, message in
                DispatchQueue.main.async {
                    if success {
                        print("Pod deleted successfully.")
                        self.homeViewModel.pods.remove(at: index)
                        if self.editMode == .active {
                            self.editingPods.remove(at: index)
                        }
                        self.homeViewModel.totalPods -= 1
                    } else {
                        print("Failed to delete pod: \(message ?? "Unknown error")")
                    }
                }
            }
        }
    }
}



struct ItemRow: View {
    @Binding var item: PodItem
    let isEditing: Bool
    let onTapNavigate: () -> Void
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Binding var isAnyItemEditing: Bool
    @Binding var showDoneButton: Bool
    @Binding var editingItemId: Int?

    @FocusState private var isMetadataFocused: Bool
    @FocusState private var isNotesFocused: Bool
    @State private var showNotesPlaceholder: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("", text: $item.metadata)
                    .focused($isMetadataFocused)
                    .font(.body)
                    .onTapGesture {
                        if !isEditing {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isMetadataFocused = true
                                showDoneButton = true
                                isAnyItemEditing = true
                                editingItemId = item.id
                                showNotesPlaceholder = true
                            }
                        }
                    }
                
                Spacer()
                
                HStack(spacing: 5) {
                    if let thumbnailURL = item.thumbnailURL {
                        AsyncImage(url: thumbnailURL) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .onTapGesture(perform: onTapNavigate)
            }

            if !item.notes.isEmpty || showNotesPlaceholder {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $item.notes)
                        .focused($isNotesFocused)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .frame(height: max(20, calculateHeight(for: item.notes)))
                        .background(Color.clear)
                        .opacity(item.notes.isEmpty ? 0.6 : 1)
                        .onTapGesture {
                            if !isEditing {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isNotesFocused = true
                                    showDoneButton = true
                                    isAnyItemEditing = true
                                    editingItemId = item.id
                                }
                            }
                        }
                    
                    if item.notes.isEmpty {
                        Text("Add note")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.top, 7)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.leading, -5)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 10)
        .padding(.leading, 15)
        .contentShape(Rectangle())
        .disabled(isEditing)
        .onChange(of: isMetadataFocused) { focused in
            if !focused && item.notes.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showNotesPlaceholder = false
                }
            }
        }
        .onChange(of: isNotesFocused) { focused in
            if focused {
                showNotesPlaceholder = true
            } else if !focused && item.notes.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showNotesPlaceholder = false
                }
            }
        }
    }
    
    private func calculateHeight(for text: String) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .footnote)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).boundingRect(
            with: CGSize(width: UIScreen.main.bounds.width - 80, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).size
        
        return size.height + 10 // Add some padding
    }
}
struct PodTitleRow: View {
    @Binding var pod: Pod
    let isExpanded: Bool
    var onExpandCollapseTapped: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @Binding var needsRefresh: Bool

    var body: some View {
        HStack {
            ZStack{
                NavigationLink(destination: PodView(pod: $pod, needsRefresh: $needsRefresh)){ EmptyView() }.opacity(0.0)
                    .padding(.trailing, -5).frame(width:0, height:0)
                Text(pod.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .padding(.leading, 0) // Apply padding to the text element itself
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            Spacer()
            Button(action: onExpandCollapseTapped) {
                HStack {
                    Text("\(pod.items.count)")
                        .foregroundColor(.gray)
                        .padding(.trailing, 4) // Adjust as necessary for alignment
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.gray)
                        .padding(.trailing, 0)
                }
            }
        }
        .cornerRadius(10)
        .padding(.vertical, 17)
        .padding(.horizontal, 15)
    }
}




extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    init(rgb r: Int, _ g: Int, _ b: Int) {
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

struct RecentlyVisitedHeader: View {
    @Binding var showSheet: Bool  // Binding to control the sheet presentation
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 5) {  // Adjust spacing to bring chevron closer to the title
            Text("Recently visited")
                .font(.headline)
                .foregroundColor(colorScheme == .light ? .black : .white)
            Image(systemName: "chevron.down")
                .font(.system(size: 11))
                .foregroundColor(colorScheme == .light ? .black : .white)
                .padding(7)
                .background(colorScheme == .light ? Color.gray.opacity(0.2) : Color.gray.opacity(0.6))
                .clipShape(Circle())
            Spacer()
        }
        .padding()
        .background(colorScheme == .dark ? Color(rgb: 44, 44, 44) : Color.white)
        .onTapGesture {
            showSheet = true  // Trigger the sheet when the header is tapped
            HapticFeedback.generateLigth()
        }
    }
}


struct RecentlyVisitedSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var showSheet: Bool  // Binding to control the sheet presentation
    var workspaces: [Workspace]  // Add this line

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button(action: {
                        showSheet = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(colorScheme == .light ? .black : .white)
                    }
                    Spacer()
                    Text("Show by")
                        .font(.headline)
                    Spacer()
                    Text("") // Placeholder to center the title
                }
                .padding()
                .background(colorScheme == .dark ? Color(rgb: 44, 44, 44) : Color.white)

                Text("Quick access from all products")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                
                VStack(spacing: 1) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.gray)
                        Text("Recently visited")
                        Spacer()
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color("container") : Color("container"))
                    
                    HStack {
                        Image(systemName: "star")
                            .foregroundColor(.gray)
                        Text("Favorites")
                        Spacer()
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color("container") : Color("container"))
                }
                
                Text("My workspaces")
                    .font(.subheadline)
                    .padding(.top, 10)
                
                ScrollView {
                    VStack(spacing: 1) {
                        // Add your workspace list here
                        // Example:
                        ForEach(workspaces) { workspace in
                            Text(workspace.name)
                                .padding()
                                .background(colorScheme == .dark ? Color("container") : Color("container"))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}




struct HapticFeedback {
    static func generate() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }
    
    static func generateLigth() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

struct PodCard: View {
    let pod: Pod
    @State private var isFavorite: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    @State private var isActive = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Image column
            Image(pod.mode == "workout" ? (colorScheme == .dark ? "wkout-dark" : "wkout") : (colorScheme == .dark ? "st-dark" : "st"))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 45, height: 45)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorScheme == .dark ? Color(rgb: 70, 70, 70) : Color(hex: "#DBDFEC"), lineWidth: 1)
                )
            
            // Details column
            VStack(alignment: .leading, spacing: 4) {
                Text(pod.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(pod.workspace ?? "Unknown workspace")
                    .font(.system(size: 14))
                    .foregroundColor(colorScheme == .dark ? .gray : .secondary)
            }
            
            Spacer()
            
            // Star column
            VStack {
                Spacer()
                Button(action: {
                    isFavorite.toggle()
                    HapticFeedback.generate()
                    NetworkManager().toggleFavorite(podId: pod.id, isFavorite: isFavorite) { success, error in
                                   if success {
                                       print("Favorite status updated successfully.")
                                   } else {
                                       print("Failed to update favorite status: \(error ?? "Unknown error")")
                                   }
                               }
                }) {
                    Image(systemName: "star.fill")
                        .foregroundColor(isFavorite ? Color(rgb: 255, 205, 42) : Color(rgb: 196, 198, 207))
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle()) // Ensure the button area is tappable
                .onTapGesture {
                    isFavorite.toggle()
                }
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 15)
        .background(colorScheme == .dark ? Color(rgb: 44, 44, 44) : Color.white)
        .cornerRadius(10)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .background(
            NavigationLink(destination: PodView(pod: .constant(pod), needsRefresh: .constant(false)), isActive: $isActive) {
                EmptyView()
            }
            .hidden()
        )
        .gesture(
            TapGesture()
                .onEnded {
                    withAnimation {
                        self.isPressed = true
                    }
                    HapticFeedback.generate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            self.isPressed = false
                        }
                        self.isActive = true
                    }
                }
        )
    }
}

struct HomeHeaderView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Glassmorphic background
            Color.clear
                .background(Material.regularMaterial)

            
            // Content
            HStack {
                Image(colorScheme == .dark ? "fullwte" : "fullblk")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 25)
                Spacer()
            }
            .padding(.horizontal, 25)
//            .padding(.vertical)
        }
        .frame(height: 44)

    }
}

