//
//  ButtonWithIcon.swift
//  Pods
//
//  Created by Dimi Nunez on 3/20/25.
//

import SwiftUI
struct ButtonWithIcon: View {
    let label: String
    let iconName: String
    let action: () -> Void
    let bgColor: Color?
    let textColor: Color?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bgColor ?? Color(UIColor.secondarySystemBackground))
            .foregroundColor(textColor ?? .accentColor)
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.top)
    }
}
