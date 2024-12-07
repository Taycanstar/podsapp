//
//  SearchBar.swift
//  Pods
//
//  Created by Dimi Nunez on 12/6/24.
//

import Foundation
import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 8)
            
            TextField("Artists, Songs, Lyrics, and More", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 8)
                }
            }
            
            Image(systemName: "mic.fill")
                .foregroundColor(.gray)
                .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
