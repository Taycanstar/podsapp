////
////  FoldersView.swift
////  Pods
////
////  Created by Dimi Nunez on 1/27/25.
////
//
import SwiftUI


enum AppNavigationDestination: Hashable {
    case pods                   // Default Pods folder
    case folder(Folder)         // A user-created folder
    case podDetails(Int)        // Pod details view
    case player(item: PodItem)  // Video player
    case podInfo(podId: Int)    // Pod info
    case podMembers(podId: Int) // Pod members
    case activityLog(podId: Int, columns: [PodColumn])
    case trends(podId: Int)
    case fullAnalytics(column: PodColumn, activities: [Activity], itemId: Int)
    case gracie(podId: Int)
    case activitySummary(podId: Int, duration: Int, startTime: Date, endTime: Date, podColumns: [PodColumn], notes: String?)
    case fullSummary(items: [PodItem], columns: [PodColumn])
    case fullActivitySummary(activityId: Int, columns: [PodColumn])
    case itemSummary(itemId: Int, columns: [PodColumn])
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .pods:
            hasher.combine("pods")
        case .folder(let folder):
            hasher.combine("folder")
            hasher.combine(folder)
        case .podDetails(let id):
            hasher.combine("podDetails")
            hasher.combine(id)
        case .player(let item):
            hasher.combine("player")
            hasher.combine(item.id)
        case .podInfo(let podId):
            hasher.combine("podInfo")
            hasher.combine(podId)
        case .podMembers(let podId):
            hasher.combine("podMembers")
            hasher.combine(podId)
        case .activityLog(let podId, let columns):
            hasher.combine("activityLog")
            hasher.combine(podId)
            hasher.combine(columns.map { $0.id })
        case .trends(let podId):
            hasher.combine("trends")
            hasher.combine(podId)
        case .fullAnalytics(let column, let activities, let itemId):
            hasher.combine("fullAnalytics")
            hasher.combine(column.name)
            hasher.combine(itemId)
            hasher.combine(activities.map { $0.id })
        case .gracie(let podId):
            hasher.combine("gracie")
            hasher.combine(podId)
        case .activitySummary(let podId, let duration, let startTime, let endTime, let columns, let notes):
            hasher.combine("activitySummary")
            hasher.combine(podId)
            hasher.combine(duration)
            hasher.combine(startTime)
            hasher.combine(endTime)
            hasher.combine(columns.map { $0.id })
            hasher.combine(notes)
        case .fullSummary(let items, let columns):
            hasher.combine("fullSummary")
            hasher.combine(items.map { $0.id })
            hasher.combine(columns.map { $0.id })
        case .fullActivitySummary(let activityId, let columns):
            hasher.combine("fullActivitySummary")
            hasher.combine(activityId)
            hasher.combine(columns.map { $0.id })
        case .itemSummary(let itemId, let columns):
            hasher.combine("itemSummary")
            hasher.combine(itemId)
            hasher.combine(columns.map { $0.id })
        }
    }
    
    static func == (lhs: AppNavigationDestination, rhs: AppNavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.pods, .pods):
            return true
        case (.folder(let f1), .folder(let f2)):
            return f1 == f2
        case (.podDetails(let id1), .podDetails(let id2)):
            return id1 == id2
        case (.player(let item1), .player(let item2)):
            return item1.id == item2.id
        case (.podInfo(let id1), .podInfo(let id2)):
            return id1 == id2
        case (.podMembers(let id1), .podMembers(let id2)):
            return id1 == id2
        case (.activityLog(let id1, let cols1), .activityLog(let id2, let cols2)):
            return id1 == id2 && cols1.map { $0.id } == cols2.map { $0.id }
        case (.trends(let id1), .trends(let id2)):
            return id1 == id2
        case (.fullAnalytics(let col1, let acts1, let itemId1), .fullAnalytics(let col2, let acts2, let itemId2)):
            return col1.name == col2.name && acts1.map { $0.id } == acts2.map { $0.id } && itemId1 == itemId2
        case (.gracie(let id1), .gracie(let id2)):
            return id1 == id2
        case (.activitySummary(let pid1, let d1, let st1, let et1, let c1, let n1),
              .activitySummary(let pid2, let d2, let st2, let et2, let c2, let n2)):
            return pid1 == pid2 && d1 == d2 && st1 == st2 && et1 == et2 &&
                   c1.map { $0.id } == c2.map { $0.id } && n1 == n2
        case (.fullSummary(let items1, let cols1), .fullSummary(let items2, let cols2)):
            return items1.map { $0.id } == items2.map { $0.id } &&
                   cols1.map { $0.id } == cols2.map { $0.id }
        case (.fullActivitySummary(let id1, let cols1), .fullActivitySummary(let id2, let cols2)):
            return id1 == id2 && cols1.map { $0.id } == cols2.map { $0.id }
        case (.itemSummary(let id1, let cols1), .itemSummary(let id2, let cols2)):
            return id1 == id2 && cols1.map { $0.id } == cols2.map { $0.id }
        default:
            return false
        }
    }
}
// MARK: - PodsContainerView
struct PodsContainerView: View {
    @EnvironmentObject var podsViewModel: PodsViewModel
    @State private var path = NavigationPath()
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        NavigationStack(path: $path) {
            FoldersView(path: $path)
                .navigationDestination(for: AppNavigationDestination.self) { destination in
                    switch destination {
                    case .pods:
                        PodsView(navigationPath: $path)
                    case .folder(let folder):
                        PodsView(folder: folder, navigationPath: $path)
                    case .podDetails(let podId):
                        HomePodView(podId: podId, needsRefresh: .constant(false), navigationPath: $path)
                    case .player(let item):
                        SingleVideoPlayerView(item: item)
                    case .podInfo(let podId):
                        if let podIndex = podsViewModel.pods.firstIndex(where: { $0.id == podId }) {
                            PodInfoView(pod: $podsViewModel.pods[podIndex],
                                        currentTitle: $podsViewModel.pods[podIndex].title,
                                        currentDescription: Binding(
                                            get: { podsViewModel.pods[podIndex].description ?? "" },
                                            set: { podsViewModel.pods[podIndex].description = $0 }
                                        ),
                                        currentType: Binding(
                                            get: { podsViewModel.pods[podIndex].type ?? "" },
                                            set: { podsViewModel.pods[podIndex].type = $0 }
                                        ),
                                        currentPrivacy: Binding(
                                            get: { podsViewModel.pods[podIndex].privacy ?? "" },
                                            set: { podsViewModel.pods[podIndex].privacy = $0 }
                                        ),
                                        currentInstructions: Binding(
                                            get: { podsViewModel.pods[podIndex].instructions ?? "" },
                                            set: { podsViewModel.pods[podIndex].instructions = $0 }
                                        )) { updatedTitle, updatedDescription, updatedInstructions, updatedType, updatedPrivacy in
                                            // Optionally do additional work here.
                                        }
                        }

                    case .podMembers(let podId):
                        if let pod = podsViewModel.pods.first(where: { $0.id == podId }) {
                            PodMembersView(podId: podId, teamId: pod.teamId)
                        }
                    case .activityLog(let podId, let columns):
                        ActivityLogView(columns: columns, podId: podId, userEmail: viewModel.email)
                    case .trends(let podId):
                        if let pod = podsViewModel.pods.first(where: { $0.id == podId }) {
                            ItemTrendsView(podId: podId, podItems: pod.items, podColumns: pod.columns)
                        }
                    case .fullAnalytics(let column, let activities, let itemId):
                        FullAnalyticsView(column: column, activities: activities, itemId: itemId) { activity in
                            let relevantItem = activity.items.first { $0.itemId == itemId }
                            guard let columnValue = relevantItem?.columnValues[String(column.id)] else { return nil }
                            
                            switch columnValue {
                            case .number(let value): return value
                            case .time(let timeValue): return Double(timeValue.totalSeconds)
                            case .array(let values):
                                let numericValues = values.compactMap { value -> Double? in
                                    switch value {
                                    case .number(let num): return num
                                    case .time(let time): return Double(time.totalSeconds)
                                    default: return nil
                                    }
                                }
                                return numericValues.max()
                            default: return nil
                            }
                        }
                    case .gracie(let podId):
                        GracieView(podId: podId)
                    case .activitySummary(let podId, let duration, let startTime, let endTime, let columns, let notes):
                        if let pod = podsViewModel.pods.first(where: { $0.id == podId }) {
                            ActivitySummaryView(pod: pod,
                                             duration: duration,
                                             items: pod.items,
                                             startTime: startTime,
                                             endTime: endTime,
                                             podColumns: columns,
                                             navigationAction: { destination in
                                                 path.append(destination)
                                             },
                                             notes: notes)
                        }
                    case .fullSummary(let items, let columns):
                        FullSummaryView(items: items, columns: columns)
                    case .fullActivitySummary(let activityId, let columns):
                        FullActivitySummaryView(activityId: activityId, columns: columns)
                    case .itemSummary(let itemId, let columns):
                        ItemSummaryView(itemId: itemId, columns: columns)
                    }
                }
        }
    }
}

