//
//  PrimaryButtonStyle.swift
//  pods
//
//  Created by Dimi Nunez on 11/8/25.
//


import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color("font"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color("button"))
            .cornerRadius(100)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.12 : 0.18), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color("font"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color("button").opacity(0.15))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.08 : 0.12), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
