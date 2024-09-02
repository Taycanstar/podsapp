//
//  ItemOptionsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/15/24.
//


import SwiftUI

struct ItemOptionsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    var networkManager: NetworkManager = NetworkManager()
    @Binding var showItemOptionsSheet: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
     var onDeleteItem: () -> Void
    var onEditName: () -> Void
     var itemName: String
    var onDuplicateItem: () -> Void
    @State private var showPodSelection = false
     @State private var pods: [Pod] = []
     @State private var isLoadingPods = false
    @State private var podSelectionOffset: CGFloat = UIScreen.main.bounds.height
    var onMoveItem: (Int) -> Void
       var currentPodId: Int
    var dismissCardDetailView: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
   
            ZStack {
                (colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                    .edgesIgnoringSafeArea(.all) 
       
                
                VStack(spacing: 0) {
                    
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            showItemOptionsSheet = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                                .foregroundColor(.primary)
                            
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        MenuItemView(iconName: "square.and.pencil", text: "Edit name", action: {
                            print("Tapped edit name")
                            showItemOptionsSheet = false
                            onEditName()
                        }, color: .primary)
                        
                        MenuItemView(iconName: "doc.on.doc", text: "Duplicate item", action: {
                            showItemOptionsSheet = false
                            onDuplicateItem()
                        }, color: .primary)
                        
                        MenuItemView(iconName: "arrow.forward.square", text: "Move to Pod", action: {
//                            showItemOptionsSheet = false
                            fetchPods()
                                                    withAnimation(.spring()) {
                                                        showPodSelection = true
                                                        podSelectionOffset = 0
                                                    }
                        }, color: .primary)
                        
                        
                        Divider().padding(.vertical, 5)
                        
                        MenuItemView(iconName: "trash", text: "Delete item", action: {
                            
                            showDeleteConfirmation = true
                            
                        }, color: .red)
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    .padding(.bottom, 15)
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                .cornerRadius(20)
                .confirmationDialog("Delete \"\(itemName)\"? ",
                                    isPresented: $showDeleteConfirmation,
                                    titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        onDeleteItem()
                        showItemOptionsSheet = false
                    }
                    Button("Cancel", role: .cancel) {}
                }
                
                // Pod Selection View
                GeometryReader { geometry in
                             VStack(spacing: 0) {
                                 HStack {
                                     Spacer()
                                     Text("Select Pod")
                                         .font(.headline)
                                     Spacer()
                                 }
                                 .overlay(
                                     HStack {
                                         Spacer()
                                         Button(action: {
                                             withAnimation(.spring()) {
                                                 showPodSelection = false
                                                 podSelectionOffset = geometry.size.height
                                             }
                                         }) {
                                             Image(systemName: "xmark")
                                                 .foregroundColor(.primary)
                                         }
                                     }
                                  
                                 )
                                 .padding()
                                 .background(Color("mdBg"))
                                 
                                 if isLoadingPods {
                                     Spacer()
                                     ProgressView()
                                     Spacer()
                                 } else {
                                     ScrollView {
                                         LazyVStack(spacing: 10) {
                                             ForEach(pods.filter { $0.id != currentPodId }, id: \.id) { pod in
                                                 Button(action: {
                                                     onMoveItem(pod.id)
                                                     showItemOptionsSheet = false
                                                     dismissCardDetailView()
                                                 }) {
                                                     Text(pod.title)
                                                         .foregroundColor(.primary)
                                                         .frame(maxWidth: .infinity, alignment: .leading)
                                                         .padding()
                                                         .background(Color("ltBg"))
                                                         .cornerRadius(8)
                                                 }
                                             }
                                         }
                                         .padding()
                                     }
                                 }
                             }
                             .frame(maxWidth: .infinity, maxHeight: .infinity)
                             .background(Color("mdBg"))
                             .cornerRadius(20)
                             .offset(y: podSelectionOffset)              }

        }
        
        
        
    }
//    private func fetchPods() {
//         isLoadingPods = true
//        networkManager.fetchPodsForUser(email: viewModel.email) { success, fetchedPods, error in
//             isLoadingPods = false
//             if success, let fetchedPods = fetchedPods {
//                 self.pods = fetchedPods
//             } else {
//                 // Handle error (you might want to show an alert here)
//                 print("Failed to fetch pods: \(error ?? "Unknown error")")
//             }
//         }
//     }
    private func fetchPods() {
        isLoadingPods = true
        networkManager.fetchPodsForUser(email: viewModel.email) { [self] result in
            DispatchQueue.main.async {
                self.isLoadingPods = false
                switch result {
                case .success(let fetchedPods):
                    self.pods = fetchedPods
                case .failure(let error):
                    // Handle error (you might want to show an alert here)
                    print("Failed to fetch pods: \(error)")
                }
            }
        }
    }
}