// MARK: - FoldersView

struct FoldersView: View {
    @Binding var path: NavigationPath
    @State private var searchText = ""
    @EnvironmentObject var podsViewModel: PodsViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var shouldNavigateToPodsOnAppear = true
    @State private var showingCreateFolderSheet = false
    @State private var showingOptionsMenu = false
    @State private var isEditMode: EditMode = .inactive

    var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return podsViewModel.folders.filter { $0.name != "Pods" }
        } else {
            return podsViewModel.folders.filter { folder in
                folder.name != "Pods" && folder.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        List {
            Section {
                // "Pods" folder with count
                NavigationLink(value: AppNavigationDestination.pods) {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 21))
                            .foregroundColor(.accentColor)
                        Text("Pods")
                        Spacer()
                        Text("\(podsViewModel.pods.count)")
                            .foregroundColor(.gray)
                    }
                }

                // User-created folders
                ForEach(filteredFolders) { folder in
                    NavigationLink(value: AppNavigationDestination.folder(folder)) {
                        HStack {
                            Image(systemName: "folder")
                                .font(.system(size: 21))
                                .foregroundColor(.accentColor)
                            Text(folder.name)
                            Spacer()
                            Text("\(folder.podCount)")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onMove(perform: moveFolders)
                .onDelete(perform: deleteFolder)
            }
        }
        .navigationTitle("Folders")
        .searchable(text: $searchText, prompt: "Search")
        .padding(.bottom, 49)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                 
                    
                    if isEditMode == .inactive {
                        Button(action: {
                            showingCreateFolderSheet = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(UIColor.secondarySystemFill))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        Button(action: {
                            showingOptionsMenu = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(UIColor.secondarySystemFill))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                    } else{
                        Button(action: {
                                                   isEditMode = .inactive
                                               }) {
                                                   Text("Done")
                                                       .foregroundColor(.accentColor)
                                               }
                    }
                 
                }
            }
        }
        .sheet(isPresented: $showingCreateFolderSheet) {
            CreateFolderSheet(isPresented: $showingCreateFolderSheet)
        }
        .confirmationDialog("Options", isPresented: $showingOptionsMenu) {
            Button("Edit") {
                withAnimation {
                    isEditMode = .active
                }
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            // Automatically navigate to the default "Pods" folder
            if shouldNavigateToPodsOnAppear {
                path.append(AppNavigationDestination.pods)
                shouldNavigateToPodsOnAppear = false
            }
        }
    }
    
    private func moveFolders(from source: IndexSet, to destination: Int) {
           var updatedFolders = filteredFolders
           updatedFolders.move(fromOffsets: source, toOffset: destination)
           
           let folderIds = updatedFolders.map { $0.id }
           podsViewModel.updateFoldersOrder(folderIds: folderIds)
       }
    
    private func deleteFolder(at offsets: IndexSet) {
        // Map filtered indices to actual folders
        let foldersToDelete = offsets.map { filteredFolders[$0] }
        // Delete each folder
        for folder in foldersToDelete {
            podsViewModel.deleteFolder(folderId: folder.id)
        }
    }
}

