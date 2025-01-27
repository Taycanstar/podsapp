//
//  PodsView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/26/25.
//

import SwiftUI

struct PodsView: View {
   @EnvironmentObject var podsViewModel: PodsViewModel
   @State private var showingFolders = false
   
   var body: some View {
       NavigationView {
           if showingFolders {
               FoldersView(showingFolders: $showingFolders)
           } else {
               PodsList()
                   .navigationTitle("Pods")
                   .navigationBarItems(
                       leading: Button("Folders") {
                           showingFolders = true
                       }
                   )
           }
       }
   }
}

struct FoldersView: View {
   @Binding var showingFolders: Bool
   
   var body: some View {
       List {
           Section(header: Text("On My iPhone")) {
               Button("Pods") {
                   showingFolders = false
               }
           }
       }
       .navigationTitle("Folders")
   }
}

struct PodsList: View {
   @EnvironmentObject var podsViewModel: PodsViewModel
   
   var body: some View {
       List(podsViewModel.pods) { pod in
           Text(pod.title)
               .font(.system(size: 17, weight: .semibold)) // Applies the Title style
          
       }
   }
}
