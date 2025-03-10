//
//  DropdownButton.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/28/24.
//

import SwiftUI

struct DropdownButton<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String {
    let label: String
    let options: [T]
    @Binding var selectedOption: T
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    selectedOption = option
                }) {
                    if option == selectedOption {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedOption.rawValue)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(colorScheme == .dark ? .white : .black)
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .cornerRadius(8)
        }
    }
}
