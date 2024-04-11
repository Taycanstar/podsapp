
import SwiftUI

struct ThumbnailCarouselView: View {
    var items: [PodItem]

    var body: some View {
        VStack{
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) { // Adjust spacing between thumbnails
                    ForEach(items, id: \.id) { item in
                        Image(uiImage: item.thumbnail ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40) // Thumbnail size
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
                            
                    }
                }

            }
            .frame(height: 60) 
            .frame(minWidth: 40, idealWidth: CGFloat(min(items.count, 3)) * 45, maxWidth: 110)
//            .frame(width: 40)
            Text("Items")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 60, alignment: .leading)
                    .padding(.leading, 7)
                    .padding(.top, -15)
           
        }
        .frame(width: CGFloat(min(items.count, 3)) * 55, alignment: .leading)
        .padding(.leading, 15)
        
      
    }
}

