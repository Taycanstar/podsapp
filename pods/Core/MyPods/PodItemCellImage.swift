//
//  PodItemCellImage.swift
//  pods
//
//  Created by Dimi Nunez on 4/27/24.
//
import SwiftUI

struct PodItemCellImage: View {
    var item: PodItem
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all) // Ensure the background is filled to avoid any gaps

            if let imageURL = item.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable()
                            .scaledToFill() // This will still fill the entire area of the image view
                            .frame(minWidth: UIScreen.main.bounds.width, minHeight: UIScreen.main.bounds.height) // Use UIScreen to set the minimum frame
                            .clipped() // Ensure the image does not display outside the bounds
                    case .failure(_):
                        Text("Failed to load image")
                            .foregroundColor(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Text("No Image Available")
                    .foregroundColor(.white)
            }

            VStack {
                Spacer()

                HStack(alignment: .bottom) {
//                    VStack(alignment: .leading) {
//                        Text("Lewis Hamilton")
//                            .fontWeight(.semibold)
//                        Text("Still we raise")
//                    }
//                    .foregroundStyle(.white)
//                    .font(.subheadline)

                    Spacer()
                }
                .padding(.bottom, 80)
            }
            .padding()
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height) // Set the frame to the device screen dimensions
        .edgesIgnoringSafeArea(.all) // Make sure it extends to all edges
    }
}


