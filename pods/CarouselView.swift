import SwiftUI

struct ThumbnailCarouselView: View {
    var items: [PodItem]

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) { // Adjust spacing between thumbnails
                    ForEach(items, id: \.videoURL) { item in
                        Image(uiImage: item.thumbnail ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 60) // Thumbnail size
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    // Add an invisible spacer to allow scrolling to the end
                    if items.count > 3 {
                        Spacer(minLength: geometry.size.width / 2)
                        Spacer().frame(width: 40)
                    }
                }
            }
            .frame(height: 60) // Carousel height
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 120) // Width of fading effect area
            )
            .mask(
                HStack {
                    Rectangle().frame(width: 120) // Fully visible area
                    Rectangle().frame(width: 20).opacity(0) // Fading area
                    Spacer() // Allows ScrollView to be scrollable beyond mask
                }
            )
        }
        .frame(height: 60)
    }
}
