////
////  FoldersView.swift
////  Pods
////
////  Created by Dimi Nunez on 1/27/25.
////
//
import SwiftUI

struct PodsContainerView: View {
    @EnvironmentObject var podsViewModel: PodsViewModel
    @State private var path = NavigationPath()
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        NavigationStack(path: $path) {
            FoldersView(path: $path)
                .navigationDestination(for: FolderDestination.self) { destination in
                    switch destination {
                    case .pods:
                        PodsView()
                           
                    }
                }
        }
        
    }
}


enum FolderDestination: Hashable {
    case pods
}
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
                // Pods folder with count
                NavigationLink(value: FolderDestination.pods) {
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
                
                // Other folders
                ForEach(filteredFolders) { folder in
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
            if shouldNavigateToPodsOnAppear {
                path.append(FolderDestination.pods)
                shouldNavigateToPodsOnAppear = false
            }
        }
    }
    
    private func deleteFolder(at offsets: IndexSet) {
        for index in offsets {
            let folder = filteredFolders[index]
            podsViewModel.deleteFolder(folderId: folder.id)
        }
    }
}

struct CreateFolderSheet: View {
    @Binding var isPresented: Bool
    @State private var folderName = ""
    @EnvironmentObject var podsViewModel: PodsViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool 
    
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
                        podsViewModel.createFolder(name: folderName, email: viewModel.email)
                        isPresented = false
                    }
                }
                    .fontWeight(.semibold)
                .disabled(folderName.isEmpty)
            )
        }
        
    
     
           

    }
}


struct ImmediateFocusTextField: UIViewRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        
        // (A) Make it look more like SwiftUI’s default
        textField.borderStyle = .none
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.placeholder = "Folder Name"     // Move your placeholder here
        textField.autocorrectionType = .default
        textField.autocapitalizationType = .sentences
        
        // (B) Ensure we capture changes in real time
        textField.addTarget(context.coordinator,
                            action: #selector(Coordinator.textDidChange(_:)),
                            for: .editingChanged)
        
        // (C) Immediately focus
        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only update if SwiftUI's value differs from UITextField's
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

