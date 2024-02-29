//
//  PodView.swift
//  pods
//
//  Created by Dimi Nunez on 2/28/24.
//

import SwiftUI

struct PodView: View {
    var pod: Pod
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false

    var body: some View {
      
            List {
                // Your pod items go here
                ForEach(pod.items, id: \.metadata) { item in
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
            .padding(.vertical, 1)
                }
              
                .onMove(perform: moveItem)
                .onDelete(perform: deleteItem)
            }
            .navigationTitle(pod.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems( trailing: editButton)
            .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
      
    }

    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left") // Customize according to your needs
        }
    }

    private var editButton: some View {
        Button(action: {
            isEditing.toggle()
        }) {
            Text(isEditing ? "Done" : "Edit")
        }
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        // Implement moving of items if necessary
    }

    func deleteItem(at offsets: IndexSet) {
        // Implement deletion of items if necessary
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        PodView(pod: Pod(items: [PodItem(videoURL: URL(string: "https://example.com")!, metadata: "Example Item", thumbnail: UIImage(systemName: "photo"))], title: "Example Pod"))
    }
}
