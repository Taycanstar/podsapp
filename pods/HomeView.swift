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
    @State private var selectedHeaderOption = "Recently visited"
    @Binding var shouldNavigateToNewPod: Bool
       @Binding var newPodId: Int?
    @Environment(\.isTabBarVisible) var isTabBarVisible
    var body: some View {
           NavigationView {
               ZStack(alignment: .top) {
                   ScrollView {
         
                       
                       LazyVStack(spacing: 0) {
                           RecentlyVisitedHeader(showSheet: $showSheet, headerTitle: $selectedHeaderOption)
                           ForEach(podsToDisplay) { pod in
                               PodCard(pod: pod)
                               if pod.id != podsToDisplay.last?.id {
                                   Divider().padding(.horizontal)
                               }
                           }
                       }
                       .background(colorScheme == .dark ? Color(rgb: 44, 44, 44) : .white)
                       .cornerRadius(10)
                       .overlay(
                           RoundedRectangle(cornerRadius: 10)
                               .stroke(colorScheme == .dark ? Color(rgb: 70,70,70) : Color(rgb: 220, 220, 220), lineWidth: 0.3)
                       )
                       .padding(.horizontal)
                       .padding(.bottom, 150)
                       .padding(.top, 60) // Add padding for the header
                    
                   }

                   .background(colorScheme == .dark ? Color(rgb:14,14,14) : Color(rgb: 246, 246, 246))
              
                   
                   HomeHeaderView()
               }
               
        
               .navigationBarHidden(true)
               .onAppear {
                   fetchPodsAndWorkspacesIfNeeded()
                   isTabBarVisible.wrappedValue = true
                   print(viewModel.subscriptionExpiresAt, "exp")
                   print(viewModel.subscriptionPlan, "plan")
                   print(viewModel.subscriptionStatus, "sub")

               }
               .refreshable {
                    refreshPods()
               }
                           .sheet(isPresented: $showSheet) {
                                          RecentlyVisitedSheet(showSheet: $showSheet, workspaces: homeViewModel.workspaces, selectedOption: $selectedHeaderOption)  // Pass workspaces here
                                      }
                           .background(
                                           NavigationLink(
                                               destination: Group {
                                                   if let podId = newPodId, let pod = homeViewModel.pods.first(where: { $0.id == podId }) {
                                                       PodView(pod: .constant(pod), needsRefresh: .constant(false))
                                                   }
                                               },
                                               isActive: $shouldNavigateToNewPod,
                                               label: { EmptyView() }
                                           )
                                       )
           }
           .onChange(of: shouldNavigateToNewPod) { oldValue, newValue in
                       if newValue, let podId = newPodId {
                           print("Attempting to navigate to new pod with ID: \(podId)")
                       }
                   }
       }
    
    private var favoritePods: [Pod] {
        homeViewModel.pods.filter { $0.isFavorite ?? false }
    }

    private var recentlyVisitedPods: [Pod] {
        // Assuming you have a property to track recently visited pods
        // You might need to implement this logic based on your app's behavior
        homeViewModel.pods.filter { $0.lastVisited != nil }.sorted { $0.lastVisited! > $1.lastVisited! }
    }

    private var workspacePods: [Pod] {
        homeViewModel.pods.filter { $0.workspace == selectedHeaderOption }
    }

    private var podsToDisplay: [Pod] {
        switch selectedHeaderOption {
        case "Favorites":
            return favoritePods
        case "Recently visited":
            return recentlyVisitedPods
        default:
            return workspacePods
        }
    }
    
    private func fetchPodsAndWorkspacesIfNeeded() {
      
              homeViewModel.fetchPodsForUser(email: viewModel.email) { 
                  
              }
        
          homeViewModel.fetchWorkspacesForUser(email: viewModel.email)
      }
    

    
    private func refreshPods() {
        DispatchQueue.global(qos: .background).async {
            homeViewModel.fetchPodsForUser(email: viewModel.email) {
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
        .onChange(of: isMetadataFocused) {_,  focused in
            if !focused && item.notes.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showNotesPlaceholder = false
                }
            }
        }
        .onChange(of: isNotesFocused) { _, focused in
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
//            ZStack{
//                NavigationLink(destination: PodView(pod: $pod, needsRefresh: $needsRefresh)){ EmptyView() }.opacity(0.0)
//                    .padding(.trailing, -5).frame(width:0, height:0)
//                Text(pod.title)
//                    .font(.system(size: 16, weight: .bold, design: .rounded))
//                    .padding(.leading, 0) // Apply padding to the text element itself
//                    .foregroundColor(colorScheme == .dark ? .white : .black)
//            }
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
    @Binding var showSheet: Bool
    @Binding var headerTitle: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 5) {
            Text(headerTitle)
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
            showSheet = true
            HapticFeedback.generateLigth()
        }
    }
}


