import SwiftUI

struct CreatePodView: View {
    @State var podName: String = ""
    var pod: Pod
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            // Header
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.backward")
                        .foregroundColor(.black)
                        .font(.system(size: 20))
                }
                Spacer()
                Text("Create Pod")
                    .font(.system(size: 18))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
            }
            .padding()

            // Pod Name Input

                PlaceholderTextView(placeholder: "Pod name", text: $podName)
                

            // List of Items
            List {
                ForEach(pod.items, id: \.videoURL) { item in
                    HStack {
                        TextField("Metadata", text: .constant(item.metadata))
                            .foregroundColor(.black) // Ensure text is visible
                            .background(Color.white) // Explicitly set background to white
                          

                        Spacer()

                        Image(uiImage: item.thumbnail ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    .listRowBackground(Color.white) // Ensure list row background is white
                }
            }
            .listStyle(PlainListStyle()) // Use plain style for list


            HStack { // Embed in HStack for padding
                Spacer() // Push button left
                Button("Create") {
                    // Handle creating the pod
                }
                .frame(maxWidth: .infinity) // Full width within HStack
                .padding() // Add padding around the button content
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(8)
                
               
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .overlay(alignment: .top) { // Apply overlay to the HStack for a top border
                Divider()
                    .opacity(0.5) // Adjust opacity if needed
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      
        .background(Color.white)
    }
}


struct PlaceholderTextView: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    /*.foregroundColor(Color(UIColor.lightGray))*/ // Customize as needed
                    .foregroundColor(Color(red: 0.9, green: 0.9, blue: 0.9))
                    .font(.system(size: 28, design: .rounded).bold())
                    .padding(.horizontal, 15)
            }
            TextField("", text: $text)
                .font(.system(size: 28, design: .rounded).bold())
                .padding(.horizontal, 15)
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
    }
}

