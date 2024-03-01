import SwiftUI


struct PodView: View {
    var pod: Pod
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var currentIndex: Int = 0

    var body: some View {
        List {
            ForEach(pod.items.indices, id: \.self) { index in
//                NavigationLink(destination: ItemView(items: pod.items, currentIndex: $currentIndex)) {
                NavigationLink(destination: ItemView(items: pod.items)) {
                    HStack {
                        Text(pod.items[index].metadata)
                        Spacer()
                        if let thumbnail = pod.items[index].thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 35, height: 35)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
            .onMove(perform: moveItem)
            .onDelete(perform: deleteItem)
        }
        .navigationTitle(pod.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: editButton)
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




