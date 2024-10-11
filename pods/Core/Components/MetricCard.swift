//
//  MetricCard.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//

import SwiftUI

struct MetricCard: View {
    let title: String
    let value: Double
    let unit: String
    var titleFontSize: CGFloat = 14
    var titleFontWeight: Font.Weight = .semibold
    var valueFontSize: CGFloat = 18
    var valueFontWeight: Font.Weight = .bold
    var unitFontSize: CGFloat = 12
    var unitFontWeight: Font.Weight = .semibold
    
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: titleFontSize, weight: titleFontWeight))
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formattedValue(value))
                        .font(.system(size: valueFontSize, weight: valueFontWeight))
                    
                    Text(unit)
                        .font(.system(size: unitFontSize, weight: unitFontWeight))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb: 244,246,247))
            .cornerRadius(12)
            .overlay(
                Image(systemName: "chevron.right")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 8),
                alignment: .trailing
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
//    private func formattedValue(_ value: Double) -> String {
//        return String(format: "%.2f", value)
//    }
    private func formattedValue(_ value: Double) -> String {
        return String(Int(round(value)))
    }

}