// MARK: - CreateFolderSheet

struct CreateFolderSheet: View {
    @Binding var isPresented: Bool
    @State private var folderName = ""
    @State private var showingNameTakenAlert = false
    @EnvironmentObject var podsViewModel: PodsViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel

    private func suggestFolderName() -> String {
        let baseName = "New Folder"
        var counter = 1
        var suggestedName = baseName
        
        while podsViewModel.folders.contains(where: { $0.name == suggestedName }) {
            counter += 1
            suggestedName = "\(baseName) \(counter)"
        }
        
        return suggestedName
    }

    var body: some View {
        NavigationView {
            Form {
                ImmediateFocusTextField(text: $folderName)
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Done") {
                    if !folderName.isEmpty {
                        if podsViewModel.folders.contains(where: { $0.name == folderName }) {
                            showingNameTakenAlert = true
                        } else {
                            podsViewModel.createFolder(name: folderName, email: viewModel.email)
                            isPresented = false
                        }
                    }
                }
                .fontWeight(.semibold)
                .disabled(folderName.isEmpty)
            )
        }
        .alert("Name Taken", isPresented: $showingNameTakenAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please choose a different name.")
        }
        .onAppear {
            folderName = suggestFolderName()
        }
    }
}

// MARK: - ImmediateFocusTextField

struct ImmediateFocusTextField: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.borderStyle = .none
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.placeholder = "Folder Name"
        textField.autocorrectionType = .default
        textField.autocapitalizationType = .sentences
        textField.clearButtonMode = .whileEditing

        textField.addTarget(context.coordinator,
                            action: #selector(Coordinator.textDidChange(_:)),
                            for: .editingChanged)

        DispatchQueue.main.async {
            textField.becomeFirstResponder()
            textField.selectAll(nil)
        }
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ImmediateFocusTextField
        
        init(_ parent: ImmediateFocusTextField) {
            self.parent = parent
        }
        
        @objc func textDidChange(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }
    }
}
