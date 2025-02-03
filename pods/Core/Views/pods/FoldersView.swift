////
////  FoldersView.swift
////  Pods
////
////  Created by Dimi Nunez on 1/27/25.
////
//
import SwiftUI


enum AppNavigationDestination: Hashable {
    case pods               // Default Pods folder
    case folder(Folder)     // A user-created folder
    case podDetails(Int)    // Pod details view
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
                        PodsView()  // Default Pods folder view
                    case .folder(let folder):
                        PodsView(folder: folder) // Pods for a specific folder
                    case .podDetails(let podId):
                                            // Pass the pod id to HomePodView.
                                            HomePodView(podId: podId, needsRefresh: .constant(false))
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
                .onDelete(perform: deleteFolder)
            }
        }
        .navigationTitle("Folders")
        .searchable(text: $searchText, prompt: "Search")
        .padding(.bottom, 49)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
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
                }
            }
        }
        .sheet(isPresented: $showingCreateFolderSheet) {
            CreateFolderSheet(isPresented: $showingCreateFolderSheet)
        }
        .confirmationDialog("Options", isPresented: $showingOptionsMenu) {
            Button("Edit") { /* Edit mode */ }
            Button("Select") { /* Select mode */ }
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