struct RecentlyVisitedSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var showSheet: Bool
    var workspaces: [Workspace]
    @Binding var selectedOption: String
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showAddWorkspace = false
    @State private var navigationPath = NavigationPath()
    
    
    var body: some View {
//        NavigationView {
        NavigationStack(path: $navigationPath) {
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
                .background(colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)

                HStack {
                    Text("Quick access from all products")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
                
                VStack(spacing: 15) {
                    Button(action: {
                        selectedOption = "Recently visited"
                        showSheet = false
                        HapticFeedback.generateRigid()
                    }) {
                        optionView(title: "Recently visited", imageName: "clock.arrow.circlepath")
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        selectedOption = "Favorites"
                        showSheet = false
                        HapticFeedback.generateRigid()
                    }) {
                        optionView(title: "Favorites", imageName: "star")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 15)
                
                HStack {
                    Text("My workspaces")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
                
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(workspaces) { workspace in
                            Button(action: {
                                selectedOption = workspace.name
                                showSheet = false
                                HapticFeedback.generateRigid()
                            }) {
                                workspaceView(workspace: workspace)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        // Add Workspace Button
                           Button(action: {
                               if viewModel.getCurrentSubscriptionTier() != nil {
                                   showAddWorkspace = true
                               } else {
                                   navigationPath.append("Subscription")
                               }
                           }) {
                               ZStack {
                                   RoundedRectangle(cornerRadius: 15)
                                       .fill(Color.accentColor)
                                   
                                   HStack {
                                       Spacer()
                                       Image(systemName: "plus")
                                           .foregroundColor(.white)
                                       Text("Add workspace")
                                           .fontWeight(.medium)
                                           .font(.system(size: 14))
                                           .foregroundColor(.white)
                                       Spacer()
                                   }
                                   .padding()
                                   .padding(.vertical, 3)
                               }
                               .padding(.top, 15)
                               .fixedSize(horizontal: false, vertical: true)
                           }
                           .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
            .navigationDestination(for: String.self) { destination in
                           if destination == "Subscription" {
                               SubscriptionView()
                           }
                       }
        }
  
        .sheet(isPresented: $showAddWorkspace) {
                    AddWorkspaceView() // Implement this view for adding workspaces
                }

    }
    
    private func optionView(title: String, imageName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color("container") : Color("container"))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(selectedOption == title ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(selectedOption == title ? Color.accentColor : Color.clear, lineWidth: 3)
                )
            
            HStack {
                Image(systemName: imageName)
                    .foregroundColor(.gray)
                Text(title)
                    .fontWeight(.medium)
                    .font(.system(size: 14))
                Spacer()
            }
            .padding(.vertical, 4)
            .padding()
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func workspaceView(workspace: Workspace) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color("container") : Color("container"))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(selectedOption == workspace.name ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(selectedOption == workspace.name ? Color.accentColor : Color.clear, lineWidth: 3)
                        .padding(1)
                )
         
            
            HStack {

                DefaultProfilePicture(
                    initial: workspace.profileInitial ?? "",
                    color: workspace.profileColor ?? "",
                              size: 30
                          )
           
                
                Text(workspace.name)
                    .fontWeight(.medium)
                    .font(.system(size: 14))
                Spacer()
            }
//            .padding(.vertical, 4)
            .padding()
        }
        .fixedSize(horizontal: false, vertical: true)
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
    static func generateRigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
}

struct PodCard: View {
    let pod: Pod
    @State private var isFavorite: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    @State private var isActive = false
    @EnvironmentObject var homeViewModel: HomeViewModel
  
    
    init(pod: Pod) {
        self.pod = pod
        _isFavorite = State(initialValue: pod.isFavorite ?? false)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Image column
            Image(pod.templateId == 1 ? (colorScheme == .dark ? "wkout-dark" : "wkout") : (colorScheme == .dark ? "st-dark" : "st"))
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
                    .font(.system(size: 12))
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
                                       print("Favorite status updated successfully.")
                                                                DispatchQueue.main.async {
                                                                    homeViewModel.updatePodFavoriteStatus(podId: pod.id, isFavorite: isFavorite)
                                                                }
                                   } else {
                                       print("Failed to update favorite status: \(error ?? "Unknown error")")
                                       DispatchQueue.main.async {
                                                                      isFavorite.toggle()
                                                                  }
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

        }
        .frame(height: 44)

    }
}
