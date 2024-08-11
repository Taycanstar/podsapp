//
//  DefaultProfilePicture.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/10/24.
//

import Foundation
import SwiftUI

struct DefaultProfilePicture: View {
    let initial: String
    let color: String
    let size: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(rgbString: color))
            Text(initial.prefix(1).uppercased())
                .foregroundColor(.white)
                .font(.system(size: size * 0.5, weight: .bold))
        }
        .frame(width: size, height: size)
    }
}

extension Color {
    init(rgbString: String) {
        let components = rgbString.components(separatedBy: ",").compactMap { Double($0) }
        if components.count == 3 {
            self.init(red: components[0] / 255, green: components[1] / 255, blue: components[2] / 255)
        } else {
            // Provide a default color (e.g., gray) if parsing fails
            self.init(red: 0.5, green: 0.5, blue: 0.5)
        }
    }
}
