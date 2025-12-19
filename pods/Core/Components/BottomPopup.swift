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
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(.label))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    BottomPopup(message: "Sample message")
}
