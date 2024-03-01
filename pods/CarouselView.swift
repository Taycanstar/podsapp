
import SwiftUI

struct ThumbnailCarouselView: View {
    var items: [PodItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) { // Adjust spacing between thumbnails
                ForEach(items, id: \.videoURL) { item in
                    Image(uiImage: item.thumbnail ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50) // Thumbnail size
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 10) // Add padding to the horizontal scroll view
        }
        .frame(height: 60) // Carousel height
        .frame(width: 130) // Limit the visible area to show only three thumbnails at a time
    }
}

