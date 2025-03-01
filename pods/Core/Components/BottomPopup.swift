//
//  BottomPopup.swift
//  Pods
//
//  Created by Dimi Nunez on 2/28/25.
//

import SwiftUI


struct BottomPopup: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundColor(Color(.label))  // Adapt to color scheme
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Material.ultraThin,  // Apply the glass effect
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.label).opacity(0.7), lineWidth: 1)  // Add a border for contrast
            ) 
            .padding(.horizontal, 16)
            .padding(.bottom, 65)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    BottomPopup(message: "Sample message")
}
